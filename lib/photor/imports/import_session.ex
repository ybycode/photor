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

  defp make_import_info(state), do: Map.delete(state, :files)

  # Server callbacks

  @impl true
  def init(%Import{} = import) do
    Logger.info("Starting import session for import ##{import.id}")

    # Register with the registry
    ImportRegistry.register_session(import.id)

    state = %{
      import_id: import.id,
      import_status: :starting,
      # Map of path => FileImport struct
      files: %{},
      current_file_path: nil,
      total_bytes_to_import: 0,
      imported_bytes: 0,
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
    new_state =
      process_import_event(event, state)
      |> update_in([:last_event_id], &(&1 + 1))

    broadcast({:import_update, state.import_id, make_import_info(new_state)})

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

    {file_import, state} =
      get_and_update_in(state.files[path], fn file_import ->
        fi = %{file_import | status: :ongoing}
        {fi, fi}
      end)

    %{
      state
      | current_file_path: file_import.path,
        import_status: :importing
    }
  end

  defp process_import_event(%Events.FileImported{path: path}, state) do
    # Update the status of the file to :imported

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
        current_file_path: nil
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
        current_file_path: nil
    }
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
