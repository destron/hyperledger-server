defmodule Hyperledger.Repo.Migrations.CreateViewModel do
  use Ecto.Migration

  def change do
    create table(:views) do
      add :primary_id, :integer, references: :nodes
      timestamps
    end
  end
end
