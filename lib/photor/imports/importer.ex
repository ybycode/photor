defmodule Photor.Imports.Importer do
  @moduledoc """
  Handles importing files into the Photor repository with proper organization.
  """

  require Logger

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

  - import: The Import struct representing this import
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

    # Notify that an import has started
    emit(event_fn, %Events.NewImport{
      import_id: import.id,
      started_at: import.started_at,
      source_dir: source_dir
    })

    with {:ok, files} <- Scanner.scan_directory(source_dir, recursive: recursive, types: types) do
      emit(event_fn, %Events.FilesFound{
        import_id: import.id,
        files: files
      })

      emit(event_fn, %Events.ScanStarted{
        import_id: import.id
      })

      find_new_files(files, import.id, event_fn)
      |> tap(fn _new_files ->
        emit(event_fn, %Events.ImportStarted{
          import_id: import.id
        })
      end)
      |> Enum.each(fn {path, partial_hash, size} ->
        import_file(import, repo_base_dir, path, partial_hash, size, event_fn)
      end)

      emit(event_fn, %Events.ImportFinished{
        import_id: import.id
      })

      :ok
    else
      # TODO: emit an error event?
      error -> error
    end
  end

  defp find_new_files(files, import_id, event_fn) do
    partial_hash_nb_bytes =
      Application.fetch_env!(:photor, :partial_hash_nb_bytes)
      |> String.to_integer()

    Enum.reduce(files, %{}, fn %{path: path}, acc ->
      case file_check(path, partial_hash_nb_bytes) do
        {:new, {_path, partial_hash, _size} = file_info} ->
          # TODO: test this if/else branching here
          # This fixes a bug where 2 duplicated files (same partial hash) are
          # in the import directory. Since all partial hash checks were
          # performed against values in the DB, and new imports are only
          # inserted after all file checks, duplicated files in the import dir
          # were considered new and all imported (instead of importing one and
          # ignoring the others).
          if duplicate_of = Map.get(acc, partial_hash) do
            emit(event_fn, %Events.DuplicateFileInSourceIgnored{
              import_id: import_id,
              path: path,
              path_same_partial_hash: duplicate_of
            })

            acc
          else
            emit(event_fn, %Events.FileNotYetInRepoFound{
              import_id: import_id,
              path: path
            })

            [file_info | acc]
            Map.put(acc, partial_hash, file_info)
          end

        :already_in_database ->
          emit(event_fn, %Events.FileAlreadyInRepoFound{
            import_id: import_id,
            path: path
          })

          acc

          # TODO. Ignored case for now, the app will crash if something happens.
          #       To fix: do something with reason, emit another type of event, ...
          # {:error, _reason} ->
          #   emit(event_fn, %Events.FileAlreadyInRepoFound{
          #     import_id: import_id,
          #     path: path
          #   })

          #   acc
      end
    end)
    |> Map.values()
  end

  defp file_check(path, nb_bytes) do
    with {:ok, file_stat} <- File.stat(path),
         true <- can_read_file(file_stat),
         {:ok, partial_hash} <- Hasher.hash_file_first_bytes(path, nb_bytes) do
      if PhotoOperations.photo_exists_by_partial_hash?(partial_hash) do
        :already_in_database
      else
        {:new, {path, partial_hash, file_stat.size}}
      end
    else
      # TODO: what about the case where can_read_file/1 is false?

      # just return well formed errors as is:
      {:error, _reason} = e ->
        e
    end
  end

  defp can_read_file(%File.Stat{access: access}) when access in [:read, :read_write], do: true
  defp can_read_file(%File.Stat{}), do: false

  defp import_file(import, repo_base_dir, path, partial_hash, size, event_fn) do
    # Continue with import since it's a new file
    emit(event_fn, %Events.FileImporting{
      import_id: import.id,
      path: path
    })

    with {:ok, metadata} <- Metadata.read(path) do
      destination_dir = get_destination_dir(repo_base_dir, metadata)
      new_filename = generate_filename(path, partial_hash)
      destination_path = Path.join(destination_dir, new_filename)

      with :ok <- ensure_directory(destination_dir),
           :ok <- copy_file(path, destination_path),
           # Handle database insertion result properly
           {:ok, _photo} <-
             PhotoOperations.insert_from_metadata(
               import,
               metadata,
               new_filename,
               Path.basename(destination_dir),
               partial_hash,
               size
             ) do
        emit(event_fn, %Events.FileImported{
          import_id: import.id,
          path: path
        })

        {:ok, destination_path}
      else
        # Handle database insertion errors
        {:error, changeset} when is_struct(changeset, Ecto.Changeset) ->
          # Clean up the copied file since the database insertion failed
          _ = File.rm(destination_path)

          emit(event_fn, %Events.FileImportError{
            import_id: import.id,
            path: path,
            reason: "Database insertion failed: #{inspect(changeset.errors)}"
          })

          {:error, "Database insertion failed: #{inspect(changeset.errors)}"}

        # Handle other errors from previous steps
        {:error, reason} ->
          emit(event_fn, %Events.FileImportError{
            import_id: import.id,
            path: path,
            reason: reason
          })

          {:error, reason}
      end
    else
      {:error, reason} ->
        emit(event_fn, %Events.FileImportError{
          import_id: import.id,
          path: path,
          reason: "Failed to read the file's metadata: #{inspect(reason)}"
        })
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

  defp copy_file(source, destination, opts \\ []) do
    copy_strategy = Keyword.get(opts, :copy_strategy, :copy)
    overwrite = Keyword.get(opts, :overwrite, false)

    if File.exists?(destination) and not overwrite do
      {:error, "Destination file already exists"}
    else
      # Use a temporary filename during copy
      temp_destination = "#{destination}.tmp"

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
      |> case do
        :ok ->
          # If copy was successful, rename to final filename
          :ok = File.rename(temp_destination, destination)

        {:error, :eacces} ->
          Logger.error("Failed to copy #{source} to #{destination}: EACCES (permission denied)")
          {:error, :eacces}

        {:error, reason} ->
          Logger.error("Failed to copy #{source} to #{destination}: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end
end
