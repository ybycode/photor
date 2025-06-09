defmodule Photor.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PhotorWeb.Telemetry,
      Photor.Repo,
      {Ecto.Migrator,
       repos: Application.fetch_env!(:photor, :ecto_repos), skip: skip_migrations?()},
      {DNSCluster, query: Application.get_env(:photor, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Photor.PubSub},
      # Start the Import Registry
      {Registry, keys: :unique, name: Photor.Imports.ImportRegistry},
      # Start the Import Supervisor
      {Photor.Imports.ImportSupervisor, []},
      # Start to serve requests, typically the last entry
      PhotorWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Photor.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PhotorWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations?() do
    # By default, sqlite migrations are run when using a release
    System.get_env("RELEASE_NAME") != nil
  end
end
