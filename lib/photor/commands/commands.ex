defmodule Photor.Commands do
  alias Photor.Imports

  def import_directory(directory), do: Imports.start_import(directory)
end
