defmodule Photor.Metadata.Exiftool do
  @default_exiftool_binary "exiftool"

  require Logger

  def read_as_json(photo_path) do
    exiftool_binary()
    |> call_binary(photo_path)
    |> and_then(&parse_json/1)
  end

  def call_binary(exiftool_binary, photo_path) when is_binary(photo_path) do
    try do
      System.cmd(exiftool_binary, ["-json", "-d", "%Y-%m-%d %H:%M:%S", photo_path],
        stderr_to_stdout: true
      )
    catch
      :error, :enoent ->
        raise(
          "Error reading a file's metadata: the \"#{exiftool_binary}\" " <>
            "executable is not available."
        )
    else
      {response, 0} ->
        {:ok, response}

      {response, exit_code} when is_binary(response) ->
        Logger.error(
          "Call to #{exiftool_binary} failed with exit code #{exit_code} and message \"#{response}\""
        )

        {:error, response}

      {_, _} ->
        raise("Command \"#{exiftool_binary}\" failed")
    end
  end

  defp exiftool_binary() do
    Application.get_env(:photor, __MODULE__, [])
    |> Keyword.get(:exiftool_binary, @default_exiftool_binary)
  end

  defp parse_json(response) when is_binary(response) do
    with {:ok, val} <- Jason.decode(response),
         [%{} = map] <- val do
      {:ok, map}
    end
  end

  defp and_then({:ok, previous_result}, fun), do: fun.(previous_result)
  defp and_then({:error, _reason} = e, _fun), do: e
end
