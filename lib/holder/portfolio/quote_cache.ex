defmodule Holder.Portfolio.QuoteCache do
  use Ecto.Schema
  import Ecto.Changeset

  schema "quotes_cache" do
    field :ticker, :string
    field :price, :float
    field :currency, :string, default: "BRL"
    field :source, :string, default: "brapi"
    field :fetched_at, :utc_datetime

    timestamps()
  end

  def changeset(quote_cache, attrs) do
    quote_cache
    |> cast(attrs, [:ticker, :price, :currency, :source, :fetched_at])
    |> validate_required([:ticker])
    |> unique_constraint(:ticker)
  end
end
