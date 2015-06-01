defmodule Hyperledger.LogEntry do
  use Ecto.Model
  import Hyperledger.ParamsHelpers, only: [underscore_keys: 1]
  import Hyperledger.Validations
  
  require Logger
  
  alias Hyperledger.Repo
  alias Hyperledger.LogEntry
  alias Hyperledger.Asset
  alias Hyperledger.Account
  alias Hyperledger.Issue
  alias Hyperledger.Transfer
  alias Hyperledger.Node
  alias Hyperledger.View
  alias Hyperledger.PrePrepare
  alias Hyperledger.PrepareConfirmation, as: Prepare
  alias Hyperledger.CommitConfirmation, as: Commit
  alias Hyperledger.Crypto

  schema "log_entries" do
    field :command, :string
    field :data, :string
    field :authentication_key, :string
    field :signature, :string
    
    field :pre_prepared, :boolean, default: false
    field :prepared, :boolean, default: false
    field :committed, :boolean, default: false
    field :executed, :boolean, default: false
    field :accepted, :boolean

    timestamps
    
    belongs_to :view, View
    has_one :pre_prepares, PrePrepare
    has_many :prepare_confirmations, Prepare
    has_many :commit_confirmations, Commit
  end
  
  @required_fields ~w(command data authentication_key signature)
  
  def changeset(log_entry, mode, params \\ nil) do
    if mode == :insert do
      required = @required_fields ++ ~w(id view_id)
    else
      required = @required_fields
    end
    log_entry
    |> cast(params, required, [])
    |> validate_encoding(:authentication_key)
    |> validate_encoding(:signature)
    |> validate_authenticity
    |> validate_data
  end
  
  def create(changeset) do
    Repo.transaction fn ->
      id = latest_id + 1
      
      log_entry =
        changeset
        |> change(%{id: id, view_id: View.current.id})
        |> Repo.insert
        |> create_pre_prepare

      Node.broadcast(log_entry.id, "log", as_json(log_entry))
      log_entry
    end
  end
  
  def insert(id: id, view_id: view_id, command: command, data: data,
    prepare_confirmations: prep_confs, commit_confirmations: commit_confs) do
    Repo.transaction fn ->
      log_entry = %LogEntry{id: id, view_id: view_id, command: command, data: data}
      prep_ids = Enum.map(prep_confs, &(&1.node_id))
      
      cond do
        # If the node is a replica and the log has a prepare from the primary
        Node.current != View.current.primary and (View.current.primary.id in prep_ids) ->
          case Repo.get(LogEntry, id) do
            nil -> log_entry = Repo.insert(log_entry)
            saved_entry -> log_entry = saved_entry
          end
 
          # Prepares
          [%{node_id: Node.current.id, signature: "temp_signature"}]
          |> Enum.into(prep_confs)
          |> Enum.each(&(add_prepare(log_entry, &1.node_id, &1.signature)))
          # Commits
          commit_confs
          |> Enum.each(&(add_commit(log_entry, &1.node_id, &1.signature)))
          Node.broadcast(log_entry.id, "prepare", as_json(log_entry))
          log_entry
          
        # Node is primary
        Node.current == View.current.primary ->      
          case Repo.get(LogEntry, id) do
            nil ->
              Repo.rollback(:cant_insert_entries_to_primary)
            log_entry ->
              # Prepares
              pc_node_ids = Repo.all(assoc(log_entry, :prepare_confirmations))
                            |> Enum.map &(&1.node_id)
              prep_confs
              |> Enum.reject(&(&1.node_id in pc_node_ids))
              |> Enum.each &(add_prepare(log_entry, &1.node_id, &1.signature))
              
              # Commits
              cc_node_ids = Repo.all(assoc(log_entry, :commit_confirmations))
                            |> Enum.map &(&1.node_id)
              commit_confs
              |> Enum.reject(&(&1.node_id in cc_node_ids))
              |> Enum.each &(add_commit(log_entry, &1.node_id, &1.signature))
          end
        true ->
          Repo.rollback(:invalid_node)
      end
      log_entry
    end
  end
  
  def create_pre_prepare(log_entry) do
    params =
      %{
        log_entry_id: log_entry.id,
        node_id: Node.current.id,
        data: Poison.encode!(as_json(log_entry)),
        signature: sign(log_entry)
      }
    
    {:ok, log_entry} = Repo.transaction fn ->
      PrePrepare.changeset(params)
      |> PrePrepare.create
      %{ log_entry | pre_prepared: true }
      |> Repo.update
    end
    update_state(log_entry)
  end
  
  def add_prepare(log_entry, node_id, signature) do
    Repo.transaction fn ->
      prep_conf = build(log_entry, :prepare_confirmations)
      %{ prep_conf | signature: signature, node_id: node_id }
      |> Repo.insert
    end
    update_state(log_entry)
  end
  
  def add_commit(log_entry, node_id, signature) do
    Repo.transaction fn ->
      commit_conf = build(log_entry, :commit_confirmations)
      %{ commit_conf | signature: signature, node_id: node_id }
      |> Repo.insert
    end
    update_state(log_entry)
  end
  
  def update_state(log_entry) do
    cond do
      log_entry.pre_prepared and
      !log_entry.prepared and
      prepare_count(log_entry) >= (Node.prepare_quorum) ->
        log_entry
        |> mark_prepared
        |> add_commit(Node.current.id, "temp_signature")
      
      !log_entry.committed and
      commit_count(log_entry) >= Node.quorum ->
        log_entry
        |> mark_committed
        |> cond_execute # If previous log entry has been executed then execute
      
      true -> log_entry
    end
  end
      
  def execute(log_entry) do
    Repo.transaction fn ->
      params = Poison.decode!(log_entry.data) |> underscore_keys
      case log_entry.command do
        "asset/create" ->
          result = 
            %Asset{}
            |> Asset.changeset(params["asset"])
            |> Asset.create
          
        "account/create" ->
          result =
            %Account{}
            |> Account.changeset(params["account"])
            |> Account.create
        
        "issue/create" ->
          result =
            %Issue{}
            |> Issue.changeset(params["issue"], log_entry.authentication_key)
            |> Issue.create
        
        "transfer/create" ->
          result =
            %Transfer{}
            |> Transfer.changeset(params["transfer"], log_entry.authentication_key)
            |> Transfer.create
      end
      
      # Mark as executed and check if there's a follow entry to execute
      log_entry
      |> mark_executed(result)
      |> execute_next
    end
  end
  
  def as_json(log_entry) do
    %{
      logEntry: %{
        id: log_entry.id,
        view_id: log_entry.view_id,
        command: log_entry.command,
        data: log_entry.data,
        authentication_key: log_entry.authentication_key,
        signature: log_entry.signature
      }
    }
  end
  
  # Private fns
  defp latest_id do
    query = from l in LogEntry,
       order_by: [desc: :id],
          limit: 1,
         select: l.id
    
    case Repo.one(query) do
      nil -> 0
      id -> id
    end
  end
    
  defp prepare_count(log_entry) do
    Repo.one(from p in Prepare,
           where: p.log_entry_id == ^log_entry.id,
          select: count(p.id))
  end
  
  defp commit_count(log_entry) do
    Repo.one(from c in Commit,
           where: c.log_entry_id == ^log_entry.id,
          select: count(c.id))
  end
  
  defp mark_prepared(log_entry) do
    log_entry = %{ log_entry | prepared: true } |> Repo.update
    Logger.info "Log entry #{log_entry.id} prepared"
    Node.broadcast(log_entry.id, "commit", as_json(log_entry))
    log_entry
  end
  
  defp mark_committed(log_entry) do
    log_entry = %{ log_entry | committed: true } |> Repo.update
    Logger.info "Log entry #{log_entry.id} comitted"
    log_entry
  end
  
  defp mark_executed(log_entry, result) do
    case result do
      {:ok, _} -> accepted? = true
      _ -> accepted? = false
    end
    
    log_entry =
      %{ log_entry | executed: true, accepted: accepted? }
      |> Repo.update
    Logger.info "Log entry #{log_entry.id} executed"
    log_entry
  end
  
  defp cond_execute(log_entry) do
    prev = prev_entry(log_entry)
    if (is_nil(prev) or prev.executed) and !log_entry.executed do
      execute(log_entry)
    end
    log_entry
  end
  
  defp execute_next(log_entry) do
    next = next_entry(log_entry)
    unless is_nil(next) do
      execute(next)
    end
    log_entry
  end
  
  defp prev_entry(log_entry) do
    Repo.get(LogEntry, log_entry.id - 1)
  end
  
  defp next_entry(log_entry) do
    Repo.get(LogEntry, log_entry.id + 1)
  end
  
  defp sign(log_entry) do
    case System.get_env("SECRET_KEY") do
      nil ->
        raise "SECRET_KEY env not found"
      key ->
        log_entry
        |> as_json
        |> Hyperledger.Crypto.sign(Base.decode16!(key))
    end
  end
    
  defp validate_authenticity(changeset) do
    key = changeset.changes.authentication_key
    sig = changeset.changes.signature
    validate_change changeset, :data, fn :data, body ->
      case {Base.decode16(key), Base.decode16(sig)} do
        {{:ok, key}, {:ok, sig}} ->
          if Crypto.verify(body, sig, key) do
            []
          else
            [{:data, :authentication_failed}]
          end
        _ -> []
      end
    end
  end
  
  defp validate_data(changeset) do
    log_entry = changeset.params
    params = Poison.decode!(log_entry["data"]) |> underscore_keys
    validate_change changeset, :data, fn _, _ ->
      changeset = case log_entry["command"] do
        "asset/create" ->
          %Asset{}
          |> Asset.changeset(params["asset"])
        
        "account/create" ->
          %Account{}
          |> Account.changeset(params["account"], skip_db: true)
      
        "issue/create" ->
          %Issue{}
          |> Issue.changeset(params["issue"], log_entry["authentication_key"], skip_db: true)
      
        "transfer/create" ->
          %Transfer{}
          |> Transfer.changeset(params["transfer"], log_entry["authentication_key"], skip_db: true)
      end
      
      if changeset.valid? do
        []
      else
        [:data, :is_not_valid]
      end
    end
  end
end
