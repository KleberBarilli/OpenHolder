defmodule HolderWeb.PageController do
  use HolderWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
