defmodule Photor.Imports.ImportTracker do
  use GenServer
  require Logger

  alias Phoenix.PubSub

  alias Photor.Imports.Events.FileImported
  alias Photor.Imports.Events.FileImporting
  alias Photor.Imports.Events.FileSkipped
  alias Photor.Imports.Events.FilesFound
  # alias Photor.Imports.Events.ImportError
  alias Photor.Imports.Events.ImportFinished
  alias Photor.Imports.Events.ImportStarted
  alias Photor.Imports.FileImport

  @pubsub Photor.PubSub
  @topic "imports"
  @default_name __MODULE__

  # Client API

  def pubsub_topic, do: @topic

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], name: opts[:name] || @default_name)
  end

  #  @doc """
  #  Get the current state of an ongoing import, if any.
  #  Also subscribes the caller to future updates.
  #
  #  Returns a tuple with the current state and a reference that can be used
  #  to identify which updates have already been seen.
  #  """
  #  def get_state_and_subscribe do
  #    GenServer.call(__MODULE__, :get_state_and_subscribe)
  #  end
  #
  @doc """
  Get just the current state without subscribing.
  """
  def get_state(pid \\ @default_name) do
    GenServer.call(pid, :get_state)
  end

  #
  #  @doc """
  #  Subscribe to import events.
  #  """
  #  def subscribe do
  #    PubSub.subscribe(@pubsub, @topic)
  #  end
  #
  #  # Server callbacks
  #
  @impl true
  def init(_opts) do
    {:ok,
     %{
       files_by_path: %{},
       last_event_id: 0,
       import_status: :no_started
     }}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  #
  #  @impl true
  #  def handle_call(:get_state_and_subscribe, _from, state) do
  #    # Subscribe the caller to the topic
  #    PubSub.subscribe(@pubsub, @topic)
  #
  #    # Return the current state along with the last event ID
  #    # This ID will help the client know which events it has already seen
  #    {:reply, {state, state.last_event_id}, state}
  #  end
  #
  @impl true
  def handle_call(
        %ImportStarted{import_id: import_id, started_at: _started_at, source_dir: _source_dir} =
          event,
        _from,
        state
      ) do
    new_state =
      %{
        state
        | import_status: :ongoing
      }
      |> increment_event_id

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(%FilesFound{files: files}, _from, state) do
    new_files_by_path =
      Enum.reduce(files, %{}, fn file, acc ->
        Map.put(acc, file.path, %{
          struct(FileImport, Map.from_struct(file))
          | status: :todo
        })
      end)

    new_state =
      update_in(state.files_by_path, fn files_by_path ->
        Map.merge(files_by_path, new_files_by_path)
      end)
      |> increment_event_id

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(%FileSkipped{path: path}, _from, state) do
    # Update the file status

    new_state =
      update_in(state[:files_by_path][path], fn file_import ->
        %{file_import | status: :skipped}
      end)
      |> increment_event_id

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(%FileImporting{path: _path}, _from, state) do
    # Update the file status and current file
    new_state = increment_event_id(state)

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(%FileImported{path: path}, _from, state) do
    new_state =
      update_in(state[:files_by_path][path], fn file_import ->
        %{file_import | status: :imported}
      end)
      |> increment_event_id

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(%ImportFinished{}, _from, state) do
    # Increment event id
    new_state =
      %{
        state
        | import_status: :done
      }
      |> increment_event_id

    {:reply, :ok, new_state}
  end

  # @impl true
  # def handle_cast(%ImportError{path: path}, state) do
  #   # Treat errors as skipped files for now
  #   file_statuses = Map.put(state.file_statuses, path, :skipped)

  #   new_state =
  #     %{state | file_statuses: file_statuses}
  #     |> increment_event_id

  #   {:noreply, new_state}
  # end

  #
  #  # Private functions

  def increment_event_id(%{last_event_id: last_event_id} = state) do
    %{state | last_event_id: last_event_id + 1}
  end
end
