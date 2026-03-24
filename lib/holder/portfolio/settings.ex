defmodule Holder.Portfolio.Settings do
  use Ecto.Schema
  import Ecto.Changeset

  schema "settings" do
    field :dollar_rate, :float, default: 5.80
    field :iof, :float, default: 0.035
    field :spread, :float, default: 0.01
    field :aporte_value, :float, default: 0.0
    field :classes_to_buy, :integer, default: 0
    field :min_diff_ignore, :float
    field :brapi_token, :string

    belongs_to :portfolio, Holder.Portfolio.PortfolioRecord

    timestamps()
  end

  def changeset(settings, attrs) do
    settings
    |> cast(attrs, [:dollar_rate, :iof, :spread, :aporte_value, :classes_to_buy, :min_diff_ignore, :brapi_token])
  end
end
