defmodule HolderWeb.RebalanceLive do
  use HolderWeb, :live_view

  alias Holder.Portfolio

  @impl true
  def mount(_params, _session, socket) do
    portfolio = Portfolio.get_or_create_default_portfolio()
    settings = Portfolio.get_settings(portfolio.id)
    summary = Portfolio.compute_macro_summary(portfolio.id)

    aporte = (settings && settings.aporte_value) || 0.0
    num_classes = (settings && settings.classes_to_buy) || 2
    num_classes = if num_classes < 1, do: 2, else: num_classes

    suggestion = compute_suggestion(summary, aporte, num_classes)

    {:ok,
     socket
     |> assign(:portfolio_id, portfolio.id)
     |> assign(:summary, summary)
     |> assign(:aporte_value, aporte)
     |> assign(:num_classes, num_classes)
     |> assign(:suggestion, suggestion)
     |> assign(:display_mode, :values)
     |> assign(:current_path, "/rebalance")}
  end

  @impl true
  def handle_event("update_aporte", %{"value" => value}, socket) do
    aporte = case Float.parse(value) do
      {f, _} -> f
      :error -> 0.0
    end
    suggestion = compute_suggestion(socket.assigns.summary, aporte, socket.assigns.num_classes)
    {:noreply, socket |> assign(:aporte_value, aporte) |> assign(:suggestion, suggestion)}
  end

  def handle_event("update_num_classes", %{"value" => value}, socket) do
    n = case Integer.parse(value) do
      {i, _} -> max(i, 1)
      :error -> 2
    end
    suggestion = compute_suggestion(socket.assigns.summary, socket.assigns.aporte_value, n)
    {:noreply, socket |> assign(:num_classes, n) |> assign(:suggestion, suggestion)}
  end

  def handle_event("toggle_display", _params, socket) do
    next = case socket.assigns.display_mode do
      :values -> :percent
      :percent -> :hidden
      :hidden -> :values
    end
    {:noreply, assign(socket, :display_mode, next)}
  end

  defp compute_suggestion(summary, aporte, num_classes) do
    if summary.grand_total == 0 or aporte == 0 do
      []
    else
      eligible = summary.classes
        |> Enum.filter(& &1.target > 0)
        |> Enum.sort_by(& &1.diff, :desc)
        |> Enum.take(num_classes)
        |> Enum.filter(& &1.diff > 0)

      if eligible == [] do
        []
      else
        total_diff_value = Enum.reduce(eligible, 0.0, fn c, acc ->
          needed = c.target * (summary.grand_total + aporte) - c.value
          acc + max(needed, 0)
        end)

        Enum.map(eligible, fn c ->
          needed = c.target * (summary.grand_total + aporte) - c.value
          proportion = if total_diff_value > 0, do: max(needed, 0) / total_diff_value, else: 1 / length(eligible)
          amount = aporte * proportion
          Map.put(c, :suggested_amount, amount)
        end)
      end
    end
  end

  defp mask(_value, _fmt, _pct, :hidden), do: "•••••"
  defp mask(_value, _fmt, pct, :percent) when not is_nil(pct), do: Portfolio.format_pct(pct)
  defp mask(value, fmt, _pct, _mode), do: fmt.(value)

  defp display_label(:values), do: "R$"
  defp display_label(:percent), do: "%"
  defp display_label(:hidden), do: gettext("Oculto")

  defp display_icon(:values), do: "hero-eye-solid"
  defp display_icon(:percent), do: "hero-receipt-percent-solid"
  defp display_icon(:hidden), do: "hero-eye-slash-solid"
end
