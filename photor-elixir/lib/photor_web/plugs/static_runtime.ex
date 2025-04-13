defmodule PhotorWeb.Plug.StaticRuntime do
  @moduledoc """
  Like `PLug.Static` (and using its callbacks), but it allows to define the
  source of the static assets at runtime.
  """

  require Logger

  def init(opts) do
    # this callback is only called at compile time. The value for the `:from`
    # key being required, but only known at runtime, it is set here as an empty
    # string.
    opts
    |> Keyword.put(:from, "")
    |> Plug.Static.init()
  end

  def call(conn, opts_map) do
    photor_dir =
      Application.get_env(
        :photor,
        :photor_dir
      )

    runtime_opts =
      Map.put(
        opts_map,
        :from,
        photor_dir
      )

    Plug.Static.call(conn, runtime_opts)
  end
end
