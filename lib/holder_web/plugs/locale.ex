defmodule HolderWeb.Plugs.Locale do
  @moduledoc "Sets Gettext locale from session or Accept-Language header"
  import Plug.Conn

  @locales ~w(pt_BR en)

  def init(opts), do: opts

  def call(conn, _opts) do
    locale = get_session(conn, "locale") || "pt_BR"
    locale = if locale in @locales, do: locale, else: "pt_BR"
    Gettext.put_locale(HolderWeb.Gettext, locale)
    assign(conn, :locale, locale)
  end
end
