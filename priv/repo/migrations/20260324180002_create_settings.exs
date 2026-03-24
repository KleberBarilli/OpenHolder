defmodule Holder.Repo.Migrations.CreateSettings do
  use Ecto.Migration

  def change do
    create table(:settings) do
      add :portfolio_id, references(:portfolios, on_delete: :delete_all), null: false
      add :dollar_rate, :float, default: 5.80
      add :iof, :float, default: 0.035
      add :spread, :float, default: 0.01
      add :aporte_value, :float, default: 0.0
      add :classes_to_buy, :integer, default: 0
      add :min_diff_ignore, :float
      add :brapi_token, :string
      timestamps()
    end

    create unique_index(:settings, [:portfolio_id])
  end
end
