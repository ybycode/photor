defmodule Photor.Imports.FileImport do
  # status is one of: :todo, :ongoing, :error, :imported, :skipped
  defstruct [
    :path,
    :type,
    :bytesize,
    :access,
    :status
  ]
end
