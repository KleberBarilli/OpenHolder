defmodule Holder.AIScoring do
  @moduledoc """
  Orchestrates AI-powered asset scoring.
  Delegates to provider modules (OpenAI/Gemini), validates responses,
  and persists scores.
  """

  alias Holder.Portfolio
  alias Holder.Vault
  require Logger

  @doc """
  Scores a single asset using the configured AI provider.
  Returns `{:ok, %{scores: map, total: integer}}` or `{:error, reason}`.
  """
  def score_asset(asset, settings) do
    Logger.info("AI Scoring: starting #{asset.ticker} (#{asset.asset_class})")

    result =
      with {:ok, provider, api_key} <- resolve_provider(settings) do
        criteria_type = criteria_type_for(asset.asset_class)
        criteria = criteria_for(criteria_type)

        Logger.info("AI Scoring: calling #{provider} for #{asset.ticker} (#{criteria_type}, #{length(criteria)} criteria)")

        case call_provider(provider, asset.ticker, criteria_type, criteria, api_key) do
          {:ok, raw} ->
            Logger.info("AI Scoring: got response for #{asset.ticker}, validating...")

            case validate_response(raw, criteria) do
              {:ok, validated} ->
                persist_scores(asset.id, validated)
                Logger.info("AI Scoring: #{asset.ticker} scored #{validated.total}/#{map_size(validated.scores)}")
                {:ok, validated}

              {:error, reason} = err ->
                Logger.error("AI Scoring: validation failed for #{asset.ticker}: #{inspect(reason)}")
                err
            end

          {:error, reason} = err ->
            Logger.error("AI Scoring: provider call failed for #{asset.ticker}: #{inspect(reason)}")
            err
        end
      else
        {:error, reason} = err ->
          Logger.error("AI Scoring: provider resolution failed: #{inspect(reason)}")
          err
      end

    result
  end

  @doc """
  Scores multiple assets concurrently. Sends progress messages to `caller_pid`.
  Messages: `{:ai_score_progress, asset_id, result}` and `{:ai_score_done, summary}`.
  """
  def score_batch(assets, settings, caller_pid) do
    Task.Supervisor.start_child(Holder.AITaskSupervisor, fn ->
      results =
        assets
        |> Task.async_stream(
          fn asset ->
            result =
              try do
                score_asset(asset, settings)
              rescue
                e ->
                  Logger.error("AI Scoring: crash for #{asset.ticker}: #{Exception.message(e)}")
                  {:error, Exception.message(e)}
              end

            send(caller_pid, {:ai_score_progress, asset.id, result})
            {asset.id, result}
          end,
          max_concurrency: 1,
          timeout: 90_000,
          on_timeout: :kill_task
        )
        |> Enum.map(fn
          {:ok, {id, result}} -> {id, result}
          {:exit, :timeout} -> {nil, {:error, :timeout}}
        end)

      ok = Enum.count(results, fn {_, r} -> match?({:ok, _}, r) end)
      errors = Enum.count(results, fn {_, r} -> match?({:error, _}, r) end)
      send(caller_pid, {:ai_score_done, %{ok: ok, errors: errors, total: length(assets)}})
    end)
  end

  @doc "Tests the connection for the given provider and encrypted key."
  def test_connection(provider, encrypted_key) do
    api_key = Vault.decrypt(encrypted_key)

    if is_nil(api_key) do
      {:error, :no_api_key}
    else
      Logger.info("AI Scoring: testing connection to #{provider}")

      case provider do
        "gemini" -> Holder.AIScoring.Gemini.test_connection(api_key)
        _ -> {:error, :unknown_provider}
      end
    end
  end

  # ── Private ──────────────────────────────────────────────

  defp resolve_provider(settings) do
    provider = settings.ai_provider

    enc_key =
      case provider do
        "gemini" -> settings.gemini_api_key_enc
        _ -> nil
      end

    api_key = Vault.decrypt(enc_key)

    cond do
      is_nil(provider) or provider == "" -> {:error, :no_provider_configured}
      is_nil(api_key) -> {:error, :no_api_key}
      true -> {:ok, provider, api_key}
    end
  end

  defp call_provider("gemini", ticker, criteria_type, criteria, api_key) do
    Holder.AIScoring.Gemini.score(ticker, criteria_type, criteria, api_key)
  end

  defp call_provider(_, _, _, _, _), do: {:error, :unknown_provider}

  defp validate_response(%{"scores" => scores_map}, criteria) when is_map(scores_map) do
    valid_ids = MapSet.new(Enum.map(criteria, & &1.id))

    validated =
      scores_map
      |> Enum.filter(fn {id, _} -> MapSet.member?(valid_ids, id) end)
      |> Enum.map(fn {id, data} ->
        answer = normalize_answer(data["answer"])
        reason = if is_binary(data["reason"]), do: String.slice(data["reason"], 0, 500), else: nil
        {id, %{answer: answer, reason: reason}}
      end)
      |> Enum.into(%{})

    total = validated |> Map.values() |> Enum.map(& &1.answer) |> Enum.sum()
    {:ok, %{scores: validated, total: total}}
  end

  defp validate_response(other, _) do
    Logger.error("AI Scoring: unexpected response format: #{inspect(other, limit: 300)}")
    {:error, :invalid_response_format}
  end

  defp normalize_answer(1), do: 1
  defp normalize_answer(-1), do: -1
  defp normalize_answer(v) when is_number(v) and v > 0, do: 1
  defp normalize_answer(v) when is_number(v) and v < 0, do: -1
  defp normalize_answer(_), do: -1

  defp persist_scores(asset_id, %{scores: scores}) do
    for {criterion_id, %{answer: answer, reason: reason}} <- scores do
      Portfolio.update_asset_score(asset_id, criterion_id, answer,
        source: "ai",
        ai_reason: reason
      )
    end
  end

  defp criteria_type_for(class) when class in ["acoes", "stocks"], do: "stock"
  defp criteria_type_for(class) when class in ["fiis", "reits"], do: "fii"
  defp criteria_type_for(_), do: "stock"

  defp criteria_for("stock"), do: Portfolio.stock_criteria()
  defp criteria_for("fii"), do: Portfolio.fii_criteria()
  defp criteria_for(_), do: Portfolio.stock_criteria()
end
