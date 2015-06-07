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

  def changeset(account, params, opts \\ nil) do
    no_db_changeset = 
      account
      |> cast(params, @required_fields, @optional_fields)
      |> validate_encoding(:public_key)
    
    unless opts[:skip_db] do
      no_db_changeset
      |> validate_existence(:asset_hash, Asset)
    else
      no_db_changeset
    end
  end
  
  def create(changeset) do
    Repo.transaction fn ->
      if changeset.valid? do
        Repo.insert(changeset)
      else
        Repo.rollback :invalid_changeset
      end
    end
  end
end
