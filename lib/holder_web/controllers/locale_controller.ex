defmodule HolderWeb.LocaleController do
  use HolderWeb, :controller

  @locales ~w(pt_BR en)

  def update(conn, %{"locale" => locale}) do
    locale = if locale in @locales, do: locale, else: "pt_BR"

    conn
    |> put_session("locale", locale)
    |> redirect(to: conn.req_headers |> Enum.find(fn {k, _} -> k == "referer" end) |> case do
      {_, referer} -> URI.parse(referer).path || "/"
      nil -> "/"
    end)
  end
end
