defmodule Photor.CLI do
  use ExCLI.DSL

  name "mycli"
  description "My CLI"
  long_description ~s"""
  This is my long description
  """

  option :verbose, count: true, aliases: [:v]

  command :hello do
    aliases [:hi]
    description "Greets the user"
    long_description """
    Gives a nice a warm greeting to whoever would listen
    """

    argument :name
    option :from, help: "the sender of hello"

    run context do
      if context.verbose > 0 do
        IO.puts("Running hello command")
      end
      if from = context[:from] do
        IO.write("#{from} says: ")
      end
      IO.puts("Hello #{context.name}!")
    end
  end
end

#   require Logger
#
#   def main(args) do
#
#     IO.puts("received, #{inspect args}")
#
#     {opts, args, invalid} = OptionParser.parse(
#       args,
#       switches: [verbose: :boolean, help: :boolean],
#       aliases: [v: :verbose, h: :help]
#     )
#
#     IO.puts("invalid: #{inspect invalid}")
#
#     if opts[:help] do
#       IO.puts("Usage: my_cli [--verbose] [--help]")
#     else
#       run(args, opts)
#     end
#   end
#
#   defp run(args, opts) do
#     IO.puts("Running with args: #{inspect(args)}, opts: #{inspect(opts)}")
#   end
# end
