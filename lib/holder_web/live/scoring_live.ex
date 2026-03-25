defmodule HolderWeb.ScoringLive do
  use HolderWeb, :live_view

  alias Holder.Portfolio

  @impl true
  def mount(_params, _session, socket) do
    portfolio = Portfolio.get_or_create_default_portfolio()
    settings = Portfolio.get_settings(portfolio.id)
    tab = "acoes"
    assets = Portfolio.list_assets(portfolio.id, tab)

    ai_available =
      settings &&
        settings.ai_provider == "gemini" &&
        settings.gemini_api_key_enc not in [nil, ""]

    {:ok,
     socket
     |> assign(:portfolio_id, portfolio.id)
     |> assign(:settings, settings)
     |> assign(:tab, tab)
     |> assign(:assets, assets)
     |> assign(:expanded_id, nil)
     |> assign(:ai_available, ai_available == true)
     |> assign(:ai_loading, MapSet.new())
     |> assign(:ai_batch_progress, nil)
     |> assign(:current_path, "/scoring")}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    assets = Portfolio.list_assets(socket.assigns.portfolio_id, tab)

    {:noreply,
     socket
     |> assign(:tab, tab)
     |> assign(:assets, assets)
     |> assign(:expanded_id, nil)
     |> assign(:ai_batch_progress, nil)}
  end

  def handle_event("toggle_expand", %{"id" => id}, socket) do
    id = String.to_integer(id)
    new_id = if socket.assigns.expanded_id == id, do: nil, else: id
    {:noreply, assign(socket, :expanded_id, new_id)}
  end

  def handle_event("set_score", %{"asset-id" => asset_id, "criterion" => criterion_id, "val" => val}, socket) do
    asset_id = String.to_integer(asset_id)
    new_val = String.to_integer(val)
    current = Map.get(Portfolio.get_scores_map(asset_id), criterion_id, 0)
    final = if current == new_val, do: 0, else: new_val
    Portfolio.update_asset_score(asset_id, criterion_id, final, source: "manual")
    assets = Portfolio.list_assets(socket.assigns.portfolio_id, socket.assigns.tab)
    {:noreply, assign(socket, :assets, assets)}
  end

  def handle_event("ai_score_one", %{"id" => id}, socket) do
    asset_id = String.to_integer(id)
    asset = Enum.find(socket.assigns.assets, &(&1.id == asset_id))

    if asset && socket.assigns.ai_available do
      loading = MapSet.put(socket.assigns.ai_loading, asset_id)
      self_pid = self()

      Task.Supervisor.start_child(Holder.AITaskSupervisor, fn ->
        result =
          try do
            Holder.AIScoring.score_asset(asset, socket.assigns.settings)
          rescue
            e -> {:error, Exception.message(e)}
          end

        send(self_pid, {:ai_score_progress, asset_id, result})
      end)

      {:noreply, assign(socket, :ai_loading, loading)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("ai_score_all", _params, socket) do
    scorable =
      socket.assigns.assets
      |> Enum.filter(&(&1.ticker && &1.ticker != ""))

    if scorable != [] && socket.assigns.ai_available do
      progress = %{ok: 0, errors: 0, total: length(scorable), done: false}

      Holder.AIScoring.score_batch(scorable, socket.assigns.settings, self())

      {:noreply,
       socket
       |> assign(:ai_loading, MapSet.new(Enum.map(scorable, & &1.id)))
       |> assign(:ai_batch_progress, progress)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:ai_score_progress, asset_id, result}, socket) do
    loading = MapSet.delete(socket.assigns.ai_loading, asset_id)
    assets = Portfolio.list_assets(socket.assigns.portfolio_id, socket.assigns.tab)

    socket =
      case result do
        {:ok, _} -> socket
        {:error, reason} ->
          asset = Enum.find(assets, &(&1.id == asset_id))
          ticker = if asset, do: asset.ticker, else: "##{asset_id}"
          put_flash(socket, :error, "#{ticker}: #{format_error(reason)}")
      end

    progress =
      case {socket.assigns.ai_batch_progress, result} do
        {nil, _} -> nil
        {p, {:ok, _}} -> %{p | ok: p.ok + 1}
        {p, {:error, _}} -> %{p | errors: p.errors + 1}
      end

    {:noreply,
     socket
     |> assign(:assets, assets)
     |> assign(:ai_loading, loading)
     |> assign(:ai_batch_progress, progress)}
  end

  def handle_info({:ai_score_done, summary}, socket) do
    assets = Portfolio.list_assets(socket.assigns.portfolio_id, socket.assigns.tab)

    {:noreply,
     socket
     |> assign(:assets, assets)
     |> assign(:ai_loading, MapSet.new())
     |> assign(:ai_batch_progress, %{summary | done: true})
     |> put_flash(:info, gettext("%{ok}/%{total} ativos pontuados com IA", ok: summary.ok, total: summary.total))}
  end

  defp format_error(:no_provider_configured), do: gettext("Provedor de IA não configurado")
  defp format_error(:no_api_key), do: gettext("Chave API não encontrada")
  defp format_error(:invalid_api_key), do: gettext("Chave API inválida")
  defp format_error(:rate_limited), do: gettext("Rate limit atingido, tente novamente")
  defp format_error(:invalid_json), do: gettext("Resposta inválida da IA")
  defp format_error(:invalid_response_format), do: gettext("Formato de resposta inesperado")
  defp format_error(:timeout), do: gettext("Timeout na chamada da IA")
  defp format_error(msg) when is_binary(msg), do: msg
  defp format_error(other), do: inspect(other)

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
