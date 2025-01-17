defmodule PhotorUiWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use PhotorUiWeb, :html

  embed_templates "page_html/*"

  def photo_url_preview(date, photo_filename) do
    preview_filename = String.replace_suffix(photo_filename, ".jpg", "_thumbnail_800px.jpg")
    Path.join(["/photos", date, preview_filename])
  end
end
