defmodule Photor.MetadataTest do
  use ExUnit.Case
  import Mox
  import Photor.MetadataHelpers

  # Set up mocks to be verified when the test exits
  setup :verify_on_exit!

  alias Photor.Metadata
  alias Photor.Metadata.MainMetadata
  alias Photor.Metadata.MockExiftool

  describe "read/1" do
    test "works with Ricoh GRIIIx JPG" do
      {:ok, json_data} = load_metadata_json("Ricoh_GRIIIxHDF_jpg.json")

      # Mock the Exiftool response for Ricoh JPG
      MockExiftool
      |> expect(:read_as_json, fn _path ->
        {:ok, json_data}
      end)

      assert {:ok, exif} = Metadata.read("dummy_ricoh.jpg")

      expected_exif = %MainMetadata{
        aperture: 2.8,
        create_date: "2025-05-02 20:29:52",
        date_time_original: "2025-05-02 20:29:52",
        focal_length: "26.0 mm",
        image_height: 1280,
        image_width: 1920,
        iso: 2500,
        lens_info: "26.1mm F2.8",
        lens_make: nil,
        lens_model: nil,
        make: "RICOH IMAGING COMPANY, LTD.",
        mime_type: "image/jpeg",
        model: "RICOH GR IIIx HDF",
        shutter_speed: "1/60"
      }

      assert exif == expected_exif
    end

    test "works with Ricoh GRIIIx RAW" do
      {:ok, json_data} = load_metadata_json("Ricoh_GRIIIxHDF_dng.json")

      # Mock the Exiftool response for Ricoh RAW
      MockExiftool
      |> expect(:read_as_json, fn _path ->
        {:ok, json_data}
      end)

      assert {:ok, exif} = Metadata.read("dummy_ricoh.dng")

      expected_exif = %MainMetadata{
        aperture: 2.8,
        create_date: "2025-05-02 20:29:52",
        date_time_original: "2025-05-02 20:29:52",
        focal_length: "26.0 mm",
        image_height: 4064,
        image_width: 6112,
        iso: 2500,
        lens_info: "26.1mm F2.8",
        lens_make: nil,
        lens_model: nil,
        make: "RICOH IMAGING COMPANY, LTD.",
        mime_type: "image/x-adobe-dng",
        model: "RICOH GR IIIx HDF",
        shutter_speed: "1/60"
      }

      assert exif == expected_exif
    end

    test "handles file not found errors" do
      MockExiftool
      |> expect(:read_as_json, fn _path ->
        {:error, :file_not_found}
      end)

      assert {:error, "File not found: non_existent.jpg"} = Metadata.read("non_existent.jpg")
    end

    test "handles exiftool errors" do
      MockExiftool
      |> expect(:read_as_json, fn _path ->
        {:error, "Some exiftool error"}
      end)

      assert {:error, "Failed to read metadata: \"Some exiftool error\""} =
               Metadata.read("dummy.jpg")
    end

    test "handles shutter speed decoding errors" do
      # Create a custom JSON with invalid shutter speed
      invalid_json = %{
        "ShutterSpeed" => %{"invalid" => "format"},
        "MIMEType" => "image/jpeg"
      }

      MockExiftool
      |> expect(:read_as_json, fn _path ->
        {:ok, invalid_json}
      end)

      assert {:error,
              "Failed to process shutter speed: Expected a string or a number for shutter speed"} =
               Metadata.read("dummy.jpg")
    end
  end
end
