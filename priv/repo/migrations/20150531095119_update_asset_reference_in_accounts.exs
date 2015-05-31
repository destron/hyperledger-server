defmodule Hyperledger.Repo.Migrations.UpdateAssetReferenceInAccounts do
  use Ecto.Migration

  def up do
    alter table(:accounts) do
      add :asset_hash, :string,
        references: :assets, column: :hash, type: :string
      remove :ledger_hash
    end
  end
  
  def down do
    alter table(:accounts) do
      add :ledger_hash, :string,
        references: :ledgers, column: :hash, type: :string
      remove :asset_hash
    end
  end
end
