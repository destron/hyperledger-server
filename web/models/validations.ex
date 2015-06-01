defmodule Hyperledger.Validations do
  use Ecto.Model
  
  alias Hyperledger.Repo
  alias Hyperledger.Node
  alias Hyperledger.Crypto
  
  def validate_encoding(changeset, field) do
    validate_change changeset, field, fn field, value ->
      case Base.decode16(value) do
        :error -> [{field, :not_base_16_encoded}]
        {:ok, ""} -> [{field, :empty}]
        {:ok, _} -> []
      end
    end
  end
  
  def validate_existence(changeset, field, model) do
    validate_change changeset, field, fn field, value ->
      case Repo.get(model, value) do
        nil -> [{field, :does_not_exist}]
        _ -> []
      end
    end
  end
  
  def validate_node_authenticity(changeset) do
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
