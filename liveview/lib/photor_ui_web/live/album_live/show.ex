defmodule PhotorUiWeb.AlbumsLive.Show do
  use PhotorUiWeb, :live_view

  def mount(%{"date" => date_str}, _session, socket) do
    case Date.from_iso8601(date_str) do
      {:ok, date} ->
        photos = PhotorUi.Photos.of_day(date)
        {:ok, assign(socket, date: date_str, photos: photos)}

      {:error, _} ->
        {:ok, socket |> put_flash(:error, "Invalid date") |> assign(date: "", photos: [])}
    end
  end

  def photo_url_preview(date, photo_filename) do
    preview_filename = String.replace_suffix(photo_filename, ".jpg", "_thumbnail_800px.jpg")
    Path.join(["/photos", date, preview_filename])
  end

  # def handle_event("inc_temperature", _params, socket) do
  #   {:noreply, update(socket, :temperature, &(&1 + 1))}
  # end
end
