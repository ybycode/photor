defmodule Photor.Metadata do
  alias Photor.Metadata.MainMetadata
  alias Photor.Metadata.ShutterSpeedDecoder

  @exiftool_module Application.compile_env(:photor, :exiftool_module, Photor.Metadata.Exiftool)
  @fallback_creation_date "1970-01-01 00:00:00"

  @doc """
  Reads metadata from a photo file and returns a structured MainMetadata struct.
  """
  def read(photo_path) do
    case @exiftool_module.read_as_json(photo_path) do
      {:ok, exif_data} ->
        extract_main_metadata(exif_data)

      {:error, :file_not_found} ->
        {:error, "File not found: #{photo_path}"}

      {:error, reason} ->
        {:error, "Failed to read metadata: #{inspect(reason)}"}
    end
  end

  defp extract_main_metadata(exif_data) do
    with {:ok, shutter_speed} <-
           map_key(exif_data, "ShutterSpeed", &ShutterSpeedDecoder.decode/1) do
      {:ok,
       %MainMetadata{
         create_date:
           parse_datetime(
             # 2 fields from the metadata are considered:
             map_key(exif_data, "DateTimeOriginal") ||
               map_key(exif_data, "CreateDate") ||
               @fallback_creation_date
           ),
         image_height: map_key(exif_data, "ImageHeight", &parse_int/1),
         image_width: map_key(exif_data, "ImageWidth", &parse_int/1),
         mime_type: map_key(exif_data, "MIMEType"),
         iso: map_key(exif_data, "ISO", &parse_int/1),
         aperture: map_key(exif_data, "Aperture", &parse_float/1),
         shutter_speed: shutter_speed,
         focal_length: map_key(exif_data, "FocalLength"),
         make: map_key(exif_data, "Make"),
         model: map_key(exif_data, "Model"),
         lens_info: map_key(exif_data, "LensInfo") || map_key(exif_data, "LensType"),
         lens_make: map_key(exif_data, "LensMake"),
         lens_model: map_key(exif_data, "LensModel")
       }}
    else
      {:error, reason} -> {:error, "Failed to process shutter speed: #{reason}"}
    end
  end

  defp map_key(map, key), do: Map.get(map, key)
  defp map_key(map, key, map_fn), do: Map.get(map, key) |> map_fn.()

  defp parse_int(nil), do: nil
  defp parse_int(val) when is_binary(val), do: String.to_integer(val)
  defp parse_int(val) when is_number(val), do: round(val)
  defp parse_int(_), do: nil

  defp parse_float(nil), do: nil
  defp parse_float(val) when is_binary(val), do: String.to_float(val)
  defp parse_float(val) when is_number(val), do: val
  defp parse_float(_), do: nil

  defp parse_datetime(nil), do: nil

  defp parse_datetime(datetime_str) when is_binary(datetime_str) do
    case NaiveDateTime.from_iso8601(datetime_str) do
      {:ok, datetime} ->
        datetime

      _ ->
        # Try with a space instead of T
        case NaiveDateTime.from_iso8601(String.replace(datetime_str, " ", "T")) do
          {:ok, datetime} -> datetime
          _ -> nil
        end
    end
  end

  defp parse_datetime(_), do: nil
end
