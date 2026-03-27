defmodule Holder.AIScoring.PromptTest do
  use ExUnit.Case, async: true

  alias Holder.AIScoring.Prompt

  describe "system_prompt/0" do
    test "returns a non-empty string" do
      prompt = Prompt.system_prompt()

      assert is_binary(prompt)
      assert String.length(prompt) > 0
    end

    test "contains scoring instructions" do
      prompt = Prompt.system_prompt()

      assert prompt =~ "YES"
      assert prompt =~ "NO"
      assert prompt =~ "JSON"
    end

    test "mentions the Diagrama do Cerrado methodology" do
      prompt = Prompt.system_prompt()

      assert prompt =~ "Diagrama do Cerrado"
    end
  end

  describe "user_prompt/3 for stock type" do
    setup do
      criteria = Holder.Portfolio.stock_criteria()
      %{criteria: criteria}
    end

    test "includes the ticker in the prompt", %{criteria: criteria} do
      prompt = Prompt.user_prompt("PETR4", "stock", criteria)

      assert prompt =~ "PETR4"
    end

    test "includes all stock criteria IDs", %{criteria: criteria} do
      prompt = Prompt.user_prompt("VALE3", "stock", criteria)

      for cr <- criteria do
        assert prompt =~ ~s(criterion_id: "#{cr.id}")
      end
    end

    test "includes asset type label for stock", %{criteria: criteria} do
      prompt = Prompt.user_prompt("ITUB4", "stock", criteria)

      assert prompt =~ "Stock"
    end

    test "includes numbered questions", %{criteria: criteria} do
      prompt = Prompt.user_prompt("BBDC4", "stock", criteria)

      assert prompt =~ "1."
      assert prompt =~ "#{length(criteria)}."
    end

    test "requests JSON response", %{criteria: criteria} do
      prompt = Prompt.user_prompt("WEGE3", "stock", criteria)

      assert prompt =~ "JSON"
    end
  end

  describe "user_prompt/3 for fii type" do
    setup do
      criteria = Holder.Portfolio.fii_criteria()
      %{criteria: criteria}
    end

    test "includes the ticker in the prompt", %{criteria: criteria} do
      prompt = Prompt.user_prompt("KNRI11", "fii", criteria)

      assert prompt =~ "KNRI11"
    end

    test "includes all fii criteria IDs", %{criteria: criteria} do
      prompt = Prompt.user_prompt("HGLG11", "fii", criteria)

      for cr <- criteria do
        assert prompt =~ ~s(criterion_id: "#{cr.id}")
      end
    end

    test "includes asset type label for fii", %{criteria: criteria} do
      prompt = Prompt.user_prompt("XPML11", "fii", criteria)

      assert prompt =~ "FII"
    end

    test "uses fii-specific questions not stock questions", %{criteria: criteria} do
      prompt = Prompt.user_prompt("MXRF11", "fii", criteria)

      # FII has "regiao" criterion, stock does not
      assert prompt =~ "regiao"
    end
  end

  describe "user_prompt/3 format consistency" do
    test "stock and fii prompts have different content" do
      stock_criteria = Holder.Portfolio.stock_criteria()
      fii_criteria = Holder.Portfolio.fii_criteria()

      stock_prompt = Prompt.user_prompt("TEST", "stock", stock_criteria)
      fii_prompt = Prompt.user_prompt("TEST", "fii", fii_criteria)

      assert stock_prompt != fii_prompt
      # Stock has ROE, FII does not
      assert stock_prompt =~ "roe"
      refute fii_prompt =~ "roe"
    end
  end
end
