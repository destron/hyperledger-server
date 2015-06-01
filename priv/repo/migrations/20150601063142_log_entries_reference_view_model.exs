defmodule Hyperledger.Repo.Migrations.LogEntriesReferenceViewModel do
  use Ecto.Migration

  def up do
    alter table(:log_entries) do
      add :view_id, :integer, references: :views
      remove :view
    end
  end
  
  def down do
    alter table(:log_entries) do
      add :view, :integer
      remove :view_id
    end
  end
end
