defmodule Hyperledger.Repo.Migrations.AddDataToConfirmations do
  use Ecto.Migration

  def change do
    alter table(:prepare_confirmations) do
      add :data, :text
    end
    
    alter table(:commit_confirmations) do
      add :data, :text
    end
  end
end
