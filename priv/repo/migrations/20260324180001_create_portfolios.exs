defmodule Holder.Repo.Migrations.CreatePortfolios do
  use Ecto.Migration

  def change do
    create table(:portfolios) do
      add :name, :string, null: false, default: "Minha Carteira"
      timestamps()
    end
  end
end
