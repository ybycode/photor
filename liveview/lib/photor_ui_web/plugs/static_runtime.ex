defmodule PhotorUiWeb.Plug.StaticRuntime do
  def init(opts) do
    runtime_opts =
      Keyword.put(
        opts,
        :from,
        Application.get_env(
          :photor_ui,
          :photor_dir
        )
      )
      |> IO.inspect()

    Plug.Static.init(runtime_opts)
  end

  def call(conn, opts) do
    Plug.Static.call(conn, opts)
  end
end
