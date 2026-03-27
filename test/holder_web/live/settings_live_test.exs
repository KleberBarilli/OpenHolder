defmodule HolderWeb.SettingsLiveTest do
  use HolderWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Holder.Portfolio

  setup %{conn: conn} do
    portfolio = Portfolio.get_or_create_default_portfolio()
    Portfolio.ensure_default_classes(portfolio.id)
    {:ok, conn: conn, portfolio: portfolio}
  end

  describe "mount" do
    test "renders settings page", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/settings")

      assert html =~ "Configurações"
    end

    test "displays BrAPI token section", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/settings")

      assert html =~ "BrAPI"
    end

    test "displays macro targets section", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/settings")

      assert has_element?(view, "button[phx-click=export]")
    end
  end
end
