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

  def changeset(issue, params, auth_key, opts \\ nil) do
    no_db_changeset = 
      issue
      |> cast(params, @required_fields, @optional_fields)
      |> validate_number(:amount, greater_than: 0)
      
    unless opts[:skip_db] do
      no_db_changeset
      |> validate_existence(:asset_hash, Asset)
      |> validate_authorisation(:asset_hash, auth_key)
    else
      no_db_changeset
    end
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
  
  defp validate_authorisation(changeset, field, auth_key) do    
    validate_change changeset, field, fn _field, asset_hash ->
      case Repo.get(Asset, asset_hash) do
        nil ->
          [] # Already added error
        asset ->
          if asset.public_key != auth_key do
            [:asset_hash, :unauthorized]
          else
            []
          end
      end
    end    
  end
end
