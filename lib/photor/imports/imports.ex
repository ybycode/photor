defmodule Photor.Imports do
  alias Photor.Imports.Import
  alias Photor.Imports.ImportSession
  alias Photor.Imports.ImportSupervisor
  alias Photor.Imports.Importer
  alias Photor.Repo
  alias Phoenix.PubSub

  require Logger

  @pubsub Photor.PubSub

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
          Importer.import_directory(import, source_dir, [], fn event ->
            ImportSession.process_event(import.id, event)
          end)
        end)

        {:ok, import}

      {:error, reason} ->
        Logger.error("Failed to start import session: #{inspect(reason)}")
        {:error, :session_start_failed}
    end
  end

  @doc """
  Gets the current state of an import.
  """
  def get_import_state(import_id) do
    ImportSession.get_state(import_id)
  end

  @doc """
  Subscribe to events for a specific import.
  """
  def subscribe_to_import(import_id) do
    PubSub.subscribe(@pubsub, ImportSession.pubsub_topic(import_id))
  end

  @doc """
  Gets the most recent import from the database.
  """
  def get_most_recent_import do
    Import.query_most_recent()
    |> Repo.one()
  end

  @doc """
  Lists all active import sessions.
  """
  def list_active_imports do
    Photor.Imports.ImportRegistry.list_sessions()
  end
end
