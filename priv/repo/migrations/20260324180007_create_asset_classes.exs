defmodule Holder.Repo.Migrations.CreateAssetClasses do
  use Ecto.Migration

  def change do
    create table(:asset_classes) do
      add :portfolio_id, references(:portfolios, on_delete: :delete_all), null: false
      add :key, :string, null: false
      add :label, :string, null: false
      add :color, :string, default: "#64748b"
      add :currency, :string, default: "BRL"
      add :has_criteria, :boolean, default: false
      add :criteria_type, :string
      add :sort_order, :integer, default: 0
      add :enabled, :boolean, default: true
      timestamps()
    end

    create unique_index(:asset_classes, [:portfolio_id, :key])
  end
end
