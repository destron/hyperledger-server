defmodule Hyperledger.Repo.Migrations.AddPrePreparedPredicateToLogEntries do
  use Ecto.Migration

  def change do
    alter table(:log_entries) do
      add :pre_prepared, :boolean
    end
  end
end
