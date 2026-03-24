defmodule Holder.Repo.Migrations.CreateMacroTargets do
  use Ecto.Migration

  def change do
    create table(:macro_targets) do
      add :portfolio_id, references(:portfolios, on_delete: :delete_all), null: false
      add :asset_class, :string, null: false
      add :target_pct, :float, default: 0.0
      timestamps()
    end

    create unique_index(:macro_targets, [:portfolio_id, :asset_class])
  end
end
