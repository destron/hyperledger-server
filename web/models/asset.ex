defmodule Hyperledger.Asset do
  use Ecto.Model
  import Hyperledger.Validations

  alias Hyperledger.Repo
  alias Hyperledger.Account
  alias Hyperledger.Issue
  
  @primary_key {:hash, :string, []}
  schema "assets" do
    field :public_key, :string
    
    timestamps
    
    has_many :accounts, Account
    has_many :issues, Issue
    
    belongs_to :primary_account, Account,
      foreign_key: :primary_account_public_key,
      references: :public_key,
      type: :string
  end
  
  @required_fields ~w(hash public_key primary_account_public_key)
  @optional_fields ~w()

  def changeset(asset, params \\ nil) do
    asset
    |> cast(params, @required_fields, @optional_fields)
    |> validate_encoding(:hash)
    |> validate_encoding(:public_key)
    |> validate_encoding(:primary_account_public_key)
  end
  
  def create(changeset) do
    Repo.transaction fn ->
      if not(changeset.valid?) do
        Repo.rollback :invalid_changset
      end
      
      asset = Repo.insert(changeset)
      account = build(asset, :primary_account)
      %{
        account |
        public_key: asset.primary_account_public_key,
        asset_hash: asset.hash
      } |> Repo.insert
      
      asset
    end
  end
end
