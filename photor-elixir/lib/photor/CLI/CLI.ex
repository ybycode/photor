defmodule Photor.CLI do
  require Logger

  def main(args) do
    IO.puts("received, #{inspect(args)}")

    {opts, args, _invalid} =
      OptionParser.parse(
        args,
        switches: [verbose: :boolean, help: :boolean],
        aliases: [v: :verbose, h: :help]
      )

    if opts[:help] do
      IO.puts("Usage: my_cli [--verbose] [--help]")
    else
      run(args, opts)
    end
  end

  defp run(args, opts) do
    IO.puts("Running with args: #{inspect(args)}, opts: #{inspect(opts)}")
  end
end
