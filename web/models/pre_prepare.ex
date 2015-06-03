defmodule Hyperledger.PrePrepare do
  use Ecto.Model
  
  alias Hyperledger.PrePrepare
  alias Hyperledger.LogEntry
  alias Hyperledger.Node
  alias Hyperledger.Repo
  alias Hyperledger.Crypto
  
  schema "pre_prepares" do
    field :data, :string
    field :signature, :string    
    timestamps
    
    belongs_to :log_entry, LogEntry
    belongs_to :node, Node
  end
  
  @required_fields ~w(data signature log_entry_id node_id)
  
  def changeset(params) do
    %PrePrepare{}
    |> cast(params, @required_fields, [])
    |> validate_authenticity
  end
  
  def create(changeset) do
    Repo.transaction fn ->
      Repo.insert(changeset)
    end
  end
  
  defp validate_authenticity(changeset) do
    key =
      case Repo.get(Node, changeset.changes.node_id) do
        nil -> ""
        node -> node.public_key
      end
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
