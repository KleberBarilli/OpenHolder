defmodule Holder.Portfolio.AssetScore do
  use Ecto.Schema
  import Ecto.Changeset

  schema "asset_scores" do
    field :criterion_id, :string
    field :value, :integer, default: 0
    field :source, :string, default: "manual"
    field :ai_reason, :string

    belongs_to :asset, Holder.Portfolio.Asset

    timestamps()
  end

  def changeset(score, attrs) do
    score
    |> cast(attrs, [:criterion_id, :value, :source, :ai_reason])
    |> validate_required([:criterion_id])
    |> validate_inclusion(:value, [-1, 0, 1])
    |> validate_inclusion(:source, ["manual", "ai"])
  end
end
