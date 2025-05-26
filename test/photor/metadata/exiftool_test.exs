defmodule Photor.Metadata.ExiftoolTest do
  use ExUnit.Case
  import Photor.TestHelpers, only: [override_test_config: 3]

  alias Photor.Metadata.Exiftool

  # a jpg file that can be used to test the metadata reads:
  @ricoh_jpg "test/assets/Ricoh_GRIIIx.JPG"
  @non_existent_file "test/assets/non_existent_file.jpg"
  @bad_exiftool_script Path.expand("test/assets/bad_exiftool.sh")

  describe "exiftool" do
    test "read_as_json/1 returns metadata for a valid image file" do
      assert {:ok, metadata} = Exiftool.read_as_json(@ricoh_jpg)
      assert is_map(metadata)
      assert Map.has_key?(metadata, "FileName")
    end

    test "read_as_json/1 returns error for non-existent file" do
      assert {:error, :file_not_found} = Exiftool.read_as_json(@non_existent_file)
    end

    test "read_as_json/1 raises when exiftool binary can't be executed" do
      # Temporarily override the exiftool binary to a non-existent one
      override_test_config(:photor, Exiftool, exiftool_binary: "non_existent_binary")

      assert_raise RuntimeError, ~r/Failed to execute exiftool/, fn ->
        Exiftool.read_as_json(@ricoh_jpg)
      end
    end

    test "read_as_json/1 returns error for other failures" do
      # Mock a directory path instead of a file to cause a different kind of error
      dir_path = "test/assets"
      assert {:error, %Jason.DecodeError{}} = Exiftool.read_as_json(dir_path)
    end

    test "read_as_json/1 handles invalid JSON returned by exiftool" do
      override_test_config(:photor, Exiftool, exiftool_binary: @bad_exiftool_script)

      assert {:error, %Jason.DecodeError{}} = Exiftool.read_as_json(@ricoh_jpg)
    end
  end
end
