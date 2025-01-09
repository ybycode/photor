defmodule PhotorUiWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use PhotorUiWeb, :html

  embed_templates "page_html/*"

  def photo_url(date, photo_filename) do
    Path.join(["/photos", Date.to_string(date), photo_filename])
  end
end
