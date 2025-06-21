defmodule Photor.Files.Scanner do
  require Logger

  alias Photor.Files.File, as: File_

  @moduledoc """
  Provides functionality to scan directories for photo and video files.
  """

  alias Photor.FileExtensions

  @doc """
  Recursively scans a directory and its subdirectories for photo and video files.

  ## Parameters
    - directory: The path to the directory to scan
    - opts: Options for scanning
      - :recursive - Whether to scan subdirectories (default: true)
      - :types - List of media types to include, e.g. [{:photo, :compressed}, {:photo, :raw}] (default: all types)

  ## Returns
    - {:ok, files} - A list of maps containing file information
    - {:error, reason} - An error occurred during scanning
  """
  def scan_directory(directory, opts \\ []) do
    recursive = Keyword.get(opts, :recursive, true)
    types = Keyword.get(opts, :types, nil)

    if File.dir?(directory) do
      files =
        do_scan_directory(directory, recursive, types)
        # files are sorted by path so that the output is cleaner, and it's
        # consistent for tests.
        |> Enum.sort_by(& &1.path)

      {:ok, files}
    else
      {:error, "Not a directory: #{directory}"}
    end
  end

  defp do_scan_directory(directory, recursive, types) do
    try do
      directory
      |> File.ls!()
      |> Enum.map(fn entry -> Path.join(directory, entry) end)
      |> Enum.flat_map(fn path ->
        case File.stat(path) do
          {:ok, %File.Stat{type: :directory}} when recursive ->
            do_scan_directory(path, recursive, types)

          {:ok, %File.Stat{type: :regular} = stat} ->
            case get_file_type(path, types) do
              nil ->
                []

              type ->
                [%File_{path: path, type: type, bytesize: stat.size, access: stat.access}]
            end

          _ ->
            []
        end
      end)
    rescue
      e in File.Error ->
        # Log the error but continue with an empty list
        Logger.error("Error scanning directory #{directory}: #{inspect(e)}")
        []
    end
  end

  defp get_file_type(path, allowed_types) do
    extension = Path.extname(path) |> String.trim_leading(".")

    case FileExtensions.extension_info(extension) do
      {medium, type} = file_type ->
        # If allowed_types is nil, accept all types
        # Otherwise, check if this type is in the allowed list
        if is_nil(allowed_types) or file_type in allowed_types do
          %{medium: medium, type: type, extension: extension}
        else
          nil
        end

      # If extension_info doesn't match, it returns a function
      _other ->
        nil
    end
  end
end
