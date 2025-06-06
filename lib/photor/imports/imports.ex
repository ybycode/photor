defmodule Photor.Imports do
  alias Photor.Imports.Import
  alias Photor.Imports.ImportTracker
  alias Photor.Imports.Importer
  alias Photor.Repo

  require Logger

  @doc """
  Starts a new import from the given source directory.
  Returns {:ok, import_id} if successful.
  """
  def start_import(source_dir) do
    import = Import.new_changeset() |> Repo.insert!()

    # Start the import process in a separate task
    Task.start(fn ->
      Importer.import_directory(import, source_dir, [], fn event ->
        GenServer.call(Photor.Imports.ImportTracker, event)
      end)
    end)

    {:ok, import}
  end

  #  @doc """
  #  Gets the current state of an ongoing import and subscribes to updates.
  #  """
  #  def get_state_and_subscribe do
  #    ImportTracker.get_state_and_subscribe()
  #  end

  @doc """
  Gets the current state of an ongoing import without subscribing.
  """
  def get_state do
    ImportTracker.get_state()
  end

  # @doc """
  # Subscribe to import events.
  # """
  # def subscribe do
  #   ImportTracker.subscribe()
  # end

  @doc """
  Gets the most recent import from the database.
  """
  def get_most_recent_import do
    Import.query_most_recent()
    |> Repo.one()
  end
end
