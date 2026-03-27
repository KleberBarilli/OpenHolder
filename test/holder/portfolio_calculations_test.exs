defmodule Holder.PortfolioCalculationsTest do
  use Holder.DataCase

  alias Holder.Portfolio

  setup do
    portfolio = Portfolio.get_or_create_default_portfolio()
    Portfolio.ensure_default_classes(portfolio.id)
    %{portfolio: portfolio}
  end

  # ── compute_score/1 ──────────────────────────────────────

  describe "compute_score/1" do
    test "returns 'SN' for asset with no scores", %{portfolio: portfolio} do
      {:ok, asset} = Portfolio.create_asset(portfolio.id, %{asset_class: "acoes", ticker: "PETR4"})
      asset = Portfolio.get_asset!(asset.id)
      assert Portfolio.compute_score(asset) == "SN"
    end

    test "sums all score values", %{portfolio: portfolio} do
      {:ok, asset} = Portfolio.create_asset(portfolio.id, %{asset_class: "acoes", ticker: "PETR4"})
      Portfolio.update_asset_score(asset.id, "roe", 1)
      Portfolio.update_asset_score(asset.id, "div_yield", 0)
      Portfolio.update_asset_score(asset.id, "p_l", 1)

      asset = Portfolio.get_asset!(asset.id)
      assert Portfolio.compute_score(asset) == 2
    end

    test "returns 0 when all scores are zero", %{portfolio: portfolio} do
      {:ok, asset} = Portfolio.create_asset(portfolio.id, %{asset_class: "acoes", ticker: "PETR4"})
      Portfolio.update_asset_score(asset.id, "roe", 0)
      Portfolio.update_asset_score(asset.id, "div_yield", 0)

      asset = Portfolio.get_asset!(asset.id)
      assert Portfolio.compute_score(asset) == 0
    end
  end

  # ── get_macro_targets_map/1 ──────────────────────────────

  describe "get_macro_targets_map/1" do
    test "returns default targets as a map", %{portfolio: portfolio} do
      targets = Portfolio.get_macro_targets_map(portfolio.id)
      assert is_map(targets)
      assert targets["acoes"] == 0.25
      assert targets["fiis"] == 0.25
      assert targets["rendaFixa"] == 0.20
      assert targets["stocks"] == 0.15
    end
  end

  # ── update_macro_target/3 ────────────────────────────────

  describe "update_macro_target/3" do
    test "updates an existing target", %{portfolio: portfolio} do
      assert {:ok, _} = Portfolio.update_macro_target(portfolio.id, "acoes", 0.30)
      targets = Portfolio.get_macro_targets_map(portfolio.id)
      assert targets["acoes"] == 0.30
    end

    test "creates a new target for unknown class", %{portfolio: portfolio} do
      assert {:ok, _} = Portfolio.update_macro_target(portfolio.id, "newClass", 0.10)
      targets = Portfolio.get_macro_targets_map(portfolio.id)
      assert targets["newClass"] == 0.10
    end
  end

  # ── compute_macro_summary/1 ──────────────────────────────

  describe "compute_macro_summary/1" do
    test "returns zero totals for empty portfolio", %{portfolio: portfolio} do
      summary = Portfolio.compute_macro_summary(portfolio.id)
      assert summary.grand_total == 0.0
      assert is_list(summary.classes)

      Enum.each(summary.classes, fn c ->
        assert c.current_pct == 0.0
        assert c.status == "Hold" or c.status == "Buy"
      end)
    end

    test "calculates BRL class values from qty * price", %{portfolio: portfolio} do
      Portfolio.create_asset(portfolio.id, %{asset_class: "acoes", ticker: "PETR4", qty: 100.0, price: 30.0})
      Portfolio.create_asset(portfolio.id, %{asset_class: "acoes", ticker: "VALE3", qty: 50.0, price: 60.0})

      summary = Portfolio.compute_macro_summary(portfolio.id)
      acoes = Enum.find(summary.classes, &(&1.key == "acoes"))

      # 100*30 + 50*60 = 6000
      assert acoes.value == 6000.0
    end

    test "calculates USD class values with exchange rate", %{portfolio: portfolio} do
      Portfolio.update_settings(portfolio.id, %{dollar_rate: 5.0})

      Portfolio.create_asset(portfolio.id, %{asset_class: "stocks", ticker: "AAPL", qty: 10.0, price: 100.0})

      summary = Portfolio.compute_macro_summary(portfolio.id)
      stocks = Enum.find(summary.classes, &(&1.key == "stocks"))

      # 10 * 100 * 5.0 = 5000
      assert stocks.value == 5000.0
    end

    test "calculates rendaFixa from value field", %{portfolio: portfolio} do
      Portfolio.create_asset(portfolio.id, %{asset_class: "rendaFixa", name: "CDB", value: 10000.0})

      summary = Portfolio.compute_macro_summary(portfolio.id)
      rf = Enum.find(summary.classes, &(&1.key == "rendaFixa"))

      assert rf.value == 10000.0
    end

    test "sets Buy status when diff > 0.005", %{portfolio: portfolio} do
      # Set acoes target to 100% so it always needs more
      Portfolio.update_macro_target(portfolio.id, "acoes", 1.0)

      Portfolio.create_asset(portfolio.id, %{asset_class: "acoes", ticker: "PETR4", qty: 10.0, price: 10.0})

      summary = Portfolio.compute_macro_summary(portfolio.id)
      acoes = Enum.find(summary.classes, &(&1.key == "acoes"))

      # current_pct should be 100% since it's the only asset, diff = 1.0 - 1.0 = 0.0
      # So status should be Hold since diff <= 0.005
      assert acoes.status == "Hold"

      # Add another class asset to shift allocation
      Portfolio.create_asset(portfolio.id, %{asset_class: "fiis", ticker: "HGLG11", qty: 10.0, price: 10.0})

      summary = Portfolio.compute_macro_summary(portfolio.id)
      acoes = Enum.find(summary.classes, &(&1.key == "acoes"))

      # acoes: 100/200 = 50%, target = 100%, diff = 0.5 > 0.005 => Buy
      assert acoes.status == "Buy"
    end

    test "sets Hold status when diff <= 0.005", %{portfolio: portfolio} do
      Portfolio.update_macro_target(portfolio.id, "acoes", 0.0)
      Portfolio.create_asset(portfolio.id, %{asset_class: "acoes", ticker: "PETR4", qty: 10.0, price: 10.0})

      summary = Portfolio.compute_macro_summary(portfolio.id)
      acoes = Enum.find(summary.classes, &(&1.key == "acoes"))

      assert acoes.status == "Hold"
    end

    test "includes all enabled classes in summary", %{portfolio: portfolio} do
      summary = Portfolio.compute_macro_summary(portfolio.id)
      keys = Enum.map(summary.classes, & &1.key)

      assert "acoes" in keys
      assert "fiis" in keys
      assert "rendaFixa" in keys
      assert "stocks" in keys
    end
  end

  # ── Format helpers ───────────────────────────────────────

  describe "format_brl/1" do
    test "formats a number as BRL currency" do
      assert Portfolio.format_brl(1234.56) == "R$ 1.234,56"
    end

    test "formats large numbers with thousands separators" do
      assert Portfolio.format_brl(1_000_000.0) == "R$ 1.000.000,00"
    end

    test "formats zero" do
      assert Portfolio.format_brl(0.0) == "R$ 0,00"
    end

    test "returns default for nil" do
      assert Portfolio.format_brl(nil) == "R$ 0,00"
    end

    test "returns default for non-numeric" do
      assert Portfolio.format_brl("abc") == "R$ 0,00"
    end

    test "formats small values" do
      assert Portfolio.format_brl(0.99) == "R$ 0,99"
    end
  end

  describe "format_usd/1" do
    test "formats a number as USD currency" do
      assert Portfolio.format_usd(1234.56) == "$ 1,234.56"
    end

    test "formats large numbers with thousands separators" do
      assert Portfolio.format_usd(1_000_000.0) == "$ 1,000,000.00"
    end

    test "formats zero" do
      assert Portfolio.format_usd(0.0) == "$ 0.00"
    end

    test "returns default for nil" do
      assert Portfolio.format_usd(nil) == "$ 0.00"
    end

    test "returns default for non-numeric" do
      assert Portfolio.format_usd("abc") == "$ 0.00"
    end
  end

  describe "format_pct/1" do
    test "formats decimal as percentage" do
      assert Portfolio.format_pct(0.255) == "25,5%"
    end

    test "formats 100%" do
      assert Portfolio.format_pct(1.0) == "100,0%"
    end

    test "formats zero" do
      assert Portfolio.format_pct(0.0) == "0,0%"
    end

    test "returns default for nil" do
      assert Portfolio.format_pct(nil) == "0,0%"
    end

    test "returns default for non-numeric" do
      assert Portfolio.format_pct("abc") == "0,0%"
    end
  end

  # ── safe_color/1 ─────────────────────────────────────────

  describe "safe_color/1" do
    test "returns valid hex color unchanged" do
      assert Portfolio.safe_color("#34d399") == "#34d399"
    end

    test "accepts uppercase hex" do
      assert Portfolio.safe_color("#FF0000") == "#FF0000"
    end

    test "returns default for invalid color string" do
      assert Portfolio.safe_color("red") == "#64748b"
    end

    test "returns default for short hex" do
      assert Portfolio.safe_color("#fff") == "#64748b"
    end

    test "returns default for nil" do
      assert Portfolio.safe_color(nil) == "#64748b"
    end

    test "returns default for non-string" do
      assert Portfolio.safe_color(123) == "#64748b"
    end
  end
end
