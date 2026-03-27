defmodule Holder.AIScoring.Gemini do
  @moduledoc "Google Gemini provider for AI scoring."

  @behaviour Holder.AIScoring.Provider

  require Logger

  @model "gemini-2.5-flash"

  def model, do: @model

  @impl true
  def name, do: "Google Gemini"

  defp url(api_key) do
    "https://generativelanguage.googleapis.com/v1beta/models/#{@model}:generateContent?key=#{api_key}"
  end

  @impl true
  def score(ticker, criteria_type, criteria, api_key) do
    alias Holder.AIScoring.Prompt

    body = %{
      system_instruction: %{
        parts: [%{text: Prompt.system_prompt()}]
      },
      contents: [
        %{role: "user", parts: [%{text: Prompt.user_prompt(ticker, criteria_type, criteria)}]}
      ],
      generationConfig: %{
        responseMimeType: "application/json",
        temperature: 0.2
      }
    }

    headers = [{"content-type", "application/json"}]

    case Req.post(url(api_key), json: body, headers: headers, receive_timeout: 60_000) do
      {:ok, %{status: 200, body: %{"candidates" => [%{"content" => %{"parts" => [%{"text" => text} | _]}} | _]}}} ->
        parse_response(text)

      {:ok, %{status: 200, body: resp_body}} ->
        Logger.error("Gemini: 200 but unexpected body shape: #{inspect(resp_body, limit: 500)}")
        {:error, :invalid_response_format}

      {:ok, %{status: status, body: resp_body}} when status in [429, 400, 403] ->
        msg = if is_map(resp_body), do: get_in(resp_body, ["error", "message"]), else: nil
        Logger.error("Gemini: HTTP #{status} — #{msg || inspect(resp_body, limit: 300)}")

        cond do
          status == 429 -> {:error, :rate_limited}
          status == 403 -> {:error, :invalid_api_key}
          status == 400 && msg && String.contains?(msg, "API_KEY") -> {:error, :invalid_api_key}
          msg -> {:error, msg}
          true -> {:error, "HTTP #{status}"}
        end

      {:ok, %{status: status, body: resp_body}} ->
        msg = if is_map(resp_body), do: get_in(resp_body, ["error", "message"]) || "HTTP #{status}", else: "HTTP #{status}"
        Logger.error("Gemini: HTTP #{status} — #{msg}")
        {:error, msg}

      {:error, reason} ->
        Logger.error("Gemini: request failed — #{inspect(reason)}")
        {:error, "request_failed: #{inspect(reason)}"}
    end
  end

  @impl true
  def test_connection(api_key) do
    body = %{
      contents: [%{role: "user", parts: [%{text: "Reply with exactly: ok"}]}],
      generationConfig: %{maxOutputTokens: 5}
    }

    headers = [{"content-type", "application/json"}]

    case Req.post(url(api_key), json: body, headers: headers, receive_timeout: 15_000) do
      {:ok, %{status: 200}} -> :ok
      {:ok, %{status: s}} when s in [400, 403] -> {:error, :invalid_api_key}
      {:ok, %{status: status}} -> {:error, "HTTP #{status}"}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  defp parse_response(content) when is_binary(content) do
    case Jason.decode(content) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, _} -> {:error, :invalid_json}
    end
  end
end
