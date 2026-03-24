defmodule HolderWeb.Hooks do
  @moduledoc "LiveView on_mount hooks"
  import Phoenix.LiveView
  import Phoenix.Component

  alias Holder.Portfolio

  def on_mount(:default, _params, session, socket) do
    locale = session["locale"] || "pt_BR"
    Gettext.put_locale(HolderWeb.Gettext, locale)

    portfolio = Portfolio.get_or_create_default_portfolio()
    asset_classes = Portfolio.list_asset_classes(portfolio.id)

    {:cont,
     socket
     |> assign(:locale, locale)
     |> assign(:portfolio_id, portfolio.id)
     |> assign(:asset_classes, asset_classes)}
  end
end
