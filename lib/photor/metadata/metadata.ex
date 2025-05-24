defmodule Photor.Metadata do
  alias Photor.Metadata.MainMetadata
  alias Photor.Metadata.Exiftool
  alias Photor.Metadata.ShutterSpeedDecoder

  def read(photo_path) do
    case Exiftool.read_as_json(photo_path) do
      {:ok, result} ->
        parse_json(result)

      {:error, exit_code, reason} ->
        {:error, "Failed to execute exiftool (exit code #{exit_code}, reason: #{reason})"}
    end
  end

  defp parse_json(json_data) do
    with {:ok, photo_exif} <- decode_pexif(json_data) do
      {:ok, photo_exif}
    else
      error when is_atom(error) or is_binary(error) ->
        {:error, "Failed to decode EXIF JSON: #{inspect(error)}"}

      _ ->
        {:error, "No EXIF data found"}
    end
  end

  defp map(map, key), do: Map.get(map, key)
  defp map(map, key, map_fn), do: Map.get(map, key) |> map_fn.()

  defp decode_pexif(data) do
    # Helper to safely fetch and map keys
    date_time_original = map(data, "DateTimeOriginal")
    create_date = map(data, "CreateDate")
    image_height = map(data, "ImageHeight", &parse_int/1)
    image_width = map(data, "ImageWidth", &parse_int/1)
    mime_type = map(data, "MIMEType")
    iso = map(data, "ISO", &parse_int/1)
    aperture = map(data, "Aperture", &parse_float/1)
    focal_length = map(data, "FocalLength")
    make = map(data, "Make")
    model = map(data, "Model")
    lens_info = map(data, "LensInfo") || map(data, "LensType")
    lens_make = map(data, "LensMake")
    lens_model = map(data, "LensModel")

    with {:ok, shutter_speed} <-
           map(data, "ShutterSpeed", &ShutterSpeedDecoder.decode/1) do
      {:ok,
       %MainMetadata{
         date_time_original: date_time_original,
         create_date: create_date,
         image_height: image_height,
         image_width: image_width,
         mime_type: mime_type,
         iso: iso,
         aperture: aperture,
         shutter_speed: shutter_speed,
         focal_length: focal_length,
         make: make,
         model: model,
         lens_info: lens_info,
         lens_make: lens_make,
         lens_model: lens_model
       }}
    end
  end

  defp parse_int(nil), do: nil
  defp parse_int(val) when is_binary(val), do: String.to_integer(val)
  defp parse_int(val) when is_number(val), do: round(val)
  defp parse_int(_), do: nil

  defp parse_float(nil), do: nil
  defp parse_float(val) when is_binary(val), do: String.to_float(val)
  defp parse_float(val) when is_number(val), do: val
  defp parse_float(_), do: nil
end
