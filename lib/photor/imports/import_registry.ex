defmodule Photor.Imports.ImportRegistry do
  @moduledoc """
  Registry for tracking import sessions.
  """

  @doc """
  Returns the registry name used for import sessions.
  """
  def registry_name, do: __MODULE__

  @doc """
  Registers a process with the registry.
  """
  def register_session(import_id) do
    Registry.register(registry_name(), {:import, import_id}, [])
  end

  @doc """
  Looks up an import session by import_id.
  """
  # what's the point of this function, since we can use a via tuple, AI
  def lookup_session(import_id) do
    case Registry.lookup(registry_name(), {:import, import_id}) do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Lists all active import sessions.
  """
  def list_sessions do
    Registry.select(registry_name(), [{{:_, {:import, :"$1"}, :_}, [], [:"$1"]}])
  end
end
