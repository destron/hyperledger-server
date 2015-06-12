defmodule Hyperledger.PrePrepare do
  use Ecto.Model
  import Hyperledger.Validations
  
  alias Hyperledger.PrePrepare
  alias Hyperledger.LogEntry
  alias Hyperledger.Node
  alias Hyperledger.Repo
  
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
    |> validate_node_authenticity
  end
  
  def create(changeset) do
    Repo.transaction fn ->
      Repo.insert(changeset)
    end
  end
end
