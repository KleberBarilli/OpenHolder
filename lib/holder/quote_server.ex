defmodule Holder.QuoteServer do
  use GenServer
  require Logger

  @market_interval :timer.minutes(5)
  @off_market_interval :timer.minutes(30)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def refresh_now(portfolio_id \\ 1) do
    GenServer.call(__MODULE__, {:refresh, portfolio_id}, 60_000)
  end

  @impl true
  def init(_opts) do
    schedule_tick()
    {:ok, %{last_refresh: nil}}
  end

  @impl true
  def handle_call({:refresh, portfolio_id}, _from, state) do
    result = do_refresh(portfolio_id)
    {:reply, result, %{state | last_refresh: DateTime.utc_now()}}
  end

  @impl true
  def handle_info(:tick, state) do
    portfolio = Holder.Portfolio.get_or_create_default_portfolio()
    settings = Holder.Portfolio.get_settings(portfolio.id)

    if settings && settings.brapi_token && settings.brapi_token != "" do
      do_refresh(portfolio.id)
    end

    schedule_tick()
    {:noreply, %{state | last_refresh: DateTime.utc_now()}}
  end

  defp do_refresh(portfolio_id) do
    case Holder.BrAPI.refresh_all(portfolio_id) do
      {:ok, stats} ->
        Logger.info("Quotes refreshed: BR=#{stats.br} US=#{stats.us} Crypto=#{stats.crypto}")
        {:ok, stats}
      {:error, reason} ->
        Logger.error("Quote refresh failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp schedule_tick do
    interval = if market_open?(), do: @market_interval, else: @off_market_interval
    Process.send_after(self(), :tick, interval)
  end

  defp market_open? do
    now = DateTime.utc_now()
    hour = now.hour
    # B3: 13:00-20:55 UTC (10:00-17:55 BRT)
    # NYSE: 14:30-21:00 UTC (10:30-17:00 EST)
    # Simplified: 13:00-21:00 UTC covers both
    hour >= 13 and hour < 21
  end
end
