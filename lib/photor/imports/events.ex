defmodule Photor.Imports.Events do
  @moduledoc """
  Defines event structs for import operations.
  """
  defmodule ImportStarted do
    defstruct [:import_id, :started_at, :source_dir]
  end

  defmodule FilesFound do
    defstruct [:import_id, :files]
  end

  defmodule FileSkipped do
    defstruct [:import_id, :path]
  end

  defmodule FileImporting do
    defstruct [:import_id, :path]
  end

  defmodule FileImported do
    defstruct [
      :import_id,
      :path
    ]
  end

  defmodule ImportFinished do
    defstruct [
      :import_id,
      :total_files,
      :skipped_count,
      :imported_count,
      :imported_bytes
    ]
  end

  defmodule ImportError do
    defstruct [
      :import_id,
      :path,
      :reason
    ]
  end
end
