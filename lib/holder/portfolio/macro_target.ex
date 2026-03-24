defmodule Holder.Portfolio.MacroTarget do
  use Ecto.Schema
  import Ecto.Changeset

  schema "macro_targets" do
    field :asset_class, :string
    field :target_pct, :float, default: 0.0

    belongs_to :portfolio, Holder.Portfolio.PortfolioRecord

    timestamps()
  end

  def changeset(target, attrs) do
    target
    |> cast(attrs, [:asset_class, :target_pct])
    |> validate_required([:asset_class])
    |> validate_number(:target_pct, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
  end
end
