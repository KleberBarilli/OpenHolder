defmodule Holder.Repo.Migrations.CreateQuotesCache do
  use Ecto.Migration

  def change do
    create table(:quotes_cache) do
      add :ticker, :string, null: false
      add :price, :float
      add :currency, :string, default: "BRL"
      add :source, :string, default: "brapi"
      add :fetched_at, :utc_datetime
      timestamps()
    end

    create unique_index(:quotes_cache, [:ticker])
  end
end
