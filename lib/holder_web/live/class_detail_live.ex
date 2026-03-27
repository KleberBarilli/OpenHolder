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
     |> assign(:sort_by, :sort_order)
     |> assign(:sort_dir, :asc)
     |> assign(:show_new_class_form, false)
     |> assign(:new_class_errors, %{})
     |> assign(:show_add_form, false)
     |> assign(:add_form_errors, %{})
     |> assign(:all_tickers, Portfolio.list_all_tickers(portfolio.id))
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
      |> assign(:sort_by, :sort_order)
      |> assign(:sort_dir, :asc)
      |> assign(:show_add_form, false)
      |> assign(:add_form_errors, %{})
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

  def handle_event("sort", %{"col" => col}, socket) do
    col_atom = String.to_existing_atom(col)

    {new_by, new_dir} =
      if socket.assigns.sort_by == col_atom do
        {col_atom, if(socket.assigns.sort_dir == :asc, do: :desc, else: :asc)}
      else
        {col_atom, :asc}
      end

    {:noreply, assign(socket, sort_by: new_by, sort_dir: new_dir)}
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

  def handle_event("toggle_add_form", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_add_form, !socket.assigns.show_add_form)
     |> assign(:add_form_errors, %{})}
  end

  def handle_event("create_new_asset", params, socket) do
    class_key = socket.assigns.class_key
    config = socket.assigns.config
    errors = validate_add_form(params, class_key)

    if errors == %{} do
      attrs =
        if class_key == "rendaFixa" do
          %{
            asset_class: class_key,
            name: String.trim(params["name"] || ""),
            value: parse_float(params["value"]),
            liquidity: params["liquidity"] || "Boa",
            currency: config.currency
          }
        else
          %{
            asset_class: class_key,
            ticker: String.trim(params["ticker"] || "") |> String.upcase(),
            qty: parse_float(params["qty"]),
            price: parse_float(params["price"]),
            target_pct: parse_float(params["target_pct"]) / 100,
            currency: config.currency
          }
        end

      Portfolio.create_asset(socket.assigns.portfolio_id, attrs)
      {_, socket} = reload(socket)

      {:noreply,
       socket
       |> assign(:show_add_form, false)
       |> assign(:add_form_errors, %{})
       |> put_flash(:info, gettext("Ativo adicionado!"))}
    else
      {:noreply, assign(socket, :add_form_errors, errors)}
    end
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

  def handle_event("inline_save", params, socket) do
    asset_id = String.to_integer(params["id"])
    field = params["field"]
    raw_value = params["value"] || ""

    case validate_inline(field, raw_value) do
      {:ok, value} ->
        value = if field == "target_pct", do: value / 100, else: value
        Portfolio.update_asset(asset_id, %{String.to_existing_atom(field) => value})
        {_, socket} = reload(socket)
        {:noreply, push_event(socket, "inline-ok", %{id: "inline-#{asset_id}-#{field}"})}

      {:error, msg} ->
        {:noreply,
         push_event(socket, "inline-err", %{id: "inline-#{asset_id}-#{field}", msg: msg})}
    end
  end

  defp validate_inline("price", raw) do
    case Float.parse(raw) do
      {v, _} when v >= 0 -> {:ok, v}
      {_, _} -> {:error, gettext("Cotação não pode ser negativa")}
      :error -> {:error, gettext("Valor inválido")}
    end
  end

  defp validate_inline("qty", raw) do
    case Float.parse(raw) do
      {v, _} when v >= 0 -> {:ok, v}
      {_, _} -> {:error, gettext("Quantidade não pode ser negativa")}
      :error -> {:error, gettext("Valor inválido")}
    end
  end

  defp validate_inline("target_pct", raw) do
    case Float.parse(raw) do
      {v, _} when v >= 0 and v <= 100 -> {:ok, v}
      {_, _} -> {:error, gettext("% Objetivo deve ser entre 0 e 100")}
      :error -> {:error, gettext("Valor inválido")}
    end
  end

  defp validate_inline("value", raw) do
    case Float.parse(raw) do
      {v, _} when v >= 0 -> {:ok, v}
      {_, _} -> {:error, gettext("Valor não pode ser negativo")}
      :error -> {:error, gettext("Valor inválido")}
    end
  end

  defp validate_inline(_field, raw) do
    case Float.parse(raw) do
      {v, _} -> {:ok, v}
      :error -> {:error, gettext("Valor inválido")}
    end
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

  defp validate_add_form(params, "rendaFixa") do
    errors = %{}
    name = String.trim(params["name"] || "")

    errors =
      if name == "", do: Map.put(errors, :name, gettext("Nome é obrigatório")), else: errors

    case Float.parse(params["value"] || "") do
      {v, _} when v >= 0 -> errors
      {_, _} -> Map.put(errors, :value, gettext("Valor não pode ser negativo"))
      :error -> Map.put(errors, :value, gettext("Valor inválido"))
    end
  end

  defp validate_add_form(params, _class_key) do
    errors = %{}
    ticker = String.trim(params["ticker"] || "")

    errors =
      if ticker == "", do: Map.put(errors, :ticker, gettext("Ticker é obrigatório")), else: errors

    errors =
      case Float.parse(params["qty"] || "") do
        {v, _} when v >= 0 ->
          errors

        {_, _} ->
          Map.put(errors, :qty, gettext("Quantidade não pode ser negativa"))

        :error ->
          if params["qty"] in [nil, ""],
            do: errors,
            else: Map.put(errors, :qty, gettext("Valor inválido"))
      end

    errors =
      case Float.parse(params["price"] || "") do
        {v, _} when v >= 0 ->
          errors

        {_, _} ->
          Map.put(errors, :price, gettext("Cotação não pode ser negativa"))

        :error ->
          if params["price"] in [nil, ""],
            do: errors,
            else: Map.put(errors, :price, gettext("Valor inválido"))
      end

    case Float.parse(params["target_pct"] || "") do
      {v, _} when v >= 0 and v <= 100 ->
        errors

      {_, _} ->
        Map.put(errors, :target_pct, gettext("% Objetivo deve ser entre 0 e 100"))

      :error ->
        if params["target_pct"] in [nil, ""],
          do: errors,
          else: Map.put(errors, :target_pct, gettext("Valor inválido"))
    end
  end

  defp parse_float(nil), do: 0.0
  defp parse_float(""), do: 0.0

  defp parse_float(str) do
    case Float.parse(str) do
      {v, _} -> v
      :error -> 0.0
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
     |> assign(:all_tickers, Portfolio.list_all_tickers(portfolio_id))
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

  defp sorted_assets(assigns) do
    assets = assigns.assets
    sort_by = assigns.sort_by
    sort_dir = assigns.sort_dir
    class_key = assigns.class_key
    total_value = assigns.total_value

    sort_assets(assets, sort_by, sort_dir, class_key, total_value)
  end

  defp sort_assets(assets, :sort_order, :asc, _class_key, _total_value), do: assets

  defp sort_assets(assets, :sort_order, :desc, _class_key, _total_value),
    do: Enum.reverse(assets)

  defp sort_assets(assets, :ticker, dir, _class_key, _total_value) do
    Enum.sort_by(assets, &String.downcase(&1.ticker || &1.name || ""), sort_comparator(dir))
  end

  defp sort_assets(assets, :valor, dir, class_key, _total_value) do
    Enum.sort_by(assets, &asset_value(&1, class_key), sort_comparator(dir))
  end

  defp sort_assets(assets, :pct_atual, dir, class_key, total_value) do
    Enum.sort_by(
      assets,
      fn a ->
        v = asset_value(a, class_key)
        if total_value > 0, do: v / total_value, else: 0.0
      end,
      sort_comparator(dir)
    )
  end

  defp sort_assets(assets, :target_pct, dir, _class_key, _total_value) do
    Enum.sort_by(assets, &(&1.target_pct || 0.0), sort_comparator(dir))
  end

  defp sort_assets(assets, :diff, dir, class_key, total_value) do
    Enum.sort_by(
      assets,
      fn a ->
        v = asset_value(a, class_key)
        pct_actual = if total_value > 0, do: v / total_value * 100, else: 0.0
        target_display = (a.target_pct || 0.0) * 100
        target_display - pct_actual
      end,
      sort_comparator(dir)
    )
  end

  defp sort_assets(assets, :nota, dir, _class_key, _total_value) do
    Enum.sort_by(
      assets,
      fn a ->
        score = Portfolio.compute_score(a)
        if is_integer(score), do: score, else: -999
      end,
      sort_comparator(dir)
    )
  end

  defp sort_assets(assets, _unknown, _dir, _class_key, _total_value), do: assets

  defp asset_value(asset, "rendaFixa"), do: asset.value || 0.0
  defp asset_value(asset, _class_key), do: (asset.qty || 0.0) * (asset.price || 0.0)

  defp sort_comparator(:asc), do: :asc
  defp sort_comparator(:desc), do: :desc

  defp display_label(:values), do: "R$"
  defp display_label(:percent), do: "%"
  defp display_label(:hidden), do: gettext("Oculto")

  defp display_icon(:values), do: "hero-eye-solid"
  defp display_icon(:percent), do: "hero-receipt-percent-solid"
  defp display_icon(:hidden), do: "hero-eye-slash-solid"
end
