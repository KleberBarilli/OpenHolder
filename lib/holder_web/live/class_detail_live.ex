defmodule HolderWeb.ClassDetailLive do
  use HolderWeb, :live_view

  alias Holder.Portfolio

  @impl true
  def mount(%{"class" => class_key}, _session, socket) do
    portfolio = Portfolio.get_or_create_default_portfolio()
    all_classes = Portfolio.list_asset_classes(portfolio.id)

    {:ok,
     socket
     |> assign(:portfolio_id, portfolio.id)
     |> assign(:all_classes, all_classes)
     |> assign(:edit_id, nil)
     |> assign(:display_mode, :values)
     |> assign(:show_new_class_form, false)
     |> assign(:new_class_errors, %{})
     |> assign_tab_indicators(portfolio.id, all_classes)
     |> load_class(class_key)}
  end

  @impl true
  def handle_params(%{"class" => class_key}, _uri, socket) do
    {:noreply, load_class(socket, class_key)}
  end

  defp load_class(socket, class_key) do
    portfolio_id = socket.assigns.portfolio_id
    ac = Portfolio.get_asset_class_by_key(portfolio_id, class_key)

    if is_nil(ac) do
      push_navigate(socket, to: ~p"/")
    else
      config = %{
        label: ac.label,
        currency: ac.currency,
        has_criteria: ac.has_criteria,
        criteria_type: ac.criteria_type,
        color: ac.color
      }

      assets = Portfolio.list_assets(portfolio_id, class_key)

      fmt =
        if config.currency == "BRL", do: &Portfolio.format_brl/1, else: &Portfolio.format_usd/1

      total_value = compute_total(assets, class_key)

      socket
      |> assign(:class_key, class_key)
      |> assign(:config, config)
      |> assign(:assets, assets)
      |> assign(:fmt, fmt)
      |> assign(:total_value, total_value)
      |> assign(:current_path, "/detail/#{class_key}")
    end
  end

  @impl true
  def handle_event("toggle_display", _params, socket) do
    next =
      case socket.assigns.display_mode do
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

    attrs =
      if params["field"] && params["value"] do
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

    attrs =
      params
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

    attrs =
      if class_key == "rendaFixa" do
        %{
          asset_class: class_key,
          name: "Novo Ativo",
          value: 0.0,
          liquidity: "Boa",
          currency: config.currency
        }
      else
        %{
          asset_class: class_key,
          ticker: "NOVO",
          sector: "",
          qty: 0.0,
          price: 0.0,
          target_pct: 0.0,
          currency: config.currency
        }
      end

    Portfolio.create_asset(socket.assigns.portfolio_id, attrs)
    reload(socket)
  end

  def handle_event("delete_asset", %{"id" => id}, socket) do
    Portfolio.delete_asset(String.to_integer(id))
    reload(socket)
  end

  def handle_event(
        "set_score",
        %{"asset-id" => asset_id, "criterion" => criterion_id, "val" => val},
        socket
      ) do
    asset_id = String.to_integer(asset_id)
    new_val = String.to_integer(val)
    current = Map.get(Portfolio.get_scores_map(asset_id), criterion_id, 0)
    # Clicking the active value toggles it off (back to 0)
    final = if current == new_val, do: 0, else: new_val
    Portfolio.update_asset_score(asset_id, criterion_id, final)
    reload(socket)
  end

  def handle_event("toggle_new_class_form", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_new_class_form, !socket.assigns.show_new_class_form)
     |> assign(:new_class_errors, %{})}
  end

  def handle_event("create_class", params, socket) do
    portfolio_id = socket.assigns.portfolio_id

    attrs = %{
      key: String.trim(params["key"] || ""),
      label: String.trim(params["label"] || ""),
      color: String.trim(params["color"] || "#64748b"),
      currency: params["currency"] || "BRL"
    }

    case Portfolio.create_asset_class(portfolio_id, attrs) do
      {:ok, _ac} ->
        all_classes = Portfolio.list_asset_classes(portfolio_id)

        {:noreply,
         socket
         |> assign(:all_classes, all_classes)
         |> assign(:show_new_class_form, false)
         |> assign(:new_class_errors, %{})
         |> assign_tab_indicators(portfolio_id, all_classes)
         |> put_flash(:info, gettext("Classe criada!"))}

      {:error, changeset} ->
        errors =
          Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
            Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
              opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
            end)
          end)

        {:noreply, assign(socket, :new_class_errors, errors)}
    end
  end

  defp reload(socket) do
    portfolio_id = socket.assigns.portfolio_id
    assets = Portfolio.list_assets(portfolio_id, socket.assigns.class_key)
    total_value = compute_total(assets, socket.assigns.class_key)
    all_classes = socket.assigns.all_classes

    {:noreply,
     socket
     |> assign(:assets, assets)
     |> assign(:total_value, total_value)
     |> assign_tab_indicators(portfolio_id, all_classes)}
  end

  defp assign_tab_indicators(socket, portfolio_id, all_classes) do
    targets_map = Portfolio.get_macro_targets_map(portfolio_id)

    asset_counts =
      Enum.into(all_classes, %{}, fn ac ->
        {ac.key, length(Portfolio.list_assets(portfolio_id, ac.key))}
      end)

    socket
    |> assign(:asset_counts, asset_counts)
    |> assign(:macro_targets_map, targets_map)
  end

  defp compute_total(assets, "rendaFixa") do
    Enum.reduce(assets, 0.0, fn a, acc -> acc + (a.value || 0.0) end)
  end

  defp compute_total(assets, _class_key) do
    Enum.reduce(assets, 0.0, fn a, acc -> acc + (a.qty || 0.0) * (a.price || 0.0) end)
  end

  defp parse_value(field, value)
       when field in ["qty", "price", "value", "target_pct", "dollar_rate", "iof", "spread"] do
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

  defp compute_signal(target_pct, pct_actual_display, target_pct_display) do
    cond do
      target_pct == 0.0 -> nil
      pct_actual_display < target_pct_display -> :buy
      true -> :hold
    end
  end

  defp render_signal(nil), do: ""

  defp render_signal(:buy) do
    assigns = %{}

    ~H"""
    <span class="badge-buy text-[10px]">Buy</span>
    """
  end

  defp render_signal(:hold) do
    assigns = %{}

    ~H"""
    <span class="badge-hold text-[10px]">Hold</span>
    """
  end

  defp format_pct_display(value) do
    :erlang.float_to_binary(value / 1, decimals: 1) <> "%"
  end

  defp format_diff(value) do
    prefix = if value > 0, do: "+", else: ""
    prefix <> :erlang.float_to_binary(value / 1, decimals: 1) <> "%"
  end

  defp compute_sum_pct_actual(assets, total_value, class_key) do
    Enum.reduce(assets, 0.0, fn asset, acc ->
      asset_total =
        if class_key == "rendaFixa",
          do: asset.value || 0.0,
          else: (asset.qty || 0.0) * (asset.price || 0.0)

      pct = if total_value > 0, do: asset_total / total_value * 100, else: 0.0
      acc + pct
    end)
  end

  defp compute_sum_target(assets) do
    Enum.reduce(assets, 0.0, fn asset, acc ->
      acc + (asset.target_pct || 0.0) * 100
    end)
  end

  defp display_label(:values), do: "R$"
  defp display_label(:percent), do: "%"
  defp display_label(:hidden), do: gettext("Oculto")

  defp display_icon(:values), do: "hero-eye-solid"
  defp display_icon(:percent), do: "hero-receipt-percent-solid"
  defp display_icon(:hidden), do: "hero-eye-slash-solid"
end
