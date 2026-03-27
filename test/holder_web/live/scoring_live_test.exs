defmodule HolderWeb.ScoringLiveTest do
  use HolderWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Holder.Portfolio

  setup %{conn: conn} do
    portfolio = Portfolio.get_or_create_default_portfolio()
    Portfolio.ensure_default_classes(portfolio.id)
    {:ok, conn: conn, portfolio: portfolio}
  end

  describe "mount" do
    test "renders scoring page", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/scoring")

      assert html =~ "Pontuação"
    end

    test "displays acoes and fiis tabs", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/scoring")

      assert has_element?(view, "button[phx-click=switch_tab][phx-value-tab=acoes]")
      assert has_element?(view, "button[phx-click=switch_tab][phx-value-tab=fiis]")
    end

    test "defaults to acoes tab active", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/scoring")

      assert has_element?(view, "button.tab-active[phx-value-tab=acoes]")
      assert has_element?(view, "button.tab-inactive[phx-value-tab=fiis]")
    end
  end
end
