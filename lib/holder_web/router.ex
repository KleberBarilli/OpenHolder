defmodule HolderWeb.Router do
  use HolderWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {HolderWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug HolderWeb.Plugs.Locale
  end

  scope "/", HolderWeb do
    pipe_through :browser

    put "/locale/:locale", LocaleController, :update

    live_session :default, layout: {HolderWeb.Layouts, :app}, on_mount: [{HolderWeb.Hooks, :default}] do
      live "/", DashboardLive
      live "/detail/:class", ClassDetailLive
      live "/rebalance", RebalanceLive
      live "/scoring", ScoringLive
      live "/settings", SettingsLive
    end
  end
end
