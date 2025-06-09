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
  alias Phoenix.PubSub

  @pubsub Photor.PubSub

  # Client API

  @doc """
  Starts a new import session for the given import.
  """
  def start_link(%Import{} = import) do
    GenServer.start_link(__MODULE__, import, name: via_tuple(import.id))
  end

  @doc """
  Returns the current state of an import session.
  """
  def get_state(import_id) do
    # TODO get rid of this lookup_session
    case ImportRegistry.lookup_session(import_id) do
      {:ok, pid} -> GenServer.call(pid, :get_state)
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  @doc """
  Processes an import event.
  """
  def process_event(import_id, event) do
    # TODO get rid of this lookup_session
    case ImportRegistry.lookup_session(import_id) do
      {:ok, pid} -> GenServer.call(pid, {:event, event})
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  @doc """
  Returns the PubSub topic for an import.
  """
  def pubsub_topic(import_id), do: "import:#{import_id}"

  # Server callbacks

  @impl true
  def init(%Import{} = import) do
    Logger.info("Starting import session for import ##{import.id}")

    # Register with the registry
    ImportRegistry.register_session(import.id)

    state = %{
      import: import,
      import_status: :starting,
      # Map of path => FileImport struct
      files: %{},
      current_file: nil,
      total_bytes_to_import: 0,
      imported_bytes: 0,
      started_at: import.started_at
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:event, event}, _from, state) do
    new_state = process_import_event(event, state)

    # Broadcast the event to subscribers if needed
    PubSub.broadcast(@pubsub, pubsub_topic(state.import.id), {:import_event, event})

    {:reply, :ok, new_state}
  end

  # Event handlers

  defp process_import_event(%Events.ImportStarted{}, state) do
    %{state | import_status: :started}
  end

  defp process_import_event(%Events.FilesFound{files: files}, state) do
    # Create a map of path => FileImport struct
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

    # Calculate total bytes to import
    total_bytes = Enum.reduce(files, 0, fn %{bytesize: size}, acc -> acc + size end)

    %{
      state
      | files: files_map,
        total_bytes_to_import: total_bytes,
        # TODO: at this point the scanning is done, so this needs changing.
        import_status: :scanning
    }
  end

  defp process_import_event(%Events.FileSkipped{path: path}, state) do
    # Update the status of the file to :skipped
    update_in(state.files[path], fn file_import ->
      %{file_import | status: :skipped}
    end)
  end

  defp process_import_event(%Events.FileImporting{path: path}, state) do
    # Update the status of the file to :ongoing
    # TODO: maybe use get_and_update_in here, to avoid the Map.get that follows?
    new_state =
      update_in(state.files[path], fn file_import ->
        %{file_import | status: :ongoing}
      end)

    # Set as current file
    current_file = Map.get(new_state.files, path)

    %{
      new_state
      | current_file: current_file,
        import_status: :importing
    }
  end

  defp process_import_event(%Events.FileImported{path: path}, state) do
    # Update the status of the file to :imported

    # TODO: use get_and_update_in/2 here instead of fetching after
    {file_import, state} =
      get_and_update_in(state.files[path], fn file_import ->
        fi = %{file_import | status: :imported}
        {fi, fi}
      end)

    # Calculate imported bytes
    imported_bytes = state.imported_bytes + (file_import.bytesize || 0)

    %{
      state
      | imported_bytes: imported_bytes,
        current_file: nil
    }
  end

  defp process_import_event(%Events.ImportError{path: path, reason: _reason}, state) do
    # Update the status of the file to :error
    new_files =
      update_in(state.files[path], fn file_import ->
        %{file_import | status: :error}
      end)

    %{
      state
      | files: new_files,
        current_file: nil
    }
  end

  defp process_import_event(%Events.ImportFinished{}, state) do
    %{
      state
      | import_status: :finished,
        current_file: nil
    }
  end

  # Helper functions

  defp via_tuple(import_id) do
    {:via, Registry, {ImportRegistry, import_id}}
  end
end
