defmodule Hyperledger.Repo.Migrations.InitalPreprepareCreate do
  use Ecto.Migration

  def change do
    create table(:pre_prepares) do
      add :data, :text
      add :signature, :string
      add :log_entry_id, :integer, references: :log_entries
      add :node_id, :integer, references: :nodes
      timestamps
    end
  end
end
