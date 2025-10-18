defmodule PhotorWeb.AlbumsLive.Show do
  use PhotorWeb, :live_view

  alias Photor.Photos
  alias Photor.Photos.Thumbnails

  def mount(%{"date" => date_str}, _session, socket) do
    case Date.from_iso8601(date_str) do
      {:ok, date} ->
        photos =
          Photor.Photos.of_day(date)
          |> Enum.map(fn photo ->
            Enum.reduce(photo.thumbnails, %{small: nil, medium: nil, large: nil}, fn thumbnail,
                                                                                     acc ->
              url =
                Path.join(
                  "/photos",
                  Thumbnails.make_thumbnail_path(photo, thumbnail)
                )

              Map.put(acc, String.to_existing_atom(thumbnail.size_name), url)
            end)
            |> Map.put(:original, Path.join("/photos", Photos.make_photo_path(photo)))
          end)

        {:ok, assign(socket, date: date_str, photos: photos, previewed_photo_index: nil)}

      {:error, _} ->
        {:ok, socket |> put_flash(:error, "Invalid date") |> assign(date: "", photos: [])}
    end
  end

  def photo_url_preview(photos, photo_index) do
    photo = Enum.at(photos, photo_index)
    photo.large
  end

  def photo_url_original(photos, photo_index) do
    photo = Enum.at(photos, photo_index)
    photo.original
  end

  def handle_event("open-preview", %{"photo-index" => photo_index}, socket) do
    photo_index = String.to_integer(photo_index)
    {:noreply, assign(socket, :previewed_photo_index, photo_index)}
  end

  def handle_event("hide-preview", _params, socket) do
    {:noreply, assign(socket, :previewed_photo_index, nil)}
  end

  def handle_event("previewNavigate", %{"direction" => direction}, socket)
      when direction in ["left", "right"] do
    offset =
      case direction do
        "left" -> -1
        "right" -> +1
      end

    %{photos: photos, previewed_photo_index: previewed_photo_index} = socket.assigns
    new_index = update_preview_photo_index(photos, previewed_photo_index, offset)
    {:noreply, assign(socket, :previewed_photo_index, new_index)}
  end

  defp update_preview_photo_index(photos, current_index, offset) do
    (current_index + offset) |> Integer.mod(length(photos))
  end
end
