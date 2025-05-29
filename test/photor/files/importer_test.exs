defmodule Photor.Files.ImporterTest do
  use Photor.DataCase
  import Mox

  alias Photor.Files.Importer
  alias Photor.Metadata.MockExiftool
  alias Photor.Photos.Photo
  alias Photor.Repo

  setup :verify_on_exit!

  @temp_dir "tmp/test_repo"
  @source_dir "tmp/test_source"

  setup do
    # Create temp directories for tests
    File.mkdir_p!(@temp_dir)
    File.mkdir_p!(@source_dir)

    on_exit(fn ->
      File.rm_rf!(@temp_dir)
      File.rm_rf!(@source_dir)
    end)

    :ok
  end

  describe "get_destination_dir/2" do
    alias Photor.Metadata.MainMetadata

    test "uses create_date when available" do
      metadata = %MainMetadata{
        create_date: ~N[2023-05-15 10:30:00]
      }

      dest_dir = Importer.get_destination_dir(metadata, @temp_dir)
      assert Path.basename(dest_dir) == "2023-05-15"
    end

    test "falls back to epoch date when no date available" do
      metadata = %MainMetadata{}
      dest_dir = Importer.get_destination_dir(metadata, @temp_dir)
      assert Path.basename(dest_dir) == "1970-01-01"
    end
  end

  describe "generate_filename/2" do
    test "prefixes original filename with hash" do
      original_path = "path/to/IMG_1234.JPG"
      hash = "abcdef1234567890"

      new_name = Importer.generate_filename(original_path, hash)
      assert new_name == "abcdef1234567890_IMG_1234.JPG"
    end
  end

  describe "import_file/3" do
    test "successfully imports a new file" do
      # Create a test file
      test_file = Path.join(@source_dir, "test_photo.jpg")
      File.write!(test_file, "test file content")

      # Mock the metadata read
      MockExiftool
      |> expect(:read_as_json, fn _path ->
        {:ok,
         %{
           "CreateDate" => "2023-06-15 10:30:00",
           "MIMEType" => "image/jpeg",
           "ImageHeight" => 1080,
           "ImageWidth" => 1920
         }}
      end)

      # Run the import
      result = Importer.import_file(test_file, @temp_dir)

      # Verify results
      assert {:ok, destination_path} = result
      assert File.exists?(destination_path)
      assert String.contains?(destination_path, "2023-06-15")

      # Verify the file was copied with the correct name format
      assert Path.basename(destination_path) =~ ~r/^[a-f0-9]+_test_photo\.jpg$/

      # Verify a database record was created
      photo = Repo.get_by(Photo, filename: Path.basename(destination_path))
      assert photo != nil
      assert photo.directory == "2023-06-15"
    end

    test "returns :already_exists when file already in database" do
      # Create a test file
      test_file = Path.join(@source_dir, "existing_photo.jpg")
      File.write!(test_file, "test file content")

      # First import the file to create the database record
      MockExiftool
      |> expect(:read_as_json, fn _path ->
        {:ok,
         %{
           "CreateDate" => "2023-06-15 10:30:00",
           "MIMEType" => "image/jpeg"
         }}
      end)

      {:ok, _} = Importer.import_file(test_file, @temp_dir)

      # Now try to import it again - should detect as already existing
      MockExiftool
      |> expect(:read_as_json, fn _path ->
        {:ok,
         %{
           "CreateDate" => "2023-06-15 10:30:00",
           "MIMEType" => "image/jpeg"
         }}
      end)

      result = Importer.import_file(test_file, @temp_dir)
      assert {:ok, :already_exists} = result
    end

    test "handles metadata read errors" do
      # Create a test file
      test_file = Path.join(@source_dir, "error_photo.jpg")
      File.write!(test_file, "test file content")

      # Mock the metadata read to fail
      MockExiftool
      |> expect(:read_as_json, fn _path ->
        {:error, "Metadata extraction failed"}
      end)

      # Run the import
      result = Importer.import_file(test_file, @temp_dir)

      # Verify it returns an error
      assert {:error, _} = result
    end
  end

  describe "import_directory/3" do
    test "imports multiple files from a directory" do
      # Create test files
      file1 = Path.join(@source_dir, "photo1.jpg")
      file2 = Path.join(@source_dir, "photo2.jpg")
      File.write!(file1, "test content 1")
      File.write!(file2, "test content 2")

      # Create a subdirectory with a file
      subdir = Path.join(@source_dir, "subdir")
      File.mkdir_p!(subdir)
      file3 = Path.join(subdir, "photo3.jpg")
      File.write!(file3, "test content 3")

      # Mock the metadata read for each file
      MockExiftool
      |> expect(:read_as_json, 3, fn path ->
        filename = Path.basename(path)

        {:ok,
         %{
           "FileName" => filename,
           "CreateDate" => "2023-06-15 10:30:00",
           "MIMEType" => "image/jpeg"
         }}
      end)

      # Run the directory import
      result = Importer.import_directory(@source_dir, @temp_dir)

      # Verify results
      assert {:ok, results} = result
      assert length(results) == 3

      # Check that all imports were successful
      assert Enum.all?(results, fn r -> match?({:ok, _}, r) end)

      # Check that files were copied to the repository
      assert File.exists?(Path.join([@temp_dir, "2023-06-15"]))

      # Check that database records were created
      photo_count = Repo.aggregate(Photo, :count)
      assert photo_count == 3
    end

    test "handles directory not found error" do
      # Try to import from a non-existent directory
      result = Importer.import_directory("/nonexistent/dir", @temp_dir)

      # Verify it returns an error
      assert {:error, _} = result
    end

    test "skips already imported files" do
      # Create test files
      file1 = Path.join(@source_dir, "photo1.jpg")
      file2 = Path.join(@source_dir, "photo2.jpg")
      File.write!(file1, "test content 1")
      File.write!(file2, "test content 2")

      # First import to create records
      MockExiftool
      |> expect(:read_as_json, 2, fn path ->
        filename = Path.basename(path)

        {:ok,
         %{
           "FileName" => filename,
           "CreateDate" => "2023-06-15 10:30:00",
           "MIMEType" => "image/jpeg"
         }}
      end)

      {:ok, _} = Importer.import_directory(@source_dir, @temp_dir)

      # Add a new file
      file3 = Path.join(@source_dir, "photo3.jpg")
      File.write!(file3, "test content 3")

      # Import again - should only import the new file
      MockExiftool
      |> expect(:read_as_json, 3, fn path ->
        filename = Path.basename(path)

        {:ok,
         %{
           "FileName" => filename,
           "CreateDate" => "2023-06-15 10:30:00",
           "MIMEType" => "image/jpeg"
         }}
      end)

      {:ok, results} = Importer.import_directory(@source_dir, @temp_dir)

      # Two should be already_exists, one should be a new import
      already_exists = Enum.count(results, fn r -> r == {:ok, :already_exists} end)

      new_imports =
        Enum.count(results, fn
          {:ok, :already_exists} -> false
          {:ok, path} when is_binary(path) -> true
        end)

      assert already_exists == 2
      assert new_imports == 1

      # Check that we now have 3 photos in the database
      photo_count = Repo.aggregate(Photo, :count)
      assert photo_count == 3
    end
  end
end
