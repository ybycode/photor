defmodule Photor.Jobs.JobsRunnerTest do
  use ExUnit.Case, async: true
  alias Photor.Jobs.JobsRunner
  alias Photor.Jobs.Job, as: Job
  import Photor.TestHelpers, only: [override_test_config: 3]

  @test_supervisor :test_supervisor
  @test_runner :test_runner
  @mock_config_key :test_mock

  # Define a mock handler module for testing
  defmodule MockHandler do
    @behaviour Photor.Jobs.JobHandler
    @mock_config_key :test_mock

    @impl true
    def execute(%Job{id: job_id}) do
      test_pid =
        Application.fetch_env!(:photor, @mock_config_key)
        |> Keyword.fetch!(:test_pid)

      send(test_pid, {:worker_started, job_id})

      :ok
    end
  end

  defmodule TestBlockHandler do
    @behaviour Photor.Jobs.JobHandler
    @mock_config_key :test_mock

    @impl true
    def execute(%Job{id: job_id}) do
      test_pid =
        Application.fetch_env!(:photor, @mock_config_key)
        |> Keyword.fetch!(:test_pid)

      # tell the test process it started alright:
      send(test_pid, {:worker_started, job_id, self()})

      # now it blocks until it receives a message:
      receive do
        _ -> :ok
      end

      :ok
    end
  end

  setup(ctx) do
    # For each test we start a supervisor, which starts a job runner. Names
    # are forced via the options:
    start_link_supervised!({Task.Supervisor, [name: @test_supervisor]})

    # tests can pass opts to the jobs runner genserver:
    jobs_runner_opts = ctx[:jobs_runner_opts] || []

    start_link_supervised!(
      {Photor.Jobs.JobsRunner,
       Keyword.merge(jobs_runner_opts, name: @test_runner, supervisor_name: @test_supervisor)}
    )

    setup_mock_handler()

    :ok
  end

  defp setup_mock_handler() do
    override_test_config(:photor, @mock_config_key, test_pid: self())
  end

  describe "add_job/1, and how tasks are started" do
    test "creates a job with correct defaults and adds it to state" do
      # Add a job with the mock handler
      {:ok, _job} = JobsRunner.add_job(MockHandler, @test_runner)

      # Get the list of jobs to verify it was added
      jobs = JobsRunner.list_jobs(@test_runner)

      assert length(jobs) == 1
      job = List.first(jobs)

      # Verify the job has correct values
      assert %Job{} = job
      assert job.handler_mod == MockHandler
      assert job.status == :running
      assert job.nb_items == 0
      assert job.nb_items_success == 0
      assert job.nb_items_error == 0
      assert %DateTime{} = job.created_at
      assert job.started_at == nil
      assert job.completed_at == nil

      assert_receive {:worker_started, _job_id}
    end

    @tag jobs_runner_opts: [max_workers: 2]
    test "Starts up to `max_workers` workers" do
      # Let's add two jobs:
      {:ok, job1} = JobsRunner.add_job(TestBlockHandler, @test_runner)
      {:ok, job2} = JobsRunner.add_job(TestBlockHandler, @test_runner)
      {:ok, job3} = JobsRunner.add_job(TestBlockHandler, @test_runner)

      # Verify the job was started
      assert_receive {:worker_started, job_a_id, job_a_pid}
      assert_receive {:worker_started, job_b_id, job_b_pid}

      # messages are coming in a random order. Some mambo jambo needed to figure out what's what:
      id_to_pid = %{} |> Map.put(job_a_id, job_a_pid) |> Map.put(job_b_id, job_b_pid)
      job1_pid = id_to_pid[job1.id]
      job2_pid = id_to_pid[job2.id]
      refute is_nil(job1_pid)
      refute is_nil(job2_pid)

      # let's get a fresh version of those jobs
      {:ok, job1} = JobsRunner.get_job(job1.id, @test_runner)
      {:ok, job2} = JobsRunner.get_job(job2.id, @test_runner)
      {:ok, job3} = JobsRunner.get_job(job3.id, @test_runner)

      # and see their respective status:
      assert job1.status == :running
      assert job2.status == :running
      assert job3.status == :pending

      # now let's unblock the job 1:
      send(job1_pid, nil)
      # the job 3 should start and tell about it:
      job3_id = job3.id
      assert_receive {:worker_started, ^job3_id, _job3_pid}

      # now let's see that their respective status is as expected:
      {:ok, job1} = JobsRunner.get_job(job1.id, @test_runner)
      {:ok, job2} = JobsRunner.get_job(job2.id, @test_runner)
      {:ok, job3} = JobsRunner.get_job(job3.id, @test_runner)

      # and see their respective status:
      assert job1.status == :completed
      assert job2.status == :running
      assert job3.status == :running
    end

    test "rejects non-module handlers" do
      assert {:error, :invalid_handler} = JobsRunner.add_job("not a module", @test_runner)
      assert JobsRunner.list_jobs(@test_runner) == []
    end

    test "rejects modules that don't implement JobHandler" do
      assert {:error, :invalid_handler} = JobsRunner.add_job(Enum, @test_runner)
      assert JobsRunner.list_jobs(@test_runner) == []
    end
  end

  describe "get_job/2" do
    test "returns the job when it exists" do
      # Add a job
      {:ok, job} = JobsRunner.add_job(MockHandler, @test_runner)
      job_id = job.id

      # Verify we can get the job directly

      # Verify get_job returns the correct job
      assert {:ok, %Job{id: ^job_id}} = JobsRunner.get_job(job_id, @test_runner)
    end

    test "returns error when job doesn't exist" do
      # Try to get a non-existent job
      assert {:error, :not_found} = JobsRunner.get_job(999, @test_runner)
    end
  end
end
