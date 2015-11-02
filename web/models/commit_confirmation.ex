defmodule Hyperledger.CommitConfirmation do
  use Ecto.Model
  import Hyperledger.Validations

  alias Hyperledger.CommitConfirmation
  alias Hyperledger.LogEntry
  alias Hyperledger.Node
  alias Hyperledger.Repo
  
  schema "commit_confirmations" do
    field :signature, :string
    field :data, :string
    timestamps
    
    belongs_to :log_entry, LogEntry
    belongs_to :node, Node
  end
  
  @required_fields ~w(data signature log_entry_id node_id)
  
  def changeset(params) do
    %CommitConfirmation{}
    |> cast(params, @required_fields, [])
    |> validate_inclusion(:node_id, Repo.all(from n in Node, select: n.id))
    |> validate_node_authenticity
  end
  
  def create(changeset) do
    Repo.transaction fn ->
      Repo.insert(changeset)
    end
  end
end
