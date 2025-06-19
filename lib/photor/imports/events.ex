defmodule Photor.Imports.Events do
  @moduledoc """
  Defines event structs for import operations.
  """
  defmodule NewImport do
    defstruct [:import_id, :started_at, :source_dir]
  end

  defmodule FilesFound do
    defstruct [:import_id, :files]
  end

  defmodule ScanStarted do
    defstruct [:import_id]
  end

  defmodule ImportStarted do
    defstruct [
      :import_id,
      :nb_files_to_import,
      :bytes_to_import
    ]
  end

  defmodule FileNotYetInRepoFound do
    # TODO: find a better name, or rename the FilesFound event.
    defstruct [:import_id, :path]
  end

  defmodule FileAlreadyInRepoFound do
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
    defstruct [:import_id]
  end

  defmodule FileImportError do
    defstruct [
      :import_id,
      :path,
      :reason
    ]
  end
end
