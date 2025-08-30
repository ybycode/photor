defmodule Photor.Jobs.WorkersSupervisor do
  @default_name __MODULE__

  def start_worker(fun, supervisor \\ @default_name) do
    Task.Supervisor.async_nolink(supervisor, fun)
  end
end
