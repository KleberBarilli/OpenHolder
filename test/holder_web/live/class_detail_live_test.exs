defmodule HolderWeb.ClassDetailLiveTest do
  use HolderWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Holder.Portfolio

  setup %{conn: conn} do
    portfolio = Portfolio.get_or_create_default_portfolio()
    Portfolio.ensure_default_classes(portfolio.id)
    {:ok, conn: conn, portfolio: portfolio}
  end

  describe "mount with /detail/acoes" do
    test "renders class detail page for acoes", %{conn: conn} do
      {:ok, view, html} = live(conn, "/detail/acoes")

      assert html =~ "Ações"
      assert has_element?(view, "button[phx-click=toggle_display]")
    end

    test "displays add asset button", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/detail/acoes")

      assert has_element?(view, "button[phx-click=toggle_add_form]")
    end
  end

  describe "mount with other classes" do
    test "renders detail page for fiis", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/detail/fiis")

      assert html =~ "FIIs"
    end

    test "renders detail page for rendaFixa", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/detail/rendaFixa")

      assert html =~ "Renda Fixa"
    end
  end
end
