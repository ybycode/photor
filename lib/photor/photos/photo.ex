defmodule Photor.Photos.Photo do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Photor.Metadata.MainMetadata

  schema "photos" do
    field :filename, :string
    field :directory, :string

    field :file_size_bytes, :integer
    field :partial_sha256_hash, :string
    field :full_sha256_hash, :string

    field :image_height, :integer
    field :image_width, :integer
    field :mime_type, :string
    field :iso, :integer
    field :aperture, :float
    field :shutter_speed, :string
    field :focal_length, :string
    field :make, :string
    field :model, :string
    field :lens_info, :string
    field :lens_make, :string
    field :lens_model, :string
    field :create_date, :naive_datetime
    field :create_day, :date

    belongs_to :import, Photor.Imports.Import

    timestamps(updated_at: false)
  end

  @doc """
  Creates a changeset for a photo.
  """
  def changeset(photo, attrs) do
    photo
    |> cast(attrs, [
      :import_id,
      :filename,
      :directory,
      :partial_sha256_hash,
      :full_sha256_hash,
      :file_size_bytes,
      :image_height,
      :image_width,
      :mime_type,
      :iso,
      :aperture,
      :shutter_speed,
      :focal_length,
      :make,
      :model,
      :lens_info,
      :lens_make,
      :lens_model,
      :create_date,
      :create_day
    ])
    |> validate_required([
      :filename,
      :directory,
      :partial_sha256_hash,
      :file_size_bytes
    ])
    |> assoc_constraint(:import)
  end

  @doc """
  Creates a Photo struct from a MainMetadata struct and additional file information.

  ## Parameters

  - metadata: A MainMetadata struct containing the photo's metadata
  - filename: The filename of the photo
  - directory: The directory where the photo will be stored
  - partial_hash: The partial SHA256 hash of the photo
  - file_size: The size of the photo in bytes

  ## Returns

  A Photo struct with fields populated from the metadata and file information.
  """
  def from_metadata(
        import_id,
        %MainMetadata{} = metadata,
        filename,
        directory,
        partial_hash,
        file_size
      ) do
    create_day =
      if metadata.create_date, do: NaiveDateTime.to_date(metadata.create_date), else: nil

    %__MODULE__{
      import_id: import_id,
      filename: filename,
      directory: directory,
      partial_sha256_hash: partial_hash,
      # full_sha256_hash: full_hash,
      file_size_bytes: file_size,
      image_height: metadata.image_height,
      image_width: metadata.image_width,
      mime_type: metadata.mime_type,
      iso: metadata.iso,
      aperture: metadata.aperture,
      shutter_speed: metadata.shutter_speed,
      focal_length: metadata.focal_length,
      make: metadata.make,
      model: metadata.model,
      lens_info: metadata.lens_info,
      lens_make: metadata.lens_make,
      lens_model: metadata.lens_model,
      create_date: metadata.create_date,
      create_day: create_day
    }
  end

  def query_unique_create_day() do
    from(p in __MODULE__,
      select: p.create_day,
      distinct: true,
      order_by: [desc: p.create_day]
    )
  end

  def query_last_day() do
    from(p in __MODULE__,
      select: p.create_day,
      order_by: [desc: p.create_day],
      limit: 1
    )
  end

  def query_of_day(day) do
    from(p in __MODULE__,
      where: p.create_day == ^day
    )
  end
end
