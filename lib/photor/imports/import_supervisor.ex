defmodule Photor.Imports.ImportSupervisor do
  @moduledoc """
  Supervisor for import sessions.
  """
  use DynamicSupervisor
  require Logger

  alias Photor.Imports.Import
  alias Photor.Imports.ImportSession

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, nil, name: opts[:name] || __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Starts a new import session under the supervisor.
  """
  def start_import_session(%Import{} = import, supervisor_pid \\ __MODULE__) do
    DynamicSupervisor.start_child(supervisor_pid, {ImportSession, import})
  end

  @doc """
  Stops an import session.
  """
  def stop_import_session(import_id, supervisor_pid \\ __MODULE__) do
    # why not using the ImportSession.via_tuple/1 function here, instead of this lookup_session/1 call, AI?
    case Photor.Imports.ImportRegistry.lookup_session(import_id) do
      {:ok, pid} ->
        DynamicSupervisor.terminate_child(supervisor_pid, pid)

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end
end
