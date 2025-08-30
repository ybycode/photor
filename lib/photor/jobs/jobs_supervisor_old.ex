defmodule Photor.Jobs.SupervisorOLD do
  use Supervisor

  @default_name __MODULE__

  @doc """
  `opts` can receive options for the supervisor itself: `name`, and options for
  the job runner it starts: `:runner_name`, `:max_workers`.
  The supervisor name is always provided to the job runner, as the
  `:supervisor_name` option.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, @default_name)

    # the init callback receives options for the job runner:
    runner_opts =
      opts
      |> Keyword.delete(:name)
      |> Keyword.put(:supervisor_name, name)

    runner_opts =
      if runner_name = Keyword.get(opts, :runner_name) do
        runner_opts
        |> Keyword.delete(:runner_name)
        |> Keyword.put(:name, runner_name)
      else
        runner_opts
      end

    Supervisor.start_link(__MODULE__, runner_opts, name: name)
  end

  @impl true
  def init(runner_opts) do
    children = [
      {Photor.Jobs.JobsRunner, runner_opts}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
