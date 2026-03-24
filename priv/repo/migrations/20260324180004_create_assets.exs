defmodule Holder.Repo.Migrations.CreateAssets do
  use Ecto.Migration

  def change do
    create table(:assets) do
      add :portfolio_id, references(:portfolios, on_delete: :delete_all), null: false
      add :asset_class, :string, null: false
      add :ticker, :string
      add :name, :string
      add :sector, :string
      add :asset_type, :string
      add :qty, :float, default: 0.0
      add :price, :float, default: 0.0
      add :value, :float, default: 0.0
      add :target_pct, :float, default: 0.0
      add :score, :integer
      add :liquidity, :string
      add :currency, :string, default: "BRL"
      add :sort_order, :integer, default: 0
      timestamps()
    end

    create index(:assets, [:portfolio_id, :asset_class])
  end
end
