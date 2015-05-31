defmodule Hyperledger.Account do
  use Ecto.Model
  import Hyperledger.Validations
  
  alias Hyperledger.Repo
  alias Hyperledger.Asset
  
  @primary_key {:public_key, :string, []}
  schema "accounts" do
    field :balance, :integer, default: 0
    
    belongs_to :asset, Asset,
      foreign_key: :asset_hash,
      references: :hash,
      type: :string
    
    timestamps
  end
  
  @required_fields ~w(public_key asset_hash)
  @optional_fields ~w()

  def changeset(account, params \\ nil) do
    account
    |> cast(params, @required_fields, @optional_fields)
    |> validate_encoding(:public_key)
    |> validate_existence(:asset_hash, Asset)
  end
  
  def create(changeset) do
    Repo.insert(changeset)
  end
end
