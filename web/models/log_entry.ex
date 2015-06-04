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
    
    field :prepared, :boolean, default: false
    field :committed, :boolean, default: false
    field :executed, :boolean, default: false

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
  end
  
  def create(changeset) do
    Repo.transaction fn ->
      id = latest_id + 1
      
      log_entry =
        changeset
        |> change(%{id: id, view: View.current})
        |> Repo.insert

      add_prepare(log_entry, Node.current.id, "temp_signature")
      Node.broadcast(log_entry.id, as_json(log_entry))
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
          Node.broadcast(log_entry.id, as_json(log_entry))
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
  
  def add_prepare(log_entry, node_id, signature) do
    Repo.transaction fn ->
      prep_conf = build(log_entry, :prepare_confirmations)
      %{ prep_conf | signature: signature, node_id: node_id }
      |> Repo.insert
      
      if (prepare_count(log_entry) >= Node.quorum and !log_entry.prepared) do
        log_entry
        |> mark_prepared
        |> add_commit(Node.current.id, "temp_signature")
      end
    end
  end
  
  def add_commit(log_entry, node_id, signature) do
    Repo.transaction fn ->
      commit_conf = build(log_entry, :commit_confirmations)
      %{ commit_conf | signature: signature, node_id: node_id }
      |> Repo.insert
      
      if (commit_count(log_entry) >= Node.quorum and !log_entry.committed) do
        log_entry
        |> mark_committed
        # If previous log entry has been executed then execute
        |> cond_execute
      end
    end
  end
      
  def execute(log_entry) do
    Repo.transaction fn ->
      params = Poison.decode!(log_entry.data) |> underscore_keys
      case log_entry.command do
        "asset/create" ->
          Asset.changeset(%Asset{}, params["asset"])
          |> Asset.create
          
        "account/create" ->
          Account.changeset(%Account{}, params["account"])
          |> Account.create
        
        "issue/create" ->
          Issue.changeset(%Issue{}, params["issue"], log_entry.authentication_key)
          |> Issue.create
        
        "transfer/create" ->
          Transfer.changeset(%Transfer{}, params["transfer"], log_entry.authentication_key)
          |> Transfer.create
      end
    
      # Mark as executed and check if there's a follow entry to execute
      log_entry
      |> mark_executed
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
        authorisation_key: log_entry.authentication_key,
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
    Node.broadcast(log_entry.id, as_json(log_entry))
    log_entry
  end
  
  defp mark_committed(log_entry) do
    log_entry = %{ log_entry | committed: true } |> Repo.update
    Logger.info "Log entry #{log_entry.id} comitted"
    log_entry
  end
  
  defp mark_executed(log_entry) do
    log_entry = %{ log_entry | executed: true } |> Repo.update
    Logger.info "Log entry #{log_entry.id} executed"
    log_entry
  end
  
  defp cond_execute(log_entry) do
    prev = prev_entry(log_entry)
    if is_nil(prev) or prev.executed do
      execute(log_entry)
    end    
  end
  
  defp execute_next(log_entry) do
    next = next_entry(log_entry)
    unless is_nil(next) do
      execute(next)
    end
  end
  
  defp prev_entry(log_entry) do
    Repo.get(LogEntry, log_entry.id - 1)
  end
  
  defp next_entry(log_entry) do
    Repo.get(LogEntry, log_entry.id + 1)
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
end
