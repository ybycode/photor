defmodule PhotorWeb.AlbumsLive.Index do
  use PhotorWeb, :live_view

  def mount(_params, _session, socket) do
    albums = Photor.Photos.unique_create_day() |> Enum.map(&Date.to_string/1)
    {:ok, assign(socket, albums: albums)}
  end
end
