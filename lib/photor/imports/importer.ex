defmodule Photor.Imports.Importer do
  @moduledoc """
  Handles importing files into the Photor repository with proper organization.
  """

  alias Photor.Files.Scanner
  alias Photor.Hasher
  alias Photor.Imports.Events
  alias Photor.Imports.Import
  alias Photor.Metadata
  alias Photor.Metadata.MainMetadata
  alias Photor.Photos.PhotoOperations

  # Helper function to emit events if an event_fn is provided.
  defp emit(nil, _event), do: :ok
  defp emit(event_fn, event), do: event_fn.(event)

  @doc """
  Imports multiple files from a directory into the repository.

  ## Parameters

  - source_dir: Directory containing files to import
  - opts: Options for importing
    - :recursive - whether to scan subdirectories (default: true)
    - :types - list of file types to import (default: all supported types)
    - :copy_strategy - :copy (default) or :move
    - :overwrite - whether to overwrite existing files (default: false)
  - event_fn: Optional function to emit events during the import process

  ## Returns

  - {:ok, results} - Where results is a list of {:ok, path} or {:error, reason} for each file
  - {:error, reason} - If the directory scan failed
  """
  def import_directory(%Import{} = import, source_dir, opts \\ [], event_fn \\ nil) do
    recursive = Keyword.get(opts, :recursive, true)
    types = Keyword.get(opts, :types, nil)
    repo_base_dir = Application.fetch_env!(:photor, :photor_dir)

    # Notify the tracker that an import has started
    emit(event_fn, %Events.ImportStarted{
      import_id: import.id,
      started_at: import.started_at,
      source_dir: source_dir
    })

    with {:ok, files} <- Scanner.scan_directory(source_dir, recursive: recursive, types: types) do
      emit(event_fn, %Events.FilesFound{
        files: files
      })

      results =
        Enum.map(files, fn %{path: path} ->
          import_file(import, repo_base_dir, path, opts, event_fn)
        end)

      # Count results for final summary
      total_files = length(results)

      skipped_count =
        Enum.count(results, fn
          {:ok, :already_exists} -> true
          _ -> false
        end)

      imported_count =
        Enum.count(results, fn
          {:ok, path} when is_binary(path) -> true
          _ -> false
        end)

      imported_bytes =
        Enum.reduce(results, 0, fn
          {:ok, path}, acc when is_binary(path) ->
            case File.stat(path) do
              {:ok, %{size: size}} -> acc + size
              _ -> acc
            end

          _, acc ->
            acc
        end)

      emit(event_fn, %Events.ImportFinished{
        import_id: import.id,
        total_files: total_files,
        skipped_count: skipped_count,
        imported_count: imported_count,
        imported_bytes: imported_bytes
      })

      {:ok, results}
    end
  end

  @doc """
  Imports a file into the repository.

  ## Parameters

  - source_path: Path to the source file
  - repo_base_dir: Base directory of the repository
  - opts: Options for importing
    - :copy_strategy - :copy (default) or :move
    - :overwrite - whether to overwrite existing files (default: false)
  - event_fn: Optional function to emit events during the import process

  ## Returns

  - {:ok, destination_path} - If the file was successfully imported
  - {:error, reason} - If the import failed
  """
  def import_file(%Import{} = import, repo_base_dir, source_path, opts \\ [], event_fn \\ nil) do
    with {:ok, metadata} <- Metadata.read(source_path),
         {:ok, partial_hash} <- Hasher.hash_file_first_bytes(source_path, 1024),
         {:ok, file_stat} <- File.stat(source_path) do
      # Check if the file already exists in the database
      if PhotoOperations.photo_exists_by_partial_hash?(partial_hash) do
        emit(event_fn, %Events.FileSkipped{path: source_path})
        {:ok, :already_exists}
      else
        # Continue with import since it's a new file
        emit(event_fn, %Events.FileImporting{path: source_path})
        destination_dir = get_destination_dir(repo_base_dir, metadata)
        new_filename = generate_filename(source_path, partial_hash)
        destination_path = Path.join(destination_dir, new_filename)

        with :ok <- ensure_directory(destination_dir),
             :ok <- copy_file(source_path, destination_path, opts),
             # Handle database insertion result properly
             {:ok, _photo} <-
               PhotoOperations.insert_from_metadata(
                 import,
                 metadata,
                 new_filename,
                 Path.basename(destination_dir),
                 partial_hash,
                 file_stat.size
               ) do
          emit(event_fn, %Events.FileImported{
            path: source_path
          })

          {:ok, destination_path}
        else
          # Handle database insertion errors
          {:error, changeset} when is_struct(changeset, Ecto.Changeset) ->
            # Clean up the copied file since the database insertion failed
            _ = File.rm(destination_path)

            emit(event_fn, %Events.ImportError{
              path: source_path,
              reason: "Database insertion failed: #{inspect(changeset.errors)}"
            })

            {:error, "Database insertion failed: #{inspect(changeset.errors)}"}

          # Handle other errors from previous steps
          {:error, reason} ->
            emit(event_fn, %Events.ImportError{
              path: source_path,
              reason: reason
            })

            {:error, reason}
        end
      end
    else
      {:error, reason} ->
        emit(event_fn, %Events.ImportError{
          path: source_path,
          reason: reason
        })

        {:error, reason}
    end
  end

  defp get_destination_dir(repo_base_dir, metadata) do
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

  defp extract_date_string(%MainMetadata{create_date: date}) do
    date
    |> Date.to_string()
    |> String.slice(0, 10)
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
