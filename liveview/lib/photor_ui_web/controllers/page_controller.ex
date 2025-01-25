defmodule PhotorUiWeb.PageController do
  use PhotorUiWeb, :controller

  def home(conn, _params) do
    redirect(conn, to: ~p"/albums/")
  end
end
