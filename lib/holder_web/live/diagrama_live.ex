defmodule HolderWeb.DiagramaLive do
  use HolderWeb, :live_view

  alias Holder.Portfolio

  @impl true
  def mount(_params, _session, socket) do
    portfolio = Portfolio.get_or_create_default_portfolio()
    tab = "acoes"
    assets = Portfolio.list_assets(portfolio.id, tab)

    {:ok,
     socket
     |> assign(:portfolio_id, portfolio.id)
     |> assign(:tab, tab)
     |> assign(:assets, assets)
     |> assign(:expanded_id, nil)
     |> assign(:current_path, "/diagrama")}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    assets = Portfolio.list_assets(socket.assigns.portfolio_id, tab)
    {:noreply, socket |> assign(:tab, tab) |> assign(:assets, assets) |> assign(:expanded_id, nil)}
  end

  def handle_event("toggle_expand", %{"id" => id}, socket) do
    id = String.to_integer(id)
    new_id = if socket.assigns.expanded_id == id, do: nil, else: id
    {:noreply, assign(socket, :expanded_id, new_id)}
  end

  def handle_event("cycle_score", %{"asset-id" => asset_id, "criterion" => criterion_id}, socket) do
    asset_id = String.to_integer(asset_id)
    scores_map = Portfolio.get_scores_map(asset_id)
    current = Map.get(scores_map, criterion_id, 0)
    next = case current do
      1 -> -1
      -1 -> 0
      _ -> 1
    end
    Portfolio.update_asset_score(asset_id, criterion_id, next)
    assets = Portfolio.list_assets(socket.assigns.portfolio_id, socket.assigns.tab)
    {:noreply, assign(socket, :assets, assets)}
  end

  defp criteria_for("acoes"), do: Portfolio.stock_criteria()
  defp criteria_for("fiis"), do: Portfolio.fii_criteria()
  defp criteria_for(_), do: []

  defp score_distribution(assets) do
    Enum.reduce(assets, %{excellent: 0, good: 0, weak: 0}, fn asset, acc ->
      score = Portfolio.compute_score(asset)
      cond do
        score == "SN" -> acc
        is_integer(score) and score >= 9 -> %{acc | excellent: acc.excellent + 1}
        is_integer(score) and score >= 5 -> %{acc | good: acc.good + 1}
        true -> %{acc | weak: acc.weak + 1}
      end
    end)
  end
end
