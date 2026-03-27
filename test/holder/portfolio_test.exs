defmodule Holder.PortfolioTest do
  use Holder.DataCase

  alias Holder.Portfolio

  setup do
    portfolio = Portfolio.get_or_create_default_portfolio()
    Portfolio.ensure_default_classes(portfolio.id)
    %{portfolio: portfolio}
  end

  # ── Asset Classes CRUD ──────────────────────────────────

  describe "list_asset_classes/1" do
    test "returns only enabled classes ordered by sort_order", %{portfolio: portfolio} do
      classes = Portfolio.list_asset_classes(portfolio.id)
      assert length(classes) == 8
      assert Enum.map(classes, & &1.key) == ~w(acoes fiis rendaFixa stocks reits etfs crypto fixedIncome)
    end

    test "excludes disabled classes", %{portfolio: portfolio} do
      acoes = Portfolio.get_asset_class_by_key(portfolio.id, "acoes")
      Portfolio.update_asset_class(acoes.id, %{enabled: false})

      classes = Portfolio.list_asset_classes(portfolio.id)
      refute Enum.any?(classes, &(&1.key == "acoes"))
      assert length(classes) == 7
    end
  end

  describe "list_all_asset_classes/1" do
    test "returns all classes including disabled", %{portfolio: portfolio} do
      acoes = Portfolio.get_asset_class_by_key(portfolio.id, "acoes")
      Portfolio.update_asset_class(acoes.id, %{enabled: false})

      classes = Portfolio.list_all_asset_classes(portfolio.id)
      assert length(classes) == 8
      assert Enum.any?(classes, &(&1.key == "acoes"))
    end
  end

  describe "create_asset_class/2" do
    test "creates a new asset class with auto sort_order", %{portfolio: portfolio} do
      attrs = %{key: "newClass", label: "New Class", color: "#abcdef", currency: "BRL"}
      assert {:ok, ac} = Portfolio.create_asset_class(portfolio.id, attrs)
      assert ac.key == "newClass"
      assert ac.label == "New Class"
      assert ac.color == "#abcdef"
      assert ac.currency == "BRL"
      assert ac.sort_order > 0
    end

    test "fails with duplicate key", %{portfolio: portfolio} do
      assert {:error, changeset} =
               Portfolio.create_asset_class(portfolio.id, %{key: "acoes", label: "Dup", color: "#111111", currency: "BRL"})

      assert errors_on(changeset).portfolio_id != []
    end

    test "fails with invalid color format", %{portfolio: portfolio} do
      assert {:error, changeset} =
               Portfolio.create_asset_class(portfolio.id, %{key: "badColor", label: "Bad", color: "red", currency: "BRL"})

      assert errors_on(changeset).color != []
    end

    test "fails with invalid currency", %{portfolio: portfolio} do
      assert {:error, changeset} =
               Portfolio.create_asset_class(portfolio.id, %{key: "badCur", label: "Bad", color: "#111111", currency: "JPY"})

      assert errors_on(changeset).currency != []
    end
  end

  describe "update_asset_class/2" do
    test "updates label and color", %{portfolio: portfolio} do
      acoes = Portfolio.get_asset_class_by_key(portfolio.id, "acoes")
      assert {:ok, updated} = Portfolio.update_asset_class(acoes.id, %{label: "Ações Brasil", color: "#00ff00"})
      assert updated.label == "Ações Brasil"
      assert updated.color == "#00ff00"
    end
  end

  describe "delete_asset_class/1" do
    test "deletes an asset class", %{portfolio: portfolio} do
      acoes = Portfolio.get_asset_class_by_key(portfolio.id, "acoes")
      assert {:ok, _} = Portfolio.delete_asset_class(acoes.id)
      assert is_nil(Portfolio.get_asset_class_by_key(portfolio.id, "acoes"))
    end
  end

  describe "get_asset_class_by_key/2" do
    test "returns the class by key", %{portfolio: portfolio} do
      ac = Portfolio.get_asset_class_by_key(portfolio.id, "fiis")
      assert ac.key == "fiis"
      assert ac.label == "FIIs"
    end

    test "returns nil for nonexistent key", %{portfolio: portfolio} do
      assert is_nil(Portfolio.get_asset_class_by_key(portfolio.id, "nonexistent"))
    end
  end

  describe "ensure_default_classes/1" do
    test "is idempotent - calling twice doesn't duplicate", %{portfolio: portfolio} do
      Portfolio.ensure_default_classes(portfolio.id)
      classes = Portfolio.list_all_asset_classes(portfolio.id)
      assert length(classes) == 8
    end
  end

  # ── Assets CRUD ─────────────────────────────────────────

  describe "list_assets/2" do
    test "returns assets for a given class", %{portfolio: portfolio} do
      {:ok, _} = Portfolio.create_asset(portfolio.id, %{asset_class: "acoes", ticker: "PETR4", qty: 100.0, price: 30.0})
      {:ok, _} = Portfolio.create_asset(portfolio.id, %{asset_class: "acoes", ticker: "VALE3", qty: 50.0, price: 60.0})
      {:ok, _} = Portfolio.create_asset(portfolio.id, %{asset_class: "fiis", ticker: "HGLG11", qty: 10.0, price: 150.0})

      acoes_assets = Portfolio.list_assets(portfolio.id, "acoes")
      assert length(acoes_assets) == 2

      fiis_assets = Portfolio.list_assets(portfolio.id, "fiis")
      assert length(fiis_assets) == 1
    end

    test "returns empty list for class with no assets", %{portfolio: portfolio} do
      assert Portfolio.list_assets(portfolio.id, "acoes") == []
    end

    test "preloads asset_scores", %{portfolio: portfolio} do
      {:ok, asset} = Portfolio.create_asset(portfolio.id, %{asset_class: "acoes", ticker: "PETR4"})
      Portfolio.update_asset_score(asset.id, "roe", 1)

      [loaded] = Portfolio.list_assets(portfolio.id, "acoes")
      assert length(loaded.asset_scores) == 1
    end
  end

  describe "create_asset/2" do
    test "creates asset with all fields", %{portfolio: portfolio} do
      attrs = %{
        asset_class: "acoes",
        ticker: "ITUB4",
        name: "Itaú",
        sector: "Bancos",
        qty: 200.0,
        price: 25.0,
        target_pct: 0.10
      }

      assert {:ok, asset} = Portfolio.create_asset(portfolio.id, attrs)
      assert asset.ticker == "ITUB4"
      assert asset.name == "Itaú"
      assert asset.qty == 200.0
      assert asset.price == 25.0
      assert asset.target_pct == 0.10
    end

    test "requires asset_class", %{portfolio: portfolio} do
      assert {:error, changeset} = Portfolio.create_asset(portfolio.id, %{ticker: "PETR4"})
      assert errors_on(changeset).asset_class != []
    end
  end

  describe "get_asset!/1" do
    test "returns asset with preloaded scores", %{portfolio: portfolio} do
      {:ok, asset} = Portfolio.create_asset(portfolio.id, %{asset_class: "acoes", ticker: "PETR4"})
      Portfolio.update_asset_score(asset.id, "roe", 1)

      loaded = Portfolio.get_asset!(asset.id)
      assert loaded.id == asset.id
      assert length(loaded.asset_scores) == 1
    end

    test "raises for nonexistent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Portfolio.get_asset!(0)
      end
    end
  end

  describe "update_asset/2" do
    test "updates asset fields", %{portfolio: portfolio} do
      {:ok, asset} = Portfolio.create_asset(portfolio.id, %{asset_class: "acoes", ticker: "PETR4", qty: 100.0})
      assert {:ok, updated} = Portfolio.update_asset(asset.id, %{qty: 200.0, price: 35.0})
      assert updated.qty == 200.0
      assert updated.price == 35.0
    end
  end

  describe "delete_asset/1" do
    test "deletes the asset", %{portfolio: portfolio} do
      {:ok, asset} = Portfolio.create_asset(portfolio.id, %{asset_class: "acoes", ticker: "PETR4"})
      assert {:ok, _} = Portfolio.delete_asset(asset.id)

      assert_raise Ecto.NoResultsError, fn ->
        Portfolio.get_asset!(asset.id)
      end
    end
  end
end
