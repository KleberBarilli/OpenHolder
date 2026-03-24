defmodule Holder.Portfolio.AssetScore do
  use Ecto.Schema
  import Ecto.Changeset

  schema "asset_scores" do
    field :criterion_id, :string
    field :value, :integer, default: 0

    belongs_to :asset, Holder.Portfolio.Asset

    timestamps()
  end

  def changeset(score, attrs) do
    score
    |> cast(attrs, [:criterion_id, :value])
    |> validate_required([:criterion_id])
    |> validate_inclusion(:value, [-1, 0, 1])
  end
end
