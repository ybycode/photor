defmodule Photor.Imports.ImportSession do
  @moduledoc """
  GenServer that tracks the state of a single import session.
  """
  use GenServer
  require Logger

  alias Photor.Imports.Events
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
    case ImportRegistry.lookup_session(import_id) do
      {:ok, pid} -> GenServer.call(pid, :get_state)
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  @doc """
  Processes an import event.
  """
  def process_event(import_id, event) do
    case ImportRegistry.lookup_session(import_id) do
      {:ok, pid} -> GenServer.cast(pid, {:event, event})
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
      files_found: [],
      files_to_import: [],
      files_skipped: [],
      files_imported: [],
      files_with_errors: [],
      current_file: nil,
      total_bytes_to_import: 0,
      imported_bytes: 0,
      started_at: DateTime.utc_now()
    }
    
    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:event, event}, state) do
    {new_state, broadcast_event} = process_import_event(event, state)
    
    # Broadcast the event to subscribers if needed
    if broadcast_event do
      PubSub.broadcast(@pubsub, pubsub_topic(state.import.id), {:import_event, event})
    end
    
    {:noreply, new_state}
  end

  # Event handlers

  defp process_import_event(%Events.ImportStarted{}, state) do
    new_state = %{state | import_status: :started}
    {new_state, true}
  end

  defp process_import_event(%Events.FilesFound{files: files}, state) do
    # Calculate total bytes to import
    files_to_import = files
    total_bytes = Enum.reduce(files, 0, fn %{bytesize: size}, acc -> acc + size end)
    
    new_state = %{
      state |
      files_found: files,
      files_to_import: files_to_import,
      total_bytes_to_import: total_bytes,
      import_status: :scanning
    }
    
    {new_state, true}
  end

  defp process_import_event(%Events.FileSkipped{path: path}, state) do
    skipped_file = Enum.find(state.files_found, fn %{path: p} -> p == path end)
    
    new_state = %{
      state |
      files_skipped: [skipped_file | state.files_skipped]
    }
    
    {new_state, true}
  end

  defp process_import_event(%Events.FileImporting{path: path}, state) do
    current_file = Enum.find(state.files_found, fn %{path: p} -> p == path end)
    
    new_state = %{
      state |
      current_file: current_file,
      import_status: :importing
    }
    
    {new_state, true}
  end

  defp process_import_event(%Events.FileImported{path: path}, state) do
    imported_file = Enum.find(state.files_found, fn %{path: p} -> p == path end)
    imported_bytes = state.imported_bytes + (imported_file.bytesize || 0)
    
    new_state = %{
      state |
      files_imported: [imported_file | state.files_imported],
      imported_bytes: imported_bytes,
      current_file: nil
    }
    
    {new_state, true}
  end

  defp process_import_event(%Events.ImportError{path: path, reason: reason}, state) do
    error_file = Enum.find(state.files_found, fn %{path: p} -> p == path end)
    
    new_state = %{
      state |
      files_with_errors: [{error_file, reason} | state.files_with_errors],
      current_file: nil
    }
    
    {new_state, true}
  end

  defp process_import_event(%Events.ImportFinished{}, state) do
    new_state = %{
      state |
      import_status: :finished,
      current_file: nil
    }
    
    {new_state, true}
  end

  defp process_import_event(_unknown_event, state) do
    # Ignore unknown events
    {state, false}
  end

  # Helper functions

  defp via_tuple(import_id) do
    {:via, Registry, {ImportRegistry.registry_name(), {:import, import_id}}}
  end
end
