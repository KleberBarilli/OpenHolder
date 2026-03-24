defmodule HolderWeb.DashboardLive do
  use HolderWeb, :live_view

  alias Holder.Portfolio

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Holder.PubSub, "quotes:updated")
    end

    portfolio = Portfolio.get_or_create_default_portfolio()
    summary = Portfolio.compute_macro_summary(portfolio.id)
    settings = Portfolio.get_settings(portfolio.id)

    {:ok,
     socket
     |> assign(:portfolio_id, portfolio.id)
     |> assign(:summary, summary)
     |> assign(:settings, settings)
     |> assign(:display_mode, :values)
     |> assign(:current_path, "/")
     |> assign(:refresh_status, :idle)
     |> assign(:refresh_stats, nil)}
  end

  @impl true
  def handle_event("toggle_display", _params, socket) do
    next = case socket.assigns.display_mode do
      :values -> :percent
      :percent -> :hidden
      :hidden -> :values
    end
    {:noreply, assign(socket, :display_mode, next)}
  end

  @refresh_cooldown_ms 5 * 60 * 1000  # 5 minutes
  def handle_event("refresh_quotes", _params, socket) do
    last = socket.assigns[:last_refresh_at]
    now = System.monotonic_time(:millisecond)

    if is_nil(last) or (now - last) > @refresh_cooldown_ms do
      send(self(), :do_refresh)
      {:noreply, socket |> assign(:refresh_status, :loading) |> assign(:last_refresh_at, now)}
    else
      remaining = div(@refresh_cooldown_ms - (now - last), 60_000) + 1
      {:noreply, put_flash(socket, :error, gettext("Aguarde %{min} min antes de atualizar novamente", min: remaining))}
    end
  end

  def handle_event("navigate_detail", %{"class" => class}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/detail/#{class}")}
  end

  @impl true
  def handle_info(:do_refresh, socket) do
    case Holder.BrAPI.refresh_all(socket.assigns.portfolio_id) do
      {:ok, stats} ->
        summary = Portfolio.compute_macro_summary(socket.assigns.portfolio_id)
        settings = Portfolio.get_settings(socket.assigns.portfolio_id)
        {:noreply,
         socket
         |> assign(:summary, summary)
         |> assign(:settings, settings)
         |> assign(:refresh_status, if(stats.errors == [], do: :success, else: :error))
         |> assign(:refresh_stats, stats)}
      {:error, _} ->
        {:noreply, assign(socket, :refresh_status, :error)}
    end
  end

  def handle_info({:quotes_updated, _stats}, socket) do
    summary = Portfolio.compute_macro_summary(socket.assigns.portfolio_id)
    settings = Portfolio.get_settings(socket.assigns.portfolio_id)
    {:noreply,
     socket
     |> assign(:summary, summary)
     |> assign(:settings, settings)}
  end

  # ── Helpers ──────────────────────────────────────────

  defp mask(value, formatter, _pct, :hidden), do: "•••••"
  defp mask(_value, _formatter, pct, :percent) when not is_nil(pct), do: Portfolio.format_pct(pct)
  defp mask(value, formatter, _pct, _mode), do: formatter.(value)

  defp display_label(:values), do: "R$"
  defp display_label(:percent), do: "%"
  defp display_label(:hidden), do: gettext("Oculto")

  defp display_icon(:values), do: "hero-eye-solid"
  defp display_icon(:percent), do: "hero-receipt-percent-solid"
  defp display_icon(:hidden), do: "hero-eye-slash-solid"

  defp pie_chart_config(classes) do
    data = classes |> Enum.filter(& &1.value > 0)
    %{
      "type" => "doughnut",
      "data" => %{
        "labels" => Enum.map(data, & &1.label),
        "datasets" => [%{
          "data" => Enum.map(data, & &1.value),
          "backgroundColor" => Enum.map(data, & &1.color),
          "borderWidth" => 0
        }]
      },
      "options" => %{
        "cutout" => "60%",
        "responsive" => true,
        "maintainAspectRatio" => false,
        "plugins" => %{
          "legend" => %{"display" => false},
          "tooltip" => %{
            "backgroundColor" => "#1a1a26",
            "borderColor" => "#2a2a3d",
            "borderWidth" => 1,
            "titleColor" => "#f1f5f9",
            "bodyColor" => "#94a3b8"
          }
        }
      }
    }
  end

  defp bar_chart_config(classes) do
    data = classes |> Enum.filter(& &1.target > 0)
    %{
      "type" => "bar",
      "data" => %{
        "labels" => Enum.map(data, & &1.label),
        "datasets" => [
          %{"label" => gettext("Atual"), "data" => Enum.map(data, &Float.round(&1.current_pct * 100, 1)), "backgroundColor" => "#64748b", "borderRadius" => 4},
          %{"label" => gettext("Objetivo"), "data" => Enum.map(data, &Float.round(&1.target * 100, 1)), "backgroundColor" => "#34d399", "borderRadius" => 4}
        ]
      },
      "options" => %{
        "responsive" => true,
        "maintainAspectRatio" => false,
        "scales" => %{
          "x" => %{"grid" => %{"color" => "#222233"}, "ticks" => %{"color" => "#64748b", "font" => %{"size" => 10}}},
          "y" => %{"grid" => %{"color" => "#222233"}, "ticks" => %{"color" => "#64748b", "font" => %{"size" => 10}, "callback_suffix" => "%"}}
        },
        "plugins" => %{
          "legend" => %{"display" => false},
          "tooltip" => %{
            "backgroundColor" => "#1a1a26",
            "borderColor" => "#2a2a3d",
            "borderWidth" => 1
          }
        }
      }
    }
  end
end
