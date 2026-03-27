defmodule HolderWeb.RebalanceLiveTest do
  use HolderWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Holder.Portfolio

  setup %{conn: conn} do
    portfolio = Portfolio.get_or_create_default_portfolio()
    Portfolio.ensure_default_classes(portfolio.id)
    {:ok, conn: conn, portfolio: portfolio}
  end

  describe "mount" do
    test "renders rebalance page", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/rebalance")

      assert html =~ "Rebalanceamento"
    end

    test "displays toggle display button", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/rebalance")

      assert has_element?(view, "button[phx-click=toggle_display]")
    end
  end
end
