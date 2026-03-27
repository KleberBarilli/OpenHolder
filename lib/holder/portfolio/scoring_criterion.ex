defmodule Holder.Portfolio.ScoringCriterion do
  use Ecto.Schema
  import Ecto.Changeset

  schema "scoring_criteria" do
    field :criteria_type, :string
    field :key, :string
    field :label, :string
    field :sort_order, :integer, default: 0
    field :enabled, :boolean, default: true

    belongs_to :portfolio, Holder.Portfolio.PortfolioRecord

    timestamps()
  end

  def changeset(criterion, attrs) do
    criterion
    |> cast(attrs, [:criteria_type, :key, :label, :sort_order, :enabled])
    |> validate_required([:criteria_type, :key, :label])
    |> validate_inclusion(:criteria_type, ~w(stock fii))
    |> validate_format(:key, ~r/^[a-zA-Z][a-zA-Z0-9_]*$/,
      message: "apenas letras, números e underscore"
    )
    |> validate_length(:key, max: 30)
    |> validate_length(:label, max: 50)
    |> unique_constraint([:portfolio_id, :criteria_type, :key])
  end
end
