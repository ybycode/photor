defmodule Photor.Photos.PhotoOperationsTest do
  use Photor.DataCase

  alias Photor.Photos.Photo
  alias Photor.Photos.PhotoOperations
  alias Photor.Metadata.MainMetadata

  import Photor.Factory

  describe "insert_from_metadata/6" do
    test "creates and inserts a photo from metadata" do
      metadata = %MainMetadata{
        create_date: ~N[2023-01-01 12:00:00],
        image_height: 1080,
        image_width: 1920,
        mime_type: "image/jpeg",
        iso: 100,
        aperture: 2.8,
        shutter_speed: "1/125",
        focal_length: "50.0 mm",
        make: "Canon",
        model: "EOS R5",
        lens_info: "24-70mm",
        lens_make: "Canon",
        lens_model: "RF 24-70mm F2.8L IS USM"
      }

      filename = "photo.jpg"
      directory = "2023-01-01"
      partial_hash = "partial123"
      file_size = 2048

      import = insert(:import)

      assert {:ok, photo} =
               PhotoOperations.insert_from_metadata(
                 import,
                 metadata,
                 filename,
                 directory,
                 partial_hash,
                 file_size
               )

      assert photo.filename == filename
      assert photo.directory == directory
      assert photo.partial_sha256_hash == partial_hash
      assert photo.file_size_bytes == file_size
      assert photo.image_height == metadata.image_height
      assert photo.image_width == metadata.image_width
      assert photo.mime_type == metadata.mime_type
      assert photo.iso == metadata.iso
      assert photo.aperture == metadata.aperture
      assert photo.shutter_speed == metadata.shutter_speed
      assert photo.focal_length == metadata.focal_length
      assert photo.make == metadata.make
      assert photo.model == metadata.model
      assert photo.lens_info == metadata.lens_info
      assert photo.lens_make == metadata.lens_make
      assert photo.lens_model == metadata.lens_model
      assert photo.create_date == metadata.create_date
    end

    test "returns error for invalid data" do
      metadata = %MainMetadata{
        create_date: ~N[2023-01-01 12:00:00]
      }

      filename = "photo.jpg"
      # Missing directory
      directory = nil
      partial_hash = "partial123"
      file_size = 2048

      import = insert(:import)

      assert {:error, changeset} =
               PhotoOperations.insert_from_metadata(
                 import,
                 metadata,
                 filename,
                 directory,
                 partial_hash,
                 file_size
               )

      assert %{directory: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "photo_exists_by_partial_hash?/1" do
    test "returns true when photo exists" do
      # Insert a photo directly for testing
      %Photo{
        filename: "test.jpg",
        directory: "2023-01-01",
        partial_sha256_hash: "unique123",
        file_size_bytes: 1024,
        create_date: ~N[2023-01-01 12:00:00]
      }
      |> Repo.insert!()

      assert PhotoOperations.photo_exists_by_partial_hash?("unique123")
      refute PhotoOperations.photo_exists_by_partial_hash?("nonexistent")
    end
  end
end
