defmodule Photor.MetadataTest do
  use ExUnit.Case

  alias Photor.Metadata
  alias Photor.Metadata.MainMetadata

  @ricoh_raw "test/assets/Ricoh_GRIIIx.DNG"
  @ricoh_jpg "test/assets/Ricoh_GRIIIx.JPG"

  # TODO: replace with dummy photos
  @fujix_raw "test/assets/DSCF7066.RAF"
  @fujix_jpg "test/assets/DSCF7066.JPG"

  describe "read/1" do
    test "works with Ricoh GRIIIx images" do
      assert {:ok, exif} = Metadata.read(@ricoh_jpg)

      jpg_exif = %MainMetadata{
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

      assert exif == jpg_exif

      raw_exif = %{
        jpg_exif
        | mime_type: "image/x-adobe-dng",
          image_height: 4064,
          image_width: 6112
      }

      assert {:ok, %MainMetadata{} = exif} = Metadata.read(@ricoh_raw)
      assert exif == raw_exif
    end

    test "works with Fuji X images" do
      assert {:ok, exif} = Metadata.read(@fujix_jpg)

      jpg_exif = %MainMetadata{
        aperture: 6.4,
        create_date: "2025-04-20 13:19:24",
        date_time_original: "2025-04-20 13:19:24",
        focal_length: "75.0 mm",
        image_height: 5152,
        image_width: 7728,
        iso: 160,
        lens_info: "75mm f/1.2",
        lens_make: "Viltrox ",
        lens_model: "AF 75/1.2 XF   ",
        make: "FUJIFILM",
        mime_type: "image/jpeg",
        model: "X-T5",
        shutter_speed: "1/80"
      }

      assert exif == jpg_exif

      raw_exif = %{
        jpg_exif
        | mime_type: "image/x-fujifilm-raf",
          image_height: 2944,
          image_width: 4416
      }

      assert {:ok, %MainMetadata{} = exif} = Metadata.read(@fujix_raw)
      assert exif == raw_exif
    end
  end
end
