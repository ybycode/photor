defmodule Photor.Photos.ThumbnailsTest do
  use Photor.DataCase
  alias Photor.Photos.Thumbnails
  import Mox
  import Photor.TestHelpers

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  describe "create_thumbnail/2" do
    test "creates a thumbnail from a source image" do
      # Setup
      source_path = "test/assets/test_image.jpg"
      output_dir = System.tmp_dir!()
      output_path = Path.join(output_dir, "test_image_thumbnail.jpg")

      # Ensure output file doesn't exist before test
      File.rm(output_path)

      # Register cleanup
      on_exit(fn -> File.rm(output_path) end)

      # Execute
      assert {:ok, ^output_path} = Thumbnails.create_thumbnail(source_path, output_path)

      # Verify
      assert File.exists?(output_path)

      # Check that the thumbnail was actually created and is smaller than the original
      {:ok, %{size: original_size}} = File.stat(source_path)
      {:ok, %{size: thumbnail_size}} = File.stat(output_path)
      assert thumbnail_size < original_size

      # Test with custom options
      custom_output_path = Path.join(output_dir, "test_image_custom_thumbnail.jpg")
      on_exit(fn -> File.rm(custom_output_path) end)

      assert {:ok, ^custom_output_path} =
               Thumbnails.create_thumbnail(
                 source_path,
                 custom_output_path,
                 max_width: 400,
                 max_height: 300,
                 quality: 70
               )

      assert File.exists?(custom_output_path)
    end

    test "process mailbox should be empty after an error" do
      # Setup
      source_path = "test/assets/test_image.jpg"
      output_path = Path.join(System.tmp_dir!(), "test_image_thumbnail.jpg")

      # Mock the implementation module
      override_test_config(:photor, Photor.Photos.Thumbnails, impl: Photor.Photos.ThumbnailMock)

      # Mock the thumbnail_cmd function to return a command that will fail
      expect(Photor.Photos.ThumbnailMock, :thumbnail_cmd, fn _, _, _, _, _ ->
        # Command that will always exit with status 1 (error)
        "false"
      end)

      # Execute with the mock
      result = Thumbnails.create_thumbnail(source_path, output_path)

      # Verify the function returns an error
      assert {:error, reason} = result
      assert reason == "Calls to create a thumbnail failed with exit status 1"

      # Verify the process mailbox is empty (no unhandled EXIT messages)
      refute_receive _, 100
    end

    test "returns error when command fails due to missing executable" do
      # Setup
      source_path = "test/assets/test_image.jpg"
      output_path = Path.join(System.tmp_dir!(), "test_image_thumbnail.jpg")

      # Ensure the file doesn't exist before and after the test
      File.rm(output_path)
      on_exit(fn -> File.rm(output_path) end)

      # Mock the implementation module
      override_test_config(:photor, Photor.Photos.Thumbnails, impl: Photor.Photos.ThumbnailMock)

      # Mock the thumbnail_cmd function to return a command with non-existent executable
      expect(Photor.Photos.ThumbnailMock, :thumbnail_cmd, fn _, _, _, _, _ ->
        "non_existent_command_123 -input #{source_path} -output #{output_path}"
      end)

      # Execute with the mock
      result = Thumbnails.create_thumbnail(source_path, output_path)

      # Verify
      assert {:error, reason} = result
      assert reason =~ "127"
      assert reason =~ "non_existent_command_123: command not found"
      refute File.exists?(output_path)
    end
  end
end
