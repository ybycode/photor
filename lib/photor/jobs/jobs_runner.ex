defmodule Photor.Jobs.JobsRunner do
  use GenServer
  alias Photor.Jobs.Job, as: Job
  alias Photor.Jobs.WorkersSupervisor

  # Client API

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def add_job(handler_mod, server \\ __MODULE__) do
    GenServer.call(server, {:add_job, handler_mod})
  end

  def list_jobs(server \\ __MODULE__) do
    GenServer.call(server, :list_jobs)
  end

  def get_job(job_id, server \\ __MODULE__) do
    GenServer.call(server, {:get_job, job_id})
  end

  def update_job_progress(job_id, progress_data) do
    GenServer.cast(__MODULE__, {:update_progress, job_id, progress_data})
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    state = %{
      jobs_by_id: %{},
      # jobs not yet started (insertion at the tail, next to start is the head):
      pending_jobs_ids: [],
      # currently running jobs:
      running_jobs_ids: [],
      # both completed and failed jobs go here:
      finished_jobs_ids: [],
      # TODO, what to store in there?
      workers: %{},
      max_workers: Keyword.get(opts, :max_workers, 1),
      # the name of the supervisor that manages the workers (Elixir's Job processes)
      supervisor: Keyword.fetch!(opts, :supervisor_name)
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:add_job, handler_mod}, _from, state) do
    if is_atom(handler_mod) and Code.ensure_loaded?(handler_mod) and
         function_exported?(handler_mod, :execute, 1) do
      job_id = System.unique_integer([:positive])

      job = %Job{
        id: job_id,
        handler_mod: handler_mod,
        status: :pending,
        created_at: DateTime.utc_now(),
        nb_items: 0,
        nb_items_success: 0,
        nb_items_error: 0
      }

      GenServer.cast(self(), :maybe_start_job)

      new_state =
        state
        |> update_in([:jobs_by_id], &Map.put(&1, job_id, job))
        |> update_in([:pending_jobs_ids], &(&1 ++ [job_id]))

      {:reply, {:ok, job}, new_state}
    else
      {:reply, {:error, :invalid_handler}, state}
    end
  end

  @impl true
  def handle_call(:list_jobs, _from, state) do
    jobs_list = Map.values(state.jobs_by_id)
    {:reply, jobs_list, state}
  end

  @impl true
  def handle_call({:get_job, job_id}, _from, state) do
    case Map.get(state.jobs_by_id, job_id) do
      nil -> {:reply, {:error, :not_found}, state}
      job -> {:reply, {:ok, job}, state}
    end
  end

  @impl true
  # no jobs to consume, do nothing
  def handle_cast(:maybe_start_job, %{pending_jobs_ids: []} = state), do: {:noreply, state}

  def handle_cast(
        :maybe_start_job,
        %{
          jobs_by_id: jobs_by_id,
          running_jobs_ids: running_jobs_ids,
          pending_jobs_ids: pending_jobs_ids,
          supervisor: supervisor,
          max_workers: max_workers
        } = state
      ) do
    nb_running_jobs = length(running_jobs_ids)

    if nb_running_jobs < max_workers do
      # the next job to run is the one at the head of `pending_jobs_ids`:
      [next_job_id | pending_jobs_ids] = pending_jobs_ids
      next_job = Map.fetch!(jobs_by_id, next_job_id)

      # it is started under the workers supervisor, and not linked to this
      # process to not crash it whatever happens.
      worker =
        WorkersSupervisor.start_worker(
          fn ->
            apply(next_job.handler_mod, :execute, [next_job])
          end,
          supervisor
        )

      # it's status is changed to running:
      next_job = Map.put(next_job, :status, :running)

      # and the updated state is build:
      # - the worker reference is saved in the workers key,
      # - the job with its new status (:running) is updated in jobs_by_id,
      # - the job is removed from the pending_jobs_ids list,
      # - it is added to the running_jobs_ids list,
      new_state =
        state
        |> update_in([:workers], &Map.put(&1, worker.ref, next_job_id))
        |> update_in([:jobs_by_id], &Map.put(&1, next_job_id, next_job))
        |> Map.put(:pending_jobs_ids, pending_jobs_ids)
        |> update_in([:running_jobs_ids], &(&1 ++ [next_job.id]))

      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:update_progress, _job_id, _progress_data}, state) do
    # Empty implementation
    {:noreply, state}
  end

  @impl true
  def handle_info({ref, answer}, state) do
    # We don't care about the DOWN message now, so let's demonitor and flush it
    Process.demonitor(ref, [:flush])

    success? =
      case answer do
        {:ok, _} -> true
        :ok -> true
        {:error, _} -> false
        :error -> false
      end

    # the job id associated to this ref:
    job_id = Map.fetch!(state.workers, ref)
    # the job is fetched and its status is changed:
    job =
      Map.fetch!(state.jobs_by_id, job_id)
      |> Map.put(:status, if(success?, do: :completed, else: :failed))

    # The new state is built:
    # - the worker associated to this ref is removed,
    # - the job id is removed from the running_jobs_ids list,
    # - the job is with its new status is updated in jobs_by_id,
    # - the job id is added to the finished_jobs_ids list.,
    new_state =
      state
      |> update_in([:workers], &Map.delete(&1, ref))
      |> update_in([:running_jobs_ids], fn running_jobs_ids ->
        Enum.filter(running_jobs_ids, &(&1 != job_id))
      end)
      |> update_in([:jobs_by_id], &Map.put(&1, job_id, job))
      |> update_in([:finished_jobs_ids], &(&1 ++ [job.id]))

    # since a job finished, a new one could be started:
    GenServer.cast(self(), :maybe_start_job)

    {:noreply, new_state}
  end

  # Private functions

  # defp broadcast_job_update(job) do
  #   # Empty implementation
  # end
end
