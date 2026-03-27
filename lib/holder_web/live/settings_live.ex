defmodule HolderWeb.SettingsLive do
  use HolderWeb, :live_view

  alias Holder.Portfolio
  alias Holder.Vault

  @impl true
  def mount(_params, _session, socket) do
    portfolio = Portfolio.get_or_create_default_portfolio()
    settings = Portfolio.get_settings(portfolio.id)
    targets = Portfolio.get_macro_targets_map(portfolio.id)
    total_target = targets |> Map.values() |> Enum.sum()

    asset_classes = Portfolio.list_all_asset_classes(portfolio.id)
    providers = Holder.AIScoring.providers()
    selected_provider = settings.ai_provider || ""

    stock_criteria = Portfolio.list_all_criteria(portfolio.id, "stock")
    fii_criteria = Portfolio.list_all_criteria(portfolio.id, "fii")

    {:ok,
     socket
     |> assign(:portfolio_id, portfolio.id)
     |> assign(:settings, settings)
     |> assign(:targets, targets)
     |> assign(:total_target, total_target)
     |> assign(:current_path, "/settings")
     |> assign(:edit_class_id, nil)
     |> assign(:all_classes, asset_classes)
     |> assign(:import_step, nil)
     |> assign(:import_preview, nil)
     |> assign(:import_new_classes, [])
     |> assign(:import_csv_raw, nil)
     |> assign(:import_results, nil)
     |> assign(:providers, providers)
     |> assign(:selected_provider, selected_provider)
     |> assign(:has_gemini_key, settings.gemini_api_key_enc not in [nil, ""])
     |> assign(:ai_test_status, nil)
     |> assign(:criteria_tab, "stock")
     |> assign(:stock_criteria, stock_criteria)
     |> assign(:fii_criteria, fii_criteria)
     |> assign(:criteria_errors, %{})
     |> allow_upload(:csv, accept: ~w(.csv), max_entries: 1, max_file_size: 1_000_000)}
  end

  @impl true
  @setting_fields ~w(dollar_rate iof spread aporte_value classes_to_buy min_diff_ignore)
  def handle_event("update_setting", params, socket) do
    attrs =
      params
      |> Map.take(@setting_fields)
      |> Enum.into(%{}, fn {k, v} -> {String.to_existing_atom(k), parse_num(v)} end)

    Portfolio.update_settings(socket.assigns.portfolio_id, attrs)
    settings = Portfolio.get_settings(socket.assigns.portfolio_id)
    {:noreply, assign(socket, :settings, settings)}
  end

  def handle_event("update_token", %{"brapi_token" => token}, socket) do
    Portfolio.update_settings(socket.assigns.portfolio_id, %{brapi_token: String.trim(token)})
    settings = Portfolio.get_settings(socket.assigns.portfolio_id)
    {:noreply, assign(socket, :settings, settings)}
  end

  def handle_event("change_provider", %{"ai_provider" => provider_key}, socket) do
    Portfolio.update_settings(socket.assigns.portfolio_id, %{ai_provider: provider_key})
    settings = Portfolio.get_settings(socket.assigns.portfolio_id)

    {:noreply,
     socket
     |> assign(:settings, settings)
     |> assign(:selected_provider, provider_key)
     |> assign(:has_gemini_key, settings.gemini_api_key_enc not in [nil, ""])
     |> assign(:ai_test_status, nil)}
  end

  def handle_event("save_ai_key", %{"provider" => provider, "api_key" => key}, socket) do
    key = String.trim(key)

    if key == "" do
      {:noreply, socket}
    else
      encrypted = Vault.encrypt(key)
      key_field = provider_key_field(provider)

      Portfolio.update_settings(
        socket.assigns.portfolio_id,
        Map.put(%{ai_provider: provider}, key_field, encrypted)
      )

      settings = Portfolio.get_settings(socket.assigns.portfolio_id)

      {:noreply,
       socket
       |> assign(:settings, settings)
       |> assign(:selected_provider, provider)
       |> assign(:has_gemini_key, settings.gemini_api_key_enc not in [nil, ""])
       |> assign(:ai_test_status, nil)
       |> put_flash(:info, gettext("Chave salva com sucesso!"))}
    end
  end

  def handle_event("test_ai_key", %{"provider" => provider}, socket) do
    enc_key = provider_enc_key(provider, socket.assigns.settings)

    status =
      case Holder.AIScoring.test_connection(provider, enc_key) do
        :ok -> :ok
        {:error, _} -> :error
      end

    {:noreply, assign(socket, :ai_test_status, status)}
  end

  def handle_event("update_target", %{"class" => class, "value" => value}, socket) do
    pct =
      case Float.parse(value) do
        {f, _} -> f / 100
        :error -> 0.0
      end

    Portfolio.update_macro_target(socket.assigns.portfolio_id, class, pct)
    targets = Portfolio.get_macro_targets_map(socket.assigns.portfolio_id)
    total = targets |> Map.values() |> Enum.sum()
    {:noreply, socket |> assign(:targets, targets) |> assign(:total_target, total)}
  end

  def handle_event("validate_csv", _params, socket) do
    {:noreply, socket}
  end

  # Step 1: Upload and parse — show review
  def handle_event("upload_csv", _params, socket) do
    pid = socket.assigns.portfolio_id

    uploaded =
      consume_uploaded_entries(socket, :csv, fn %{path: path}, _entry ->
        csv_content = File.read!(path)
        result = Portfolio.parse_csv(pid, csv_content)
        {:ok, {csv_content, result}}
      end)

    case uploaded do
      [{csv_content, {:ok, preview}}] ->
        {:noreply,
         socket
         |> assign(:import_step, :review)
         |> assign(:import_csv_raw, csv_content)
         |> assign(:import_preview, preview)
         |> assign(:import_new_classes, preview.new_classes)}

      [{_, {:error, reason}}] ->
        {:noreply, put_flash(socket, :error, gettext("Erro: %{reason}", reason: reason))}

      [] ->
        {:noreply, put_flash(socket, :error, gettext("Selecione um arquivo CSV"))}

      other ->
        {:noreply, put_flash(socket, :error, "Unexpected: #{inspect(other)}")}
    end
  end

  # Step 2: Update new class config during review
  def handle_event("update_new_class", %{"key" => key} = params, socket) do
    new_classes =
      Enum.map(socket.assigns.import_new_classes, fn c ->
        if c.key == key do
          c
          |> Map.put(:label, params["label"] || c.label)
          |> Map.put(:color, params["color"] || c.color)
          |> Map.put(:currency, params["currency"] || c.currency)
        else
          c
        end
      end)

    {:noreply, assign(socket, :import_new_classes, new_classes)}
  end

  def handle_event("toggle_skip_class", %{"key" => key}, socket) do
    new_classes =
      Enum.map(socket.assigns.import_new_classes, fn c ->
        if c.key == key, do: Map.put(c, :skip, !c.skip), else: c
      end)

    {:noreply, assign(socket, :import_new_classes, new_classes)}
  end

  # Step 3: Confirm import
  def handle_event("confirm_import", _params, socket) do
    pid = socket.assigns.portfolio_id
    csv = socket.assigns.import_csv_raw

    class_configs =
      socket.assigns.import_new_classes
      |> Enum.into(%{}, fn c -> {c.key, c} end)

    case Portfolio.import_csv_confirmed(pid, csv, class_configs) do
      {:ok, results} ->
        all_classes = Portfolio.list_all_asset_classes(pid)
        asset_classes = Enum.filter(all_classes, & &1.enabled)

        {:noreply,
         socket
         |> assign(:import_step, :done)
         |> assign(:import_results, results)
         |> assign(:all_classes, all_classes)
         |> assign(:asset_classes, asset_classes)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, gettext("Erro: %{reason}", reason: reason))}
    end
  end

  # Cancel import
  def handle_event("cancel_import", _params, socket) do
    {:noreply,
     socket
     |> assign(:import_step, nil)
     |> assign(:import_preview, nil)
     |> assign(:import_new_classes, [])
     |> assign(:import_csv_raw, nil)
     |> assign(:import_results, nil)}
  end

  # ── Asset Classes CRUD ──────────────────────────────────

  def handle_event(
        "add_class",
        %{"key" => key, "label" => label, "color" => color, "currency" => currency},
        socket
      ) do
    key = key |> String.trim() |> String.replace(~r/[^a-zA-Z0-9_]/, "")

    if key != "" and label != "" do
      Portfolio.create_asset_class(socket.assigns.portfolio_id, %{
        key: key,
        label: String.trim(label),
        color: color,
        currency: currency
      })
    end

    reload_classes(socket)
  end

  @class_fields ~w(label color currency)
  def handle_event("update_class", %{"id" => id} = params, socket) do
    attrs =
      params
      |> Map.take(@class_fields)
      |> Enum.into(%{}, fn {k, v} -> {String.to_existing_atom(k), v} end)

    Portfolio.update_asset_class(String.to_integer(id), attrs)
    {_, socket} = reload_classes(socket)

    {:noreply,
     socket |> assign(:edit_class_id, nil) |> put_flash(:info, gettext("Classe atualizada!"))}
  end

  def handle_event("toggle_class", %{"id" => id}, socket) do
    ac = Portfolio.get_asset_class!(String.to_integer(id))
    Portfolio.update_asset_class(ac.id, %{enabled: !ac.enabled})
    reload_classes(socket)
  end

  def handle_event("delete_class", %{"id" => id}, socket) do
    Portfolio.delete_asset_class(String.to_integer(id))
    {_, socket} = reload_classes(socket)
    {:noreply, put_flash(socket, :info, gettext("Classe removida"))}
  end

  def handle_event("toggle_edit_class", %{"id" => id}, socket) do
    id = String.to_integer(id)
    new_id = if socket.assigns.edit_class_id == id, do: nil, else: id
    {:noreply, assign(socket, :edit_class_id, new_id)}
  end

  # ── Scoring Criteria ──────────────────────────────────────

  def handle_event("switch_criteria_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :criteria_tab, tab)}
  end

  def handle_event("update_criterion_label", %{"id" => id, "value" => label}, socket) do
    label = String.trim(label)

    if label != "" do
      Portfolio.update_criterion(String.to_integer(id), %{label: label})
    end

    {:noreply, reload_criteria(socket)}
  end

  def handle_event("toggle_criterion", %{"id" => id}, socket) do
    criterion = Portfolio.get_criterion!(String.to_integer(id))
    Portfolio.update_criterion(criterion.id, %{enabled: !criterion.enabled})
    {:noreply, reload_criteria(socket)}
  end

  def handle_event("delete_criterion", %{"id" => id}, socket) do
    Portfolio.delete_criterion(String.to_integer(id))
    {:noreply, reload_criteria(socket)}
  end

  def handle_event("reorder_criterion", %{"id" => id, "dir" => dir}, socket) do
    direction = if dir == "up", do: :up, else: :down
    Portfolio.reorder_criterion(String.to_integer(id), direction, socket.assigns.portfolio_id)
    {:noreply, reload_criteria(socket)}
  end

  def handle_event("add_criterion", %{"key" => key, "label" => label}, socket) do
    key = key |> String.trim() |> String.replace(~r/[^a-zA-Z0-9_]/, "")
    label = String.trim(label)
    criteria_type = socket.assigns.criteria_tab

    cond do
      key == "" or label == "" ->
        {:noreply,
         assign(socket, :criteria_errors, %{add: gettext("Key e label são obrigatórios")})}

      not Regex.match?(~r/^[a-zA-Z][a-zA-Z0-9_]*$/, key) ->
        {:noreply,
         assign(socket, :criteria_errors, %{add: gettext("Key deve começar com letra")})}

      true ->
        case Portfolio.create_criterion(socket.assigns.portfolio_id, %{
               criteria_type: criteria_type,
               key: key,
               label: label
             }) do
          {:ok, _} ->
            {:noreply, socket |> assign(:criteria_errors, %{}) |> reload_criteria()}

          {:error, changeset} ->
            msg =
              changeset
              |> Ecto.Changeset.traverse_errors(fn {msg, _} -> msg end)
              |> Enum.map_join(", ", fn {_k, v} -> Enum.join(v, ", ") end)

            {:noreply, assign(socket, :criteria_errors, %{add: msg})}
        end
    end
  end

  def handle_event("export", _params, socket) do
    json = Portfolio.export_json(socket.assigns.portfolio_id)
    date = Date.utc_today() |> Date.to_iso8601()
    filename = "holder-backup-#{date}.json"

    {:noreply,
     socket
     |> push_event("download", %{data: json, filename: filename, content_type: "application/json"})}
  end

  def handle_event("reset", _params, socket) do
    for class <- ["acoes", "fiis", "stocks", "reits", "etfs", "crypto", "rendaFixa"] do
      assets = Portfolio.list_assets(socket.assigns.portfolio_id, class)
      for a <- assets, do: Portfolio.delete_asset(a.id)
    end

    Portfolio.update_settings(socket.assigns.portfolio_id, %{
      dollar_rate: 5.80,
      iof: 0.035,
      spread: 0.01,
      aporte_value: 0.0,
      classes_to_buy: 0
    })

    settings = Portfolio.get_settings(socket.assigns.portfolio_id)
    targets = Portfolio.get_macro_targets_map(socket.assigns.portfolio_id)
    total = targets |> Map.values() |> Enum.sum()

    {:noreply,
     socket
     |> assign(:settings, settings)
     |> assign(:targets, targets)
     |> assign(:total_target, total)
     |> put_flash(:info, gettext("Dados resetados com sucesso"))}
  end

  defp reload_criteria(socket) do
    pid = socket.assigns.portfolio_id

    socket
    |> assign(:stock_criteria, Portfolio.list_all_criteria(pid, "stock"))
    |> assign(:fii_criteria, Portfolio.list_all_criteria(pid, "fii"))
  end

  defp reload_classes(socket) do
    all_classes = Portfolio.list_all_asset_classes(socket.assigns.portfolio_id)
    asset_classes = Enum.filter(all_classes, & &1.enabled)

    {:noreply,
     socket |> assign(:all_classes, all_classes) |> assign(:asset_classes, asset_classes)}
  end

  defp parse_num(val) when is_binary(val) do
    case Float.parse(val) do
      {f, _} -> f
      :error -> 0.0
    end
  end

  defp parse_num(val), do: val

  defp provider_key_field("gemini"), do: :gemini_api_key_enc
  defp provider_key_field(_), do: :gemini_api_key_enc

  defp provider_enc_key("gemini", settings), do: settings.gemini_api_key_enc
  defp provider_enc_key(_, _), do: nil
end
