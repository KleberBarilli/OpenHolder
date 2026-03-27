defmodule HolderWeb.DashboardLiveTest do
  use HolderWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Holder.Portfolio

  setup %{conn: conn} do
    portfolio = Portfolio.get_or_create_default_portfolio()
    Portfolio.ensure_default_classes(portfolio.id)
    {:ok, conn: conn, portfolio: portfolio}
  end

  describe "mount" do
    test "renders dashboard page", %{conn: conn} do
      {:ok, view, html} = live(conn, "/")

      assert html =~ "Atualizar"
      assert has_element?(view, "button[phx-click=refresh_quotes]")
      assert has_element?(view, "button[phx-click=toggle_display]")
    end

    test "displays toggle display button", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      assert has_element?(view, "button[phx-click=toggle_display]")
    end

    test "displays refresh quotes button", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      assert has_element?(view, "button[phx-click=refresh_quotes]")
    end
  end
end
