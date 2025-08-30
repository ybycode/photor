defmodule Photor.Jobs.JobHandler do
  @moduledoc """
  Behaviour for job handlers.

  Each job type should have a corresponding module that implements this behaviour.
  """

  alias Photor.Jobs.Job

  @doc """
  Execute the job.

  Returns :ok on success, or {:error, reason} on failure.
  """
  @callback execute(%Job{}) :: :ok | {:error, String.t()}
end
