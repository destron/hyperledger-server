defmodule Hyperledger.Repo.Migrations.AddClosedBoolToViews do
  use Ecto.Migration

  def change do
    alter table(:views) do
      add :closed, :boolean
    end
  end
end
