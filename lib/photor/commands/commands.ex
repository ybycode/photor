defmodule Photor.Commands do
  alias Photor.Imports

  def import_directory(directory), do: Imports.import_directory(directory)
end
