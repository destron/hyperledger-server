defmodule Hyperledger.Repo.Migrations.RenameLedgersTableToAssets do
  use Ecto.Migration

  def up do
    create table(:assets, primary_key: false) do
      add :hash, :string, primary_key: true
      add :public_key, :string
      add :primary_account_public_key, :string,
        references: :accounts, column: :public_key, type: :string
      
      timestamps
    end
            
    drop table(:ledgers)
  end
  
  def down do
    create table(:ledgers, primary_key: false) do
      add :hash, :string, primary_key: true
      add :public_key, :string
      add :primary_account_public_key, :string
      
      timestamps
    end
        
    drop table(:assets)
  end
end
