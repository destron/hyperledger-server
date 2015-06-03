defmodule Hyperledger.Repo.Migrations.InitialCloseConfirmationsCreate do
  use Ecto.Migration

  def change do
    create table(:close_confirmations) do
      add :view_id, :integer, references: :views
      add :node_id, :integer, references: :nodes
      add :data, :text
      add :signature, :text
      timestamps
    end
  end
end
