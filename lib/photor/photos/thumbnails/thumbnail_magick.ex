defmodule Photor.Photos.Thumbnails.ThumbnailMagick do
  @moduledoc """
  Implementation of thumbnail generation using ImageMagick and cjpeg.
  """
  @behaviour Photor.Photos.Thumbnails

  @impl true
  def thumbnail_cmd(source_path, output_path, max_width, max_height, quality) do
    size_spec = "#{max_width}x#{max_height}>"

    ~s"""
    magick \
      "#{source_path}" \
      -auto-orient \
      -thumbnail \
      "#{size_spec}" \
      PPM:- \
    | cjpeg \
      -quality \
      #{quality} \
      -outfile "#{output_path}"
    """
  end
end
