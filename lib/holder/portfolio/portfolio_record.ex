defmodule Holder.Portfolio.PortfolioRecord do
  use Ecto.Schema
  import Ecto.Changeset

  schema "portfolios" do
    field :name, :string, default: "Minha Carteira"

    has_one :settings, Holder.Portfolio.Settings, foreign_key: :portfolio_id
    has_many :macro_targets, Holder.Portfolio.MacroTarget, foreign_key: :portfolio_id
    has_many :assets, Holder.Portfolio.Asset, foreign_key: :portfolio_id

    timestamps()
  end

  def changeset(portfolio, attrs) do
    portfolio
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
