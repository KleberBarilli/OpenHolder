defmodule Holder.Repo.Migrations.CreateAssetScores do
  use Ecto.Migration

  def change do
    create table(:asset_scores) do
      add :asset_id, references(:assets, on_delete: :delete_all), null: false
      add :criterion_id, :string, null: false
      add :value, :integer, default: 0
      timestamps()
    end

    create unique_index(:asset_scores, [:asset_id, :criterion_id])
  end
end
