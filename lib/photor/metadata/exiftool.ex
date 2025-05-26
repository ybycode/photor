defmodule Photor.Metadata.Exiftool do
  @default_exiftool_binary "exiftool"

  require Logger
  @behaviour Photor.Metadata.ExiftoolBehaviour

  def read_as_json(photo_path) do
    exiftool_binary()
    |> call_binary(photo_path)
    |> and_then(&parse_json/1)
  end

  def call_binary(exiftool_binary, photo_path) when is_binary(photo_path) do
    if not File.exists?(photo_path) do
      {:error, :file_not_found}
    else
      args = ["-json", "-d", "%Y-%m-%d %H:%M:%S", photo_path]

      try do
        case System.cmd(exiftool_binary, args, stderr_to_stdout: true) do
          {output, 0} ->
            {:ok, output}

          {error, _} ->
            {:error, String.trim(error)}
        end
      rescue
        e in ErlangError ->
          case e do
            %ErlangError{original: :enoent} ->
              raise "Failed to execute exiftool: binary not found or not executable. Please make sure it's in PATH or is defined with an absolute filename."

            _ ->
              {:error, "Unexpected error: #{inspect(e)}"}
          end
      end
    end
  end

  defp exiftool_binary() do
    Application.get_env(:photor, __MODULE__, [])
    |> Keyword.get(:exiftool_binary, @default_exiftool_binary)
  end

  defp parse_json(response) when is_binary(response) do
    case Jason.decode(response) do
      {:ok, [%{} = map]} -> {:ok, map}
      {:ok, _} -> {:error, "Invalid JSON format"}
      {:error, error} -> {:error, error}
    end
  end

  defp and_then({:ok, previous_result}, fun) when is_function(fun, 1), do: fun.(previous_result)
  defp and_then({:error, _reason} = e, _fun), do: e
end
