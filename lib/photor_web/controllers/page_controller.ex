defmodule PhotorWeb.PageController do
  use PhotorWeb, :controller

  def home(conn, _params) do
    redirect(conn, to: ~p"/albums/")
  end
end
