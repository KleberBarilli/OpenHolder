defmodule HolderWeb.ClassDetailLive do
  use HolderWeb, :live_view

  alias Holder.Portfolio

  @impl true
  def mount(%{"class" => class_key}, _session, socket) do
    portfolio = Portfolio.get_or_create_default_portfolio()
    ac = Portfolio.get_asset_class_by_key(portfolio.id, class_key)

    if is_nil(ac) do
      {:ok, push_navigate(socket, to: ~p"/")}
    else
      config = %{label: ac.label, currency: ac.currency, has_criteria: ac.has_criteria, criteria_type: ac.criteria_type, color: ac.color}
      assets = Portfolio.list_assets(portfolio.id, class_key)
      fmt = if config.currency == "BRL", do: &Portfolio.format_brl/1, else: &Portfolio.format_usd/1

      total_value = compute_total(assets, class_key)

      {:ok,
       socket
       |> assign(:portfolio_id, portfolio.id)
       |> assign(:class_key, class_key)
       |> assign(:config, config)
       |> assign(:assets, assets)
       |> assign(:fmt, fmt)
       |> assign(:total_value, total_value)
       |> assign(:edit_id, nil)
       |> assign(:display_mode, :values)
       |> assign(:current_path, "/detail/#{class_key}")}
    end
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

  def handle_event("toggle_edit", %{"id" => id}, socket) do
    id = String.to_integer(id)
    new_id = if socket.assigns.edit_id == id, do: nil, else: id
    {:noreply, assign(socket, :edit_id, new_id)}
  end

  def handle_event("update_asset", %{"id" => id} = params, socket) do
    id = String.to_integer(id)
    attrs = %{}
    attrs = if params["field"] && params["value"] do
      field = String.to_existing_atom(params["field"])
      value = parse_value(params["field"], params["value"])
      Map.put(attrs, field, value)
    else
      attrs
    end

    Portfolio.update_asset(id, attrs)
    reload(socket)
  end

  @asset_fields ~w(ticker name sector asset_type qty price value target_pct score liquidity)
  def handle_event("save_asset", %{"id" => id} = params, socket) do
    id = String.to_integer(id)

    attrs = params
    |> Map.take(@asset_fields)
    |> Enum.into(%{}, fn {k, v} ->
      val = parse_value(k, v)
      val = if k == "target_pct" and is_number(val), do: val / 100, else: val
      {String.to_existing_atom(k), val}
    end)

    Portfolio.update_asset(id, attrs)
    {_, socket} = reload(socket)
    {:noreply, socket |> assign(:edit_id, nil) |> put_flash(:info, gettext("Ativo salvo!"))}
  end

  def handle_event("add_asset", _params, socket) do
    class_key = socket.assigns.class_key
    config = socket.assigns.config

    attrs = if class_key == "rendaFixa" do
      %{asset_class: class_key, name: "Novo Ativo", value: 0.0, liquidity: "Boa", currency: config.currency}
    else
      %{asset_class: class_key, ticker: "NOVO", sector: "", qty: 0.0, price: 0.0, target_pct: 0.0, currency: config.currency}
    end

    Portfolio.create_asset(socket.assigns.portfolio_id, attrs)
    reload(socket)
  end

  def handle_event("delete_asset", %{"id" => id}, socket) do
    Portfolio.delete_asset(String.to_integer(id))
    reload(socket)
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
    reload(socket)
  end

  defp reload(socket) do
    assets = Portfolio.list_assets(socket.assigns.portfolio_id, socket.assigns.class_key)
    total_value = compute_total(assets, socket.assigns.class_key)
    {:noreply, socket |> assign(:assets, assets) |> assign(:total_value, total_value)}
  end

  defp compute_total(assets, "rendaFixa") do
    Enum.reduce(assets, 0.0, fn a, acc -> acc + (a.value || 0.0) end)
  end
  defp compute_total(assets, _class_key) do
    Enum.reduce(assets, 0.0, fn a, acc -> acc + (a.qty || 0.0) * (a.price || 0.0) end)
  end

  defp parse_value(field, value) when field in ["qty", "price", "value", "target_pct", "dollar_rate", "iof", "spread"] do
    case Float.parse(value) do
      {f, _} -> f
      :error -> 0.0
    end
  end
  defp parse_value(field, value) when field in ["score", "sort_order", "classes_to_buy"] do
    case Integer.parse(value) do
      {i, _} -> i
      :error -> 0
    end
  end
  defp parse_value(_field, value), do: value

  defp mask(_value, _fmt, _pct, :hidden), do: "•••••"
  defp mask(_value, _fmt, pct, :percent) when not is_nil(pct), do: Portfolio.format_pct(pct)
  defp mask(value, fmt, _pct, _mode), do: fmt.(value)

  defp criteria_for("acoes"), do: Portfolio.stock_criteria()
  defp criteria_for("fiis"), do: Portfolio.fii_criteria()
  defp criteria_for(_), do: []

  defp display_label(:values), do: "R$"
  defp display_label(:percent), do: "%"
  defp display_label(:hidden), do: gettext("Oculto")

  defp display_icon(:values), do: "hero-eye-solid"
  defp display_icon(:percent), do: "hero-receipt-percent-solid"
  defp display_icon(:hidden), do: "hero-eye-slash-solid"
end
