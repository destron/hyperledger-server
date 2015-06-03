defmodule Hyperledger.CloseConfirmation do
  use Ecto.Model
  
  alias Hyperledger.CloseConfirmation
  alias Hyperledger.View
  alias Hyperledger.Node
  alias Hyperledger.Repo
  alias Hyperledger.Crypto
  
  schema "close_confirmations" do
    field :signature, :string
    field :data, :string
    timestamps
    
    belongs_to :view, View
    belongs_to :node, Node
  end
  
  @required_fields ~w(data signature view_id node_id)
  
  def changeset(params) do
    %CloseConfirmation{}
    |> cast(params, @required_fields, [])
    |> validate_inclusion(:node_id, Repo.all(from n in Node, select: n.id))
    |> validate_inclusion(:view_id, [View.current.id])
    |> validate_authenticity
    |> validate_unique(:node_id, scope: [:view_id], on: Repo)
  end
  
  def create(changeset) do
    Repo.transaction fn ->
      cc = Repo.insert(changeset)
      
      view = Repo.one(assoc(cc, :view))
      View.check_and_close(view)
      cc
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
