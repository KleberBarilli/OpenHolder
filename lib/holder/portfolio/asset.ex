defmodule Holder.Portfolio.Asset do
  use Ecto.Schema
  import Ecto.Changeset

  schema "assets" do
    field :asset_class, :string
    field :ticker, :string
    field :name, :string
    field :sector, :string
    field :asset_type, :string
    field :qty, :float, default: 0.0
    field :price, :float, default: 0.0
    field :value, :float, default: 0.0
    field :target_pct, :float, default: 0.0
    field :score, :integer
    field :liquidity, :string
    field :currency, :string, default: "BRL"
    field :sort_order, :integer, default: 0

    belongs_to :portfolio, Holder.Portfolio.PortfolioRecord
    has_many :asset_scores, Holder.Portfolio.AssetScore

    timestamps()
  end

  def changeset(asset, attrs) do
    asset
    |> cast(attrs, [:asset_class, :ticker, :name, :sector, :asset_type, :qty, :price, :value, :target_pct, :score, :liquidity, :currency, :sort_order])
    |> validate_required([:asset_class])
  end
end
