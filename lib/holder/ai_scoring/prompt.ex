defmodule Holder.AIScoring.Prompt do
  @moduledoc """
  Builds the system and user prompts for AI-powered asset scoring
  following the "Diagrama do Cerrado" methodology.
  """

  @system_prompt """
  You are a financial evaluator following the "Diagrama do Cerrado — Company Assessment" methodology.
  Your role is to analyze a given asset (Stock, REIT, or FII) provided by ticker and objectively
  answer a specific questionnaire, detailing each response based on research from multiple reliable sources.

  ## Purpose and Goals

  - Receive a stock/REIT/FII ticker.
  - Identify the asset type and apply the corresponding questionnaire.
  - Conduct thorough research using multiple reliable sources to answer each question objectively.
  - Score the asset: +1 for "YES", -1 for "NO".
  - Return structured results with detailed justification for each answer.

  ## Behavior and Rules

  1. **Identification**: Confirm the ticker and identify the asset type (Brazilian Stock, US Stock, REIT, or FII).

  2. **Research and Detail**:
     - Each answer must be supported by financial data and historical facts from multiple reliable sources.
     - The objective explanation must be concise, focusing only on the data necessary to justify the "YES" or "NO" answer.

  3. **Scoring**: "YES" = +1, "NO" = -1. The final score is the sum of all answers.

  ## Response Format

  You MUST respond with valid JSON only. No markdown, no commentary outside the JSON.
  The JSON must follow this exact structure:

  ```
  {
    "ticker": "PETR4",
    "asset_type": "stock",
    "scores": {
      "<criterion_id>": {
        "answer": 1,
        "reason": "Brief factual justification with data"
      }
    }
  }
  ```

  Where `answer` is strictly `1` (YES) or `-1` (NO). Never use `0`.

  ## Tone

  - Analytical, objective, and direct.
  - Professional and technical financial analysis language.
  - Neutral tone, strictly focused on researched facts and data.
  """

  @stock_questions %{
    "roe" => "Has the company historically maintained a ROE above 15%? (Consider prior years)",
    "cagr" =>
      "Has the company achieved revenue (or profit) growth above 5% over the last 5 years?",
    "dy" =>
      "Does the company have a track record of paying dividends or conducting share buybacks?",
    "tech" =>
      "Does the company invest significantly in R&D and innovation? Rule: Obsolete sector or pure Commodity = ALWAYS NO",
    "market" => "Has the company been in the market for 30+ years or is it a Blue Chip?",
    "perene" => "Has the sector the company operates in existed for 100+ years?",
    "gov" => "Does the company have good governance? Rule: History of corruption = ALWAYS NO",
    "indep" => "Is the company free from government control or single-customer concentration?",
    "divida" =>
      "Is Net Debt/EBITDA below 2 (utilities ≤ 3) over the last 5 years? Rule: For banks, Basel Index > 11",
    "ncicl" => "Is the company NOT in a cyclical sector? OR Is it a perennial company?",
    "lucro" => "Has the company NOT posted a loss in the last 5 years?"
  }

  @fii_questions %{
    "regiao" =>
      "Are the fund's properties located in prime regions (T1 or urban core), above 30%? For paper/mortgage funds = YES",
    "pvp" =>
      "Is the fund trading below P/BV 1.0 or P/FFO 15? (Above 1.2 or P/FFO 18+ = disqualified in any case)",
    "dep" =>
      "Is the fund NOT dependent on a single tenant or property? OR Does the fund have less than 10% exposure to a single issuer?",
    "dy" => "Is the dividend yield at or above the average for funds of the same type?",
    "risco" => "Is the fund rated High Grade BBB+ or above?",
    "local" =>
      "Is the fund present in more than 3 states? For paper funds = YES, US REITs = 5+ states",
    "gov" => "Does the fund have an excellent management company with a good track record?",
    "taxa" => "Is the management fee equal to or below 1% per year? REITs < 1.5%",
    "vacancia" => "Is the fund a brick-and-mortar type with vacancy below 10%?",
    "divida" =>
      "Does the fund have healthy leverage? (FII: sector average; paper: below 10 in high Selic | REIT: Net Debt/EBITDA acceptable for its type)",
    "cagr" => "Is FFO growth (CAGR) above 3%?"
  }

  @doc """
  Builds the system prompt (static, same for all requests).
  """
  def system_prompt, do: @system_prompt

  @doc """
  Builds the user prompt for a specific ticker and criteria type.

  ## Parameters
    - `ticker` — e.g. "PETR4", "AAPL", "KNRI11"
    - `criteria_type` — "stock" or "fii"
    - `criteria` — list of `%{id: "roe", label: "ROE", q: "..."}` from Portfolio
  """
  def user_prompt(ticker, criteria_type, criteria) do
    questions = questions_for(criteria_type)

    numbered =
      criteria
      |> Enum.with_index(1)
      |> Enum.map(fn {cr, i} ->
        # Use detailed question from hardcoded map if available, otherwise use the criterion's own question/label
        q = Map.get(questions, cr.id, cr[:q] || cr[:label] || cr.id)
        ~s(#{i}. [criterion_id: "#{cr.id}"] #{q})
      end)
      |> Enum.join("\n")

    """
    Evaluate the following asset: **#{ticker}**
    Asset type: #{type_label(criteria_type)}

    Answer each question below. For each criterion, return the `criterion_id` exactly as shown,
    with `answer` as `1` (YES) or `-1` (NO), and a brief `reason` with supporting data.

    #{numbered}

    Respond ONLY with valid JSON matching the required schema. No extra text.
    """
  end

  defp questions_for("stock"), do: @stock_questions
  defp questions_for("fii"), do: @fii_questions
  defp questions_for(_), do: @stock_questions

  defp type_label("stock"), do: "Stock (Equity)"
  defp type_label("fii"), do: "FII / REIT (Real Estate Fund)"
  defp type_label(_), do: "Stock (Equity)"
end
