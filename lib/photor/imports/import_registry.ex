defmodule Photor.Imports.ImportRegistry do
  @moduledoc """
  Registry for tracking import sessions.
  """

  @doc """
  Registers the curent process process with the registry.
  """
  def register_session(import_id, registry_name \\ __MODULE__) do
    Registry.register(registry_name, import_id, [])
  end

  @doc """
  Looks up an import session by import_id.
  """
  def lookup_session(import_id, registry_name \\ __MODULE__) do
    case Registry.lookup(registry_name, import_id) do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Lists all active import sessions.
  """
  def list_sessions(registry_name \\ __MODULE__) do
    Registry.select(registry_name, [{{:_, :"$1", :_}, [], [:"$1"]}])
  end
end
