defmodule Hyperledger.Issue do
  use Ecto.Model
  import Hyperledger.Validations
  
  alias Hyperledger.Repo
  alias Hyperledger.Ledger
  
  @primary_key {:uuid, Ecto.UUID, []}
  schema "issues" do
    field :amount, :integer

    timestamps
    
    belongs_to :ledger, Ledger,
      foreign_key: :ledger_hash,
      references: :hash,
      type: :string
    
    has_one :account, through: [:ledger, :primary_account]
  end
  
  @required_fields ~w(uuid amount ledger_hash)
  @optional_fields ~w()

  def changeset(transfer, params \\ nil, auth_key) do
    auth_ledger = Repo.one(from l in Ledger, where: l.public_key == ^auth_key, select: l)
    auth_hash = 
      case auth_ledger do
        nil -> []
        ledger -> [ledger.hash]
      end
    
    transfer
    |> cast(params, @required_fields, @optional_fields)
    |> validate_existence(:ledger_hash, Ledger)
    |> validate_number(:amount, greater_than: 0)
    |> validate_inclusion(:ledger_hash, auth_hash)
  end
  
  def create(changeset) do
    Repo.transaction fn ->
      issue = Repo.insert(changeset)
      issue = Repo.preload(issue, [:ledger, :account])

      %{ issue.account | balance: (issue.account.balance + issue.amount)}
      |> Repo.update
      
      issue
    end
  end
  
end
