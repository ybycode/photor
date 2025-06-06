defmodule Photor.Photos.PhotoOperations do
  @moduledoc """
  Operations for managing photos in the database.
  """

  import Ecto.Query

  alias Photor.Imports.Import
  alias Photor.Metadata.MainMetadata
  alias Photor.Photos.Photo
  alias Photor.Repo

  @doc """
  Creates a Photo struct from metadata and file information and inserts it into the database.

  ## Parameters

  - metadata: A MainMetadata struct containing the photo's metadata
  - filename: The filename of the photo
  - directory: The directory where the photo will be stored
  - partial_hash: The partial SHA256 hash of the photo
  - file_size: The size of the photo in bytes

  ## Returns

  `{:ok, photo}` if the photo was inserted successfully.
  `{:error, changeset}` if there was an error.
  """
  def insert_from_metadata(
        %Import{id: import_id},
        %MainMetadata{} = metadata,
        filename,
        directory,
        partial_hash,
        file_size
      ) do
    photo = Photo.from_metadata(import_id, metadata, filename, directory, partial_hash, file_size)

    %Photo{}
    |> Photo.changeset(Map.from_struct(photo))
    |> Repo.insert()
  end

  @doc """
  Checks if a photo with the given partial hash already exists in the database.

  Returns `true` if a photo with the given partial hash exists, `false` otherwise.
  """
  def photo_exists_by_partial_hash?(partial_hash) when is_binary(partial_hash) do
    Repo.exists?(from p in Photo, where: p.partial_sha256_hash == ^partial_hash)
  end
end
