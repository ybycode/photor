defmodule Photor.Files.Importer do
  @moduledoc """
  Handles importing files into the Photor repository with proper organization.
  """

  alias Photor.Files.Scanner
  alias Photor.Hasher
  alias Photor.Metadata
  alias Photor.Photos.PhotoOperations

  @doc """
  Imports a file into the repository.

  ## Parameters

  - source_path: Path to the source file
  - repo_base_dir: Base directory of the repository
  - opts: Options for importing
    - :copy_strategy - :copy (default) or :move
    - :overwrite - whether to overwrite existing files (default: false)

  ## Returns

  - {:ok, destination_path} - If the file was successfully imported
  - {:error, reason} - If the import failed
  """
  def import_file(source_path, repo_base_dir, opts \\ []) do
    with {:ok, metadata} <- Metadata.read(source_path),
         {:ok, partial_hash} <- Hasher.hash_file_first_bytes(source_path, 1024),
         {:ok, file_stat} <- File.stat(source_path) do
      # Check if the file already exists in the database
      if PhotoOperations.photo_exists_by_partial_hash?(partial_hash) do
        {:ok, :already_exists}
      else
        # Continue with import since it's a new file
        destination_dir = get_destination_dir(metadata, repo_base_dir)
        new_filename = generate_filename(source_path, partial_hash)
        destination_path = Path.join(destination_dir, new_filename)

        with :ok <- ensure_directory(destination_dir),
             :ok <- copy_file(source_path, destination_path, opts),
             # Handle database insertion result properly
             {:ok, _photo} <-
               PhotoOperations.insert_from_metadata(
                 metadata,
                 new_filename,
                 Path.basename(destination_dir),
                 partial_hash,
                 file_stat.size
               ) do
          {:ok, destination_path}
        else
          # Handle database insertion errors
          {:error, changeset} when is_struct(changeset, Ecto.Changeset) ->
            # Clean up the copied file since the database insertion failed
            _ = File.rm(destination_path)
            {:error, "Database insertion failed: #{inspect(changeset.errors)}"}

          # Handle other errors from previous steps
          {:error, reason} ->
            {:error, reason}
        end
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Imports multiple files from a directory into the repository.

  ## Parameters

  - source_dir: Directory containing files to import
  - repo_base_dir: Base directory of the repository
  - opts: Options for importing
    - :recursive - whether to scan subdirectories (default: true)
    - :types - list of file types to import (default: all supported types)
    - :copy_strategy - :copy (default) or :move
    - :overwrite - whether to overwrite existing files (default: false)

  ## Returns

  - {:ok, results} - Where results is a list of {:ok, path} or {:error, reason} for each file
  - {:error, reason} - If the directory scan failed
  """
  def import_directory(source_dir, repo_base_dir, opts \\ []) do
    recursive = Keyword.get(opts, :recursive, true)
    types = Keyword.get(opts, :types, nil)

    with {:ok, files} <- Scanner.scan_directory(source_dir, recursive: recursive, types: types) do
      results =
        Enum.map(files, fn %{path: file_path} ->
          import_file(file_path, repo_base_dir, opts)
        end)

      {:ok, results}
    end
  end

  @doc """
  Determines the destination directory based on metadata.
  Falls back to current date if no creation date is found.
  """
  def get_destination_dir(metadata, repo_base_dir) do
    date_string = extract_date_string(metadata)
    Path.join(repo_base_dir, date_string)
  end

  @doc """
  Generates a new filename with the partial hash as prefix.
  """
  def generate_filename(original_path, partial_hash) do
    original_name = Path.basename(original_path)
    "#{partial_hash}_#{original_name}"
  end

  defp extract_date_string(metadata) do
    case metadata do
      %{create_date: %NaiveDateTime{} = date} ->
        Date.to_string(NaiveDateTime.to_date(date))

      %{create_date: date_string} when is_binary(date_string) ->
        date_string |> String.slice(0, 10)

      %{date_time_original: date_string} when is_binary(date_string) ->
        date_string |> String.slice(0, 10)

      _ ->
        "1970-01-01"
    end
  end

  defp ensure_directory(dir) do
    case File.mkdir_p(dir) do
      :ok -> :ok
      {:error, reason} -> {:error, "Failed to create directory: #{inspect(reason)}"}
    end
  end

  defp copy_file(source, destination, opts) do
    copy_strategy = Keyword.get(opts, :copy_strategy, :copy)
    overwrite = Keyword.get(opts, :overwrite, false)

    if File.exists?(destination) and not overwrite do
      {:error, "Destination file already exists"}
    else
      # Use a temporary filename during copy
      temp_destination = "#{destination}.tmp"

      result =
        case copy_strategy do
          :copy ->
            File.cp(source, temp_destination)

          :move ->
            # For move, we need to copy first then delete the original
            with :ok <- File.cp(source, temp_destination),
                 :ok <- File.rm(source) do
              :ok
            end
        end

      # If copy was successful, rename to final filename
      case result do
        :ok -> File.rename(temp_destination, destination)
        error -> error
      end
    end
  end
end
