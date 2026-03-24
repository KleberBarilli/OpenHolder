defmodule Holder.Portfolio.AssetClass do
  use Ecto.Schema
  import Ecto.Changeset

  schema "asset_classes" do
    field :key, :string
    field :label, :string
    field :color, :string, default: "#64748b"
    field :currency, :string, default: "BRL"
    field :has_criteria, :boolean, default: false
    field :criteria_type, :string
    field :sort_order, :integer, default: 0
    field :enabled, :boolean, default: true

    belongs_to :portfolio, Holder.Portfolio.PortfolioRecord

    timestamps()
  end

  def changeset(asset_class, attrs) do
    asset_class
    |> cast(attrs, [:key, :label, :color, :currency, :has_criteria, :criteria_type, :sort_order, :enabled])
    |> validate_required([:key, :label])
    |> validate_format(:key, ~r/^[a-zA-Z][a-zA-Z0-9_]*$/, message: "apenas letras, números e underscore")
    |> validate_format(:color, ~r/^#[0-9a-fA-F]{6}$/, message: "deve ser hex válido (#RRGGBB)")
    |> validate_length(:label, max: 50)
    |> validate_length(:key, max: 30)
    |> validate_inclusion(:currency, ~w(BRL USD EUR))
    |> unique_constraint([:portfolio_id, :key])
  end
end
