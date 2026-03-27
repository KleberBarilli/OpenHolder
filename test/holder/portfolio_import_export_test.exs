defmodule Holder.PortfolioImportExportTest do
  use Holder.DataCase

  alias Holder.Portfolio

  setup do
    portfolio = Portfolio.get_or_create_default_portfolio()
    Portfolio.ensure_default_classes(portfolio.id)
    %{portfolio: portfolio}
  end

  # Helper to create a portfolio with some assets and scores
  defp seed_assets(portfolio) do
    {:ok, asset1} =
      Portfolio.create_asset(portfolio.id, %{
        asset_class: "acoes",
        ticker: "PETR4",
        name: "Petrobras",
        sector: "Petróleo",
        qty: 100,
        price: 35.50,
        value: 3550.0,
        target_pct: 0.20,
        currency: "BRL"
      })

    Portfolio.update_asset_score(asset1.id, "roe", 1)
    Portfolio.update_asset_score(asset1.id, "dividend_yield", 1)

    {:ok, asset2} =
      Portfolio.create_asset(portfolio.id, %{
        asset_class: "acoes",
        ticker: "VALE3",
        name: "Vale",
        sector: "Mineração",
        qty: 50,
        price: 68.00,
        value: 3400.0,
        target_pct: 0.15,
        currency: "BRL"
      })

    {:ok, asset_rf} =
      Portfolio.create_asset(portfolio.id, %{
        asset_class: "rendaFixa",
        name: "Tesouro SELIC",
        value: 10000.0,
        target_pct: 0.30,
        liquidity: "Boa",
        currency: "BRL"
      })

    {:ok, asset_fii} =
      Portfolio.create_asset(portfolio.id, %{
        asset_class: "fiis",
        ticker: "HGLG11",
        name: "CSHG Logística",
        qty: 10,
        price: 160.0,
        value: 1600.0,
        target_pct: 0.10,
        currency: "BRL"
      })

    Portfolio.update_asset_score(asset_fii.id, "vacancia", 1)

    %{asset1: asset1, asset2: asset2, asset_rf: asset_rf, asset_fii: asset_fii}
  end

  # ── export_json ─────────────────────────────────────────────

  describe "export_json/1" do
    test "returns valid JSON with settings and macro targets", %{portfolio: portfolio} do
      json = Portfolio.export_json(portfolio.id)
      assert {:ok, data} = Jason.decode(json)

      assert is_map(data["settings"])
      assert is_map(data["macroTargets"])
      assert Map.has_key?(data["settings"], "dollarRate")
      assert Map.has_key?(data["settings"], "aporteValue")
    end

    test "excludes API keys from export", %{portfolio: portfolio} do
      Portfolio.update_settings(portfolio.id, %{brapi_token: "secret_token_123"})

      json = Portfolio.export_json(portfolio.id)
      refute String.contains?(json, "secret_token_123")
      refute String.contains?(json, "brapiToken")
    end

    test "includes asset data with correct structure", %{portfolio: portfolio} do
      seed_assets(portfolio)

      json = Portfolio.export_json(portfolio.id)
      {:ok, data} = Jason.decode(json)

      assert is_list(data["acoes"])
      assert length(data["acoes"]) == 2

      petr = Enum.find(data["acoes"], &(&1["ticker"] == "PETR4"))
      assert petr["name"] == "Petrobras"
      assert petr["qty"] == 100
      assert petr["price"] == 35.50
      assert petr["targetPct"] == 0.20
    end

    test "includes scores for acoes and fiis", %{portfolio: portfolio} do
      seed_assets(portfolio)

      json = Portfolio.export_json(portfolio.id)
      {:ok, data} = Jason.decode(json)

      petr = Enum.find(data["acoes"], &(&1["ticker"] == "PETR4"))
      assert is_map(petr["scores"])
      assert petr["scores"]["roe"] == 1
      assert petr["scores"]["dividend_yield"] == 1

      hglg = Enum.find(data["fiis"], &(&1["ticker"] == "HGLG11"))
      assert is_map(hglg["scores"])
      assert hglg["scores"]["vacancia"] == 1
    end

    test "does not include scores key for non-acoes/fiis classes", %{portfolio: portfolio} do
      seed_assets(portfolio)

      json = Portfolio.export_json(portfolio.id)
      {:ok, data} = Jason.decode(json)

      rf_asset = List.first(data["rendaFixa"])
      refute Map.has_key?(rf_asset, "scores")
    end

    test "includes rendaFixa assets with value and liquidity", %{portfolio: portfolio} do
      seed_assets(portfolio)

      json = Portfolio.export_json(portfolio.id)
      {:ok, data} = Jason.decode(json)

      rf = List.first(data["rendaFixa"])
      assert rf["name"] == "Tesouro SELIC"
      assert rf["value"] == 10000.0
      assert rf["liquidity"] == "Boa"
    end

    test "empty portfolio exports empty asset lists", %{portfolio: portfolio} do
      json = Portfolio.export_json(portfolio.id)
      {:ok, data} = Jason.decode(json)

      assert data["acoes"] == []
      assert data["fiis"] == []
      assert data["rendaFixa"] == []
    end
  end

  # ── import_json ─────────────────────────────────────────────

  describe "import_json/2" do
    test "roundtrip: export then import restores data", %{portfolio: portfolio} do
      seed_assets(portfolio)

      json = Portfolio.export_json(portfolio.id)

      # Delete all assets first
      for class_key <- ~w(acoes fiis rendaFixa stocks reits etfs crypto) do
        assets = Portfolio.list_assets(portfolio.id, class_key)
        for a <- assets, do: Portfolio.delete_asset(a.id)
      end

      # Verify assets are gone
      assert Portfolio.list_assets(portfolio.id, "acoes") == []

      # Import
      assert :ok = Portfolio.import_json(portfolio.id, json)

      # Verify assets restored
      acoes = Portfolio.list_assets(portfolio.id, "acoes")
      assert length(acoes) == 2

      petr = Enum.find(acoes, &(&1.ticker == "PETR4"))
      assert petr.name == "Petrobras"
      assert petr.qty == 100
      assert petr.price == 35.50
    end

    test "import restores scores for acoes", %{portfolio: portfolio} do
      seed_assets(portfolio)

      json = Portfolio.export_json(portfolio.id)
      assert :ok = Portfolio.import_json(portfolio.id, json)

      acoes = Portfolio.list_assets(portfolio.id, "acoes")
      petr = Enum.find(acoes, &(&1.ticker == "PETR4"))
      scores = Portfolio.get_scores_map(petr.id)
      assert scores["roe"] == 1
      assert scores["dividend_yield"] == 1
    end

    test "import updates settings", %{portfolio: portfolio} do
      json =
        Jason.encode!(%{
          "settings" => %{
            "dollarRate" => 5.50,
            "iof" => 0.38,
            "spread" => 2.0,
            "aporteValue" => 5000.0,
            "classesToBuy" => 3,
            "minDiffIgnore" => 0.5
          }
        })

      assert :ok = Portfolio.import_json(portfolio.id, json)

      settings = Portfolio.get_settings(portfolio.id)
      assert settings.dollar_rate == 5.50
      assert settings.aporte_value == 5000.0
      assert settings.classes_to_buy == 3
    end

    test "import updates macro targets", %{portfolio: portfolio} do
      json =
        Jason.encode!(%{
          "macroTargets" => %{
            "acoes" => 0.40,
            "fiis" => 0.20,
            "rendaFixa" => 0.30
          }
        })

      assert :ok = Portfolio.import_json(portfolio.id, json)

      targets = Portfolio.get_macro_targets_map(portfolio.id)
      assert targets["acoes"] == 0.40
      assert targets["fiis"] == 0.20
      assert targets["rendaFixa"] == 0.30
    end

    test "returns error for invalid JSON", %{portfolio: portfolio} do
      assert {:error, _} = Portfolio.import_json(portfolio.id, "not json {{{")
    end
  end

  # ── parse_csv ───────────────────────────────────────────────

  describe "parse_csv/2" do
    test "parses valid CSV and groups by class", %{portfolio: portfolio} do
      csv = """
      asset_class,ticker,name,sector,asset_type,qty,price,value,target_pct,score,liquidity
      acoes,PETR4,Petrobras,Petróleo,,100,35.50,3550,0.20,,
      acoes,VALE3,Vale,Mineração,,50,68,3400,0.15,,
      rendaFixa,,Tesouro SELIC,,,0,0,10000,0.30,,Boa
      """

      assert {:ok, preview} = Portfolio.parse_csv(portfolio.id, csv)

      assert is_map(preview.assets_by_class)
      assert length(preview.assets_by_class["acoes"]) == 2
      assert length(preview.assets_by_class["rendaFixa"]) == 1
      assert preview.total == 3
    end

    test "detects new classes not in portfolio", %{portfolio: portfolio} do
      csv = """
      asset_class,ticker,name,sector,asset_type,qty,price,value,target_pct,score,liquidity
      newclass,TICK1,Test,,,,,,,,
      """

      assert {:ok, preview} = Portfolio.parse_csv(portfolio.id, csv)

      assert length(preview.new_classes) == 1
      new = List.first(preview.new_classes)
      assert new.key == "newclass"
      assert new.currency == "BRL"
      refute new.skip
    end

    test "existing classes are not marked as new", %{portfolio: portfolio} do
      csv = """
      asset_class,ticker,name,sector,asset_type,qty,price,value,target_pct,score,liquidity
      acoes,PETR4,Petrobras,,,100,35.50,3550,0.20,,
      """

      assert {:ok, preview} = Portfolio.parse_csv(portfolio.id, csv)
      assert preview.new_classes == []
    end

    test "returns empty preview for empty CSV body", %{portfolio: portfolio} do
      # An empty string is split into a single-element list (header only), so it returns ok with 0 total
      assert {:ok, preview} = Portfolio.parse_csv(portfolio.id, "")
      assert preview.total == 0
    end

    test "returns error for truly empty input (only whitespace)", %{portfolio: portfolio} do
      # A completely whitespace-only string trims to "" which splits to [""] — header only, no rows
      assert {:ok, preview} = Portfolio.parse_csv(portfolio.id, "   ")
      assert preview.total == 0
    end

    test "returns summary with counts per class", %{portfolio: portfolio} do
      csv = """
      asset_class,ticker,name,sector,asset_type,qty,price,value,target_pct,score,liquidity
      acoes,PETR4,Petrobras,,,100,35.50,3550,0.20,,
      acoes,VALE3,Vale,,,50,68,3400,0.15,,
      fiis,HGLG11,CSHG Log,,,10,160,1600,0.10,,
      """

      assert {:ok, preview} = Portfolio.parse_csv(portfolio.id, csv)

      acoes_summary = Enum.find(preview.summary, &(&1.class == "acoes"))
      assert acoes_summary.count == 2
      refute acoes_summary.new

      fiis_summary = Enum.find(preview.summary, &(&1.class == "fiis"))
      assert fiis_summary.count == 1
    end

    test "skips rows with missing asset_class", %{portfolio: portfolio} do
      csv = """
      asset_class,ticker,name,sector,asset_type,qty,price,value,target_pct,score,liquidity
      acoes,PETR4,Petrobras,,,100,35.50,3550,0.20,,
      ,,,,,,,,,,,
      """

      assert {:ok, preview} = Portfolio.parse_csv(portfolio.id, csv)
      assert preview.total == 1
    end
  end

  # ── import_csv_confirmed ────────────────────────────────────

  describe "import_csv_confirmed/3" do
    test "imports assets from CSV", %{portfolio: portfolio} do
      csv = """
      asset_class,ticker,name,sector,asset_type,qty,price,value,target_pct,score,liquidity
      acoes,PETR4,Petrobras,Petróleo,,100,35.50,3550,0.20,,
      acoes,VALE3,Vale,Mineração,,50,68,3400,0.15,,
      """

      assert {:ok, results} = Portfolio.import_csv_confirmed(portfolio.id, csv, %{})

      assert results.imported == 2
      assert results.skipped == 0
      assert results.by_class["acoes"] == 2

      assets = Portfolio.list_assets(portfolio.id, "acoes")
      tickers = Enum.map(assets, & &1.ticker)
      assert "PETR4" in tickers
      assert "VALE3" in tickers
    end

    test "creates new classes from class_configs", %{portfolio: portfolio} do
      csv = """
      asset_class,ticker,name,sector,asset_type,qty,price,value,target_pct,score,liquidity
      newclass,TICK1,Test Asset,,,,,,,,
      """

      class_configs = %{
        "newclass" => %{label: "New Class", color: "#34d399", currency: "USD", skip: false}
      }

      assert {:ok, results} = Portfolio.import_csv_confirmed(portfolio.id, csv, class_configs)
      assert results.imported == 1

      ac = Portfolio.get_asset_class_by_key(portfolio.id, "newclass")
      assert ac.label == "New Class"
      assert ac.currency == "USD"
    end

    test "skips classes marked as skip in class_configs", %{portfolio: portfolio} do
      csv = """
      asset_class,ticker,name,sector,asset_type,qty,price,value,target_pct,score,liquidity
      skipme,TICK1,Test,,,,,,,,
      acoes,PETR4,Petrobras,,,100,35.50,3550,0.20,,
      """

      class_configs = %{
        "skipme" => %{label: "Skip Me", color: "#000", currency: "BRL", skip: true}
      }

      assert {:ok, results} = Portfolio.import_csv_confirmed(portfolio.id, csv, class_configs)
      assert results.imported == 1
      assert results.skipped == 1

      assert is_nil(Portfolio.get_asset_class_by_key(portfolio.id, "skipme"))
    end

    test "parses numeric fields correctly", %{portfolio: portfolio} do
      csv = """
      asset_class,ticker,name,sector,asset_type,qty,price,value,target_pct,score,liquidity
      acoes,TEST1,Test,Tech,,200,42.75,8550,0.25,8,
      """

      assert {:ok, _} = Portfolio.import_csv_confirmed(portfolio.id, csv, %{})

      assets = Portfolio.list_assets(portfolio.id, "acoes")
      test_asset = Enum.find(assets, &(&1.ticker == "TEST1"))
      assert test_asset.qty == 200.0
      assert test_asset.price == 42.75
      assert test_asset.value == 8550.0
      assert test_asset.target_pct == 0.25
      assert test_asset.score == 8
    end

    test "handles blank optional fields as nil", %{portfolio: portfolio} do
      csv = """
      asset_class,ticker,name,sector,asset_type,qty,price,value,target_pct,score,liquidity
      rendaFixa,,Tesouro SELIC,,,0,0,10000,0.30,,Boa
      """

      assert {:ok, _} = Portfolio.import_csv_confirmed(portfolio.id, csv, %{})

      assets = Portfolio.list_assets(portfolio.id, "rendaFixa")
      rf = List.first(assets)
      assert rf.name == "Tesouro SELIC"
      assert rf.ticker == nil
      assert rf.liquidity == "Boa"
    end
  end
end
