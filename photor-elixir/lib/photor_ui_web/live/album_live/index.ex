defmodule PhotorUiWeb.AlbumsLive.Index do
  use PhotorUiWeb, :live_view

  def mount(_params, _session, socket) do
    albums = PhotorUi.Photos.unique_create_day() |> Enum.map(&Date.to_string/1)
    {:ok, assign(socket, albums: albums)}
  end
end
