defmodule Photor.Imports.ImportSessionState do
  defstruct [
    :import_id,
    :import_status,
    # Map of path => FileImport struct
    :files,
    :bytes_to_import,
    :bytes_imported,
    :nb_files,
    :nb_files_skipped,
    :nb_files_imported,
    :nb_files_to_import,
    :current_file_path,
    :started_at,
    :last_event_id
  ]
end

defmodule Photor.Imports.ImportSession do
  @moduledoc """
  GenServer that tracks the state of a single import session.
  """
  use GenServer
  require Logger

  alias Photor.Imports.Events
  alias Photor.Imports.FileImport
  alias Photor.Imports.Import
  alias Photor.Imports.ImportRegistry
  alias Photor.Imports.ImportSessionState
  alias Phoenix.PubSub

  @pubsub_name Photor.PubSub
  @pubsub_topic "imports"

  # Client API

  @doc """
  Returns the PubSub topic for an import.
  """
  def pubsub_name(), do: @pubsub_name
  def pubsub_topic(), do: @pubsub_topic

  @doc """
  Starts a new import session for the given import.
  """
  def start_link(%Import{} = import) do
    GenServer.start_link(__MODULE__, import, name: via_tuple(import.id))
  end

  @doc """
  Returns the current state of an import session.
  """
  def get_import_info(import_id) do
    case ImportRegistry.lookup_session(import_id) do
      {:ok, pid} ->
        GenServer.call(pid, :get_import_info)

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @doc """
  Processes an import event.
  """
  def process_event(import_id, event) do
    case ImportRegistry.lookup_session(import_id) do
      {:ok, pid} -> GenServer.call(pid, {:event, event})
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  # helper

  defp make_import_info(state), do: Map.from_struct(state) |> Map.delete(:files)

  # Server callbacks

  @impl true
  def init(%Import{} = import) do
    Logger.info("Starting import session for import ##{import.id}")

    # Register with the registry
    ImportRegistry.register_session(import.id)

    state = %ImportSessionState{
      import_id: import.id,
      import_status: :starting,
      # Map of path => FileImport struct
      files: %{},
      bytes_to_import: 0,
      bytes_imported: 0,
      nb_files: 0,
      nb_files_skipped: 0,
      nb_files_imported: 0,
      nb_files_to_import: 0,
      current_file_path: nil,
      started_at: import.started_at,
      last_event_id: 0
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_import_info, _from, state) do
    # the whole state minus the files info is returned:
    {:reply, {:ok, make_import_info(state)}, state}
  end

  @impl true
  def handle_call({:event, event}, _from, state) do
    s = process_import_event(event, state)
    new_state = update_in(s.last_event_id, &(&1 + 1))

    broadcast({:import_update, state.import_id, make_import_info(new_state)})

    {:reply, :ok, new_state}
  end

  # Event handlers

  defp process_import_event(%Events.NewImport{}, state) do
    %{state | import_status: :started}
  end

  defp process_import_event(%Events.FilesFound{files: files}, state) do
    # Create a map of path => FileImport struct
    # TODO: somewhere should be checked the file.access value.
    files_map =
      files
      |> Enum.map(fn file ->
        {file.path,
         %FileImport{
           path: file.path,
           type: file.type,
           bytesize: file.bytesize,
           access: file.access,
           status: :todo
         }}
      end)
      |> Map.new()

    # the new files are merged with the existing ones, and in case the path
    # already exists, the existing value is kept, the new one is discarded, so
    # that import data regarding this file is not lost.
    s =
      update_in(state.files, fn state_files ->
        Map.merge(state_files, files_map, fn _path, state_file, _new_file ->
          state_file
        end)
      end)

    nb_files = Map.keys(s.files) |> length
    Map.put(s, :nb_files, nb_files)
  end

  defp process_import_event(%Events.ScanStarted{}, state) do
    %{state | import_status: :scanning}
  end

  defp process_import_event(%Events.FileNotYetInRepoFound{path: path}, state) do
    {file_import, state} =
      get_and_update_in(state.files[path], fn file_import ->
        fi = %{file_import | status: :to_import}
        {fi, fi}
      end)

    %{
      state
      | nb_files_to_import: state.nb_files_to_import + 1,
        bytes_to_import: state.bytes_to_import + file_import.bytesize
    }
  end

  defp process_import_event(%Events.FileAlreadyInRepoFound{path: path}, state) do
    # Update the status of the file to :skipped
    state =
      update_in(state.files[path], fn file_import ->
        %{file_import | status: :skipped}
      end)

    %{
      state
      | nb_files_skipped: state.nb_files_skipped + 1
    }
  end

  defp process_import_event(
         %Events.ImportStarted{
           nb_files_to_import: nb_files_to_import,
           bytes_to_import: bytes_to_import
         },
         state
       ) do
    %{
      state
      | import_status: :files_import,
        nb_files_to_import: nb_files_to_import,
        bytes_to_import: bytes_to_import
    }
  end

  defp process_import_event(%Events.FileImporting{path: path}, state) do
    # Update the status of the file to :ongoing

    {file_import, new_state} =
      get_and_update_in(state.files[path], fn file_import ->
        fi = %{file_import | status: :importing}
        {fi, fi}
      end)

    %{new_state | current_file_path: file_import.path}
  end

  defp process_import_event(%Events.FileImported{path: path}, state) do
    # Update the status of the file to :imported

    {file_import, state} =
      get_and_update_in(state.files[path], fn file_import ->
        fi = %{file_import | status: :imported}
        {fi, fi}
      end)

    %{
      state
      | bytes_imported: state.bytes_imported + (file_import.bytesize || 0),
        nb_files_imported: state.nb_files_imported + 1
    }
  end

  defp process_import_event(%Events.FileImportError{path: path, reason: _reason}, state) do
    # Update the status of the file to :error
    new_files =
      update_in(state.files[path], fn file_import ->
        %{file_import | status: :error}
      end)

    %{state | files: new_files}
  end

  defp process_import_event(%Events.ImportFinished{}, state) do
    %{
      state
      | import_status: :finished,
        current_file_path: nil
    }
  end

  # Helper functions

  defp via_tuple(import_id) do
    {:via, Registry, {ImportRegistry, import_id}}
  end

  defp broadcast(payload) do
    PubSub.broadcast(
      @pubsub_name,
      @pubsub_topic,
      payload
    )
  end
end
