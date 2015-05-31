defmodule Hyperledger.Issue do
  use Ecto.Model
  import Hyperledger.Validations
  
  alias Hyperledger.Repo
  alias Hyperledger.Asset
  
  @primary_key {:uuid, Ecto.UUID, []}
  schema "issues" do
    field :amount, :integer

    timestamps
    
    belongs_to :asset, Asset,
      foreign_key: :asset_hash,
      references: :hash,
      type: :string
    
    has_one :account, through: [:asset, :primary_account]
  end
  
  @required_fields ~w(uuid amount asset_hash)
  @optional_fields ~w()

  def changeset(transfer, params \\ nil, auth_key) do
    auth_asset = Repo.one(from a in Asset, where: a.public_key == ^auth_key, select: a)
    auth_hash = 
      case auth_asset do
        nil -> []
        asset -> [asset.hash]
      end
    
    transfer
    |> cast(params, @required_fields, @optional_fields)
    |> validate_existence(:asset_hash, Asset)
    |> validate_number(:amount, greater_than: 0)
    |> validate_inclusion(:asset_hash, auth_hash)
  end
  
  def create(changeset) do
    Repo.transaction fn ->
      issue = Repo.insert(changeset)
      issue = Repo.preload(issue, [:asset, :account])

      %{ issue.account | balance: (issue.account.balance + issue.amount)}
      |> Repo.update
      
      issue
    end
  end
  
end
