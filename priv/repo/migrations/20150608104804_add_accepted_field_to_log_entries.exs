defmodule Hyperledger.Repo.Migrations.AddAcceptedFieldToLogEntries do
  use Ecto.Migration

  def change do
    alter table(:log_entries) do
      add :accepted, :boolean
    end
  end
end
