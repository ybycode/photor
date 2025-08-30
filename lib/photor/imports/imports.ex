defmodule Photor.Imports do
  alias Photor.Imports.ImportRegistry
  alias Photor.Imports.Import
  alias Photor.Imports.ImportSession
  alias Photor.Imports.ImportSupervisor
  alias Photor.Imports.Importer
  alias Photor.Jobs.JobsRunner
  alias Photor.Repo
  alias Phoenix.PubSub

  require Logger

  defdelegate pubsub_topic, to: ImportSession
  defdelegate pubsub_name, to: ImportSession

  @doc """
  Starts a new import from the given source directory.
  Returns {:ok, import} if successful.
  """
  def start_import(source_dir) do
    # Create a new import record
    import = Import.new_changeset() |> Repo.insert!()

    # Start a new import session
    case ImportSupervisor.start_import_session(import) do
      {:ok, _pid} ->
        # Start the import process in a separate task
        Task.start(fn ->
          :ok =
            Importer.import_directory(
              import,
              source_dir,
              [],
              fn event -> ImportSession.process_event(import.id, event) end
            )

          # now add a job to create thumbnails:
          {:ok, _job} = JobsRunner.add_job(Photor.Photos.Thumbnails.Job)
        end)

        {:ok, import}

      {:error, reason} ->
        Logger.error("Failed to start import session: #{inspect(reason)}")
        {:error, :session_start_failed}
    end
  end

  def subscribe_to_import_sessions() do
    PubSub.subscribe(pubsub_name(), pubsub_topic())
  end

  @doc """
  Subscribe to events for a specific import.
  """
  def get_all_imports_info() do
    # the current state of all ongoing imports is fetched:
    ImportRegistry.list_sessions()
    |> Enum.reduce(%{}, fn pid, acc ->
      {:ok, %{import_id: import_id} = import_info} = GenServer.call(pid, :get_import_info)
      Map.put(acc, import_id, import_info)
    end)
  end

  @doc """
  Gets the most recent import from the database.
  """
  def get_most_recent_import do
    Import.query_most_recent()
    |> Repo.one()
  end
end
