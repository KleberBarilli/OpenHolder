defmodule Holder.BrAPI do
  @moduledoc "HTTP client for brapi.dev API"

  @base "https://brapi.dev/api"

  def fetch_quote(ticker, token) do
    url = "#{@base}/quote/#{ticker}"
    case Req.get(url, headers: auth_headers(token)) do
      {:ok, %{status: 200, body: %{"results" => [%{"regularMarketPrice" => price} | _]}}} ->
        {:ok, %{ticker: ticker, price: price || 0.0}}
      {:ok, %{status: status}} ->
        {:error, "#{status} for #{ticker}"}
      {:error, reason} ->
        {:error, "#{inspect(reason)} for #{ticker}"}
    end
  end

  def fetch_crypto(coins, token) when is_list(coins) do
    joined = Enum.join(coins, ",")
    url = "#{@base}/v2/crypto?coin=#{joined}&currency=USD"
    case Req.get(url, headers: auth_headers(token)) do
      {:ok, %{status: 200, body: %{"coins" => coins_data}}} ->
        quotes = Enum.map(coins_data, fn c ->
          %{ticker: c["coin"], price: c["regularMarketPrice"] || 0.0}
        end)
        {:ok, quotes}
      {:ok, %{status: status}} ->
        {:error, "crypto #{status}"}
      {:error, reason} ->
        {:error, "crypto #{inspect(reason)}"}
    end
  end

  def fetch_currency(token) do
    url = "#{@base}/v2/currency?currency=USD-BRL"
    case Req.get(url, headers: auth_headers(token)) do
      {:ok, %{status: 200, body: %{"currency" => [%{"bidPrice" => bid} | _]}}} ->
        rate = if is_binary(bid), do: String.to_float(bid), else: bid
        {:ok, rate || 0.0}
      {:ok, %{status: status}} ->
        {:error, "currency #{status}"}
      {:error, reason} ->
        {:error, "currency #{inspect(reason)}"}
    end
  end

  def refresh_all(portfolio_id) do
    alias Holder.Portfolio

    settings = Portfolio.get_settings(portfolio_id)
    token = settings && settings.brapi_token

    # Collect all tickers by type
    br_tickers =
      (Portfolio.list_assets(portfolio_id, "acoes") ++ Portfolio.list_assets(portfolio_id, "fiis"))
      |> Enum.map(& &1.ticker)
      |> Enum.filter(& &1)

    us_tickers =
      (Portfolio.list_assets(portfolio_id, "stocks") ++
       Portfolio.list_assets(portfolio_id, "reits") ++
       Portfolio.list_assets(portfolio_id, "etfs"))
      |> Enum.map(& &1.ticker)
      |> Enum.filter(& &1)

    crypto_tickers =
      Portfolio.list_assets(portfolio_id, "crypto")
      |> Enum.map(& &1.ticker)
      |> Enum.filter(& &1)

    errors = []

    # Fetch BR quotes (1 per request)
    {br_results, br_errors} = fetch_quotes_batch(br_tickers, token)
    errors = errors ++ br_errors

    # Fetch US quotes (1 per request)
    {us_results, us_errors} = fetch_quotes_batch(us_tickers, token)
    errors = errors ++ us_errors

    # Fetch crypto
    {crypto_results, crypto_errors} = if crypto_tickers != [] do
      case fetch_crypto(crypto_tickers, token) do
        {:ok, quotes} -> {quotes, []}
        {:error, e} -> {[], [e]}
      end
    else
      {[], []}
    end
    errors = errors ++ crypto_errors

    # Fetch currency
    {currency_rate, currency_errors} = case fetch_currency(token) do
      {:ok, rate} -> {rate, []}
      {:error, e} -> {0.0, [e]}
    end
    errors = errors ++ currency_errors

    # Save to quotes cache
    all_quotes = br_results ++ us_results ++ crypto_results
    for %{ticker: ticker, price: price} <- all_quotes do
      Portfolio.upsert_quote(ticker, price)
    end

    # Apply to assets
    Portfolio.apply_quotes_to_assets(portfolio_id)

    # Update dollar rate
    if currency_rate > 0 do
      Portfolio.update_settings(portfolio_id, %{dollar_rate: currency_rate})
    end

    stats = %{
      br: length(br_results),
      us: length(us_results),
      crypto: length(crypto_results),
      currency: currency_rate > 0,
      errors: errors,
      timestamp: DateTime.utc_now()
    }

    # Broadcast
    Phoenix.PubSub.broadcast(Holder.PubSub, "quotes:updated", {:quotes_updated, stats})

    {:ok, stats}
  end

  # ── Private ───────────────────────────────────────────────

  defp fetch_quotes_batch(tickers, token) do
    results =
      tickers
      |> Task.async_stream(fn ticker -> fetch_quote(ticker, token) end, max_concurrency: 5, timeout: 15_000)
      |> Enum.reduce({[], []}, fn
        {:ok, {:ok, quote}}, {quotes, errors} -> {[quote | quotes], errors}
        {:ok, {:error, e}}, {quotes, errors} -> {quotes, [e | errors]}
        {:exit, reason}, {quotes, errors} -> {quotes, ["timeout: #{inspect(reason)}" | errors]}
      end)

    results
  end

  defp auth_headers(nil), do: []
  defp auth_headers(""), do: []
  defp auth_headers(token), do: [{"authorization", "Bearer #{token}"}]
end
