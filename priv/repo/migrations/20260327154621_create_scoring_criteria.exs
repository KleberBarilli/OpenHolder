defmodule Holder.Repo.Migrations.CreateScoringCriteria do
  use Ecto.Migration

  def change do
    create table(:scoring_criteria) do
      add :portfolio_id, references(:portfolios, on_delete: :delete_all), null: false
      add :criteria_type, :string, null: false
      add :key, :string, null: false
      add :label, :string, null: false
      add :sort_order, :integer, default: 0
      add :enabled, :boolean, default: true, null: false

      timestamps()
    end

    create unique_index(:scoring_criteria, [:portfolio_id, :criteria_type, :key])
  end
end
