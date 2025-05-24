defmodule Photor.Metadata.MainMetadata do
  @moduledoc """
  Represents metadata extracted from a photo using `exiftool`.
  Matches the structure expected by the Ecto schema `Photor.Photos.Photo`.
  """

  defstruct [
    :date_time_original,
    :create_date,
    :image_height,
    :image_width,
    :mime_type,
    :iso,
    :aperture,
    :shutter_speed,
    :focal_length,
    :make,
    :model,
    :lens_info,
    :lens_make,
    :lens_model
  ]
end
