defmodule Photor.Imports.ImporterTest do
  use Photor.DataCase
  import Mox

  alias Photor.Imports.Importer
  alias Photor.Imports.Events
  # alias Photor.Metadata.MainMetadata
  alias Photor.Metadata.MockExiftool
  alias Photor.Photos.Photo
  alias Photor.Repo

  import Photor.Factory

  setup :verify_on_exit!

  @photor_dir Application.compile_env!(:photor, :photor_dir)
  @source_dir "test/tmp/"

  setup do
    # Create temp directories for tests
    File.mkdir_p!(@source_dir)

    on_exit(fn ->
      File.rm_rf!(@source_dir)

      [
        "1970-01-01",
        "2023-06-15"
      ]
      |> Enum.each(fn date ->
        Path.join(@photor_dir, date)
        |> File.rm_rf!()
      end)
    end)

    :ok
  end

  describe "generate_filename/2" do
    test "prefixes original filename with hash" do
      original_path = "path/to/IMG_1234.JPG"
      hash = "abcdef1234567890"

      new_name = Importer.generate_filename(original_path, hash)
      assert new_name == "abcdef1234567890_IMG_1234.JPG"
    end
  end

  # describe "import_file/3" do
  #   test "successfully imports a new file" do
  #     # Create a test file
  #     test_file = Path.join(@source_dir, "test_photo.jpg")
  #     File.write!(test_file, "test file content")

  #     # Mock the metadata read
  #     MockExiftool
  #     |> expect(:read_as_json, fn _path ->
  #       {:ok,
  #        %{
  #          "CreateDate" => "2023-06-15 10:30:00",
  #          "MIMEType" => "image/jpeg",
  #          "ImageHeight" => 1080,
  #          "ImageWidth" => 1920
  #        }}
  #     end)

  #     # Run the import
  #     import = insert(:import)
  #     result = Importer.import_file(import, @photor_dir, test_file)

  #     # Verify results
  #     assert {:ok, destination_path} = result
  #     assert File.exists?(destination_path)
  #     assert String.contains?(destination_path, "2023-06-15")

  #     # Verify the file was copied with the correct name format
  #     assert Path.basename(destination_path) =~ ~r/^[a-z0-9]+_test_photo\.jpg$/

  #     # Verify a database record was created
  #     photo = Repo.get_by(Photo, filename: Path.basename(destination_path))
  #     assert photo != nil
  #     assert photo.directory == "2023-06-15"
  #   end

  #   test "uses 1970-01-01 if not date found in the file" do
  #     # Create a test file
  #     test_file = Path.join(@source_dir, "test_photo.jpg")
  #     File.write!(test_file, "test file content")

  #     # Mock the metadata read
  #     MockExiftool
  #     |> expect(:read_as_json, fn _path ->
  #       {:ok,
  #        %{
  #          # "CreateDate" => "2023-06-15 10:30:00", # no date in metadata
  #          "MIMEType" => "image/jpeg",
  #          "ImageHeight" => 1080,
  #          "ImageWidth" => 1920
  #        }}
  #     end)

  #     # Run the import
  #     import = insert(:import)
  #     result = Importer.import_file(import, @photor_dir, test_file)

  #     # Verify results
  #     assert {:ok, destination_path} = result
  #     assert File.exists?(destination_path)
  #     assert String.contains?(destination_path, "1970-01-01")

  #     # Verify the file was copied with the correct name format
  #     assert Path.basename(destination_path) =~ ~r/^[a-z0-9]+_test_photo\.jpg$/

  #     # Verify a database record was created
  #     photo = Repo.get_by(Photo, filename: Path.basename(destination_path))
  #     assert photo != nil
  #     assert photo.directory == "1970-01-01"
  #   end

  #   test "returns :already_exists when file already in database" do
  #     # Create a test file
  #     test_file = Path.join(@source_dir, "existing_photo.jpg")
  #     File.write!(test_file, "test file content")

  #     # First import the file to create the database record
  #     MockExiftool
  #     |> expect(:read_as_json, fn _path ->
  #       {:ok,
  #        %{
  #          "CreateDate" => "2023-06-15 10:30:00",
  #          "MIMEType" => "image/jpeg"
  #        }}
  #     end)

  #     import = insert(:import)
  #     {:ok, _} = Importer.import_file(import, @photor_dir, test_file)

  #     # Now try to import it again - should detect as already existing
  #     MockExiftool
  #     |> expect(:read_as_json, fn _path ->
  #       {:ok,
  #        %{
  #          "CreateDate" => "2023-06-15 10:30:00",
  #          "MIMEType" => "image/jpeg"
  #        }}
  #     end)

  #     import = insert(:import)
  #     result = Importer.import_file(import, @photor_dir, test_file)
  #     assert {:ok, :already_exists} = result
  #   end

  #   test "handles metadata read errors" do
  #     # Create a test file
  #     test_file = Path.join(@source_dir, "error_photo.jpg")
  #     File.write!(test_file, "test file content")

  #     # Mock the metadata read to fail
  #     MockExiftool
  #     |> expect(:read_as_json, fn _path ->
  #       {:error, "Metadata extraction failed"}
  #     end)

  #     # Run the import
  #     import = insert(:import)
  #     result = Importer.import_file(import, @photor_dir, test_file)

  #     # Verify it returns an error
  #     assert {:error, _} = result
  #   end
  # end

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
      import = insert(:import)

      test_pid = self()

      assert :ok =
               Importer.import_directory(import, @source_dir, [], fn event ->
                 send(test_pid, event)
               end)

      # Now we should have received events:
      assert_received e

      assert e == %Events.NewImport{
               import_id: import.id,
               source_dir: @source_dir,
               started_at: import.started_at
             }

      assert_received e

      assert e == %Events.FilesFound{
               import_id: import.id,
               files: [
                 %Photor.Files.File{
                   path: "test/tmp/subdir/photo3.jpg",
                   type: %{type: :compressed, extension: "jpg", medium: :photo},
                   bytesize: 14,
                   access: :read_write
                 },
                 %Photor.Files.File{
                   path: "test/tmp/photo2.jpg",
                   type: %{type: :compressed, extension: "jpg", medium: :photo},
                   bytesize: 14,
                   access: :read_write
                 },
                 %Photor.Files.File{
                   path: "test/tmp/photo1.jpg",
                   type: %{type: :compressed, extension: "jpg", medium: :photo},
                   bytesize: 14,
                   access: :read_write
                 }
               ]
             }

      assert_received e

      assert e == %Events.ScanStarted{import_id: import.id}

      [
        "test/tmp/subdir/photo3.jpg",
        "test/tmp/photo2.jpg",
        "test/tmp/photo1.jpg"
      ]
      |> Enum.each(fn path ->
        assert_received e
        assert e == %Events.FileNotYetInRepoFound{import_id: import.id, path: path}
      end)

      assert_received e

      assert e == %Events.ImportStarted{
               import_id: import.id,
               bytes_to_import: 42,
               nb_files_to_import: 3
             }

      [
        "test/tmp/photo1.jpg",
        "test/tmp/photo2.jpg",
        "test/tmp/subdir/photo3.jpg"
      ]
      |> Enum.each(fn path ->
        assert_received e
        assert e == %Events.FileImporting{import_id: import.id, path: path}
        assert_received e
        assert e == %Events.FileImported{import_id: import.id, path: path}
      end)

      assert_received e

      assert e == %Events.ImportFinished{import_id: import.id}

      # # Verify results
      # assert length(results) == 3

      # # Check that all imports were successful
      # assert Enum.all?(results, fn r -> match?({:ok, _}, r) end)

      # # Check that files were copied to the repository
      # assert File.exists?(Path.join([@photor_dir, "2023-06-15"]))

      # # Check that database records were created
      # photo_count = Repo.aggregate(Photo, :count)
      # assert photo_count == 3
    end

    test "handles directory not found error" do
      # Try to import from a non-existent directory
      import = insert(:import)
      result = Importer.import_directory(import, "/nonexistent/dir")

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

      import = insert(:import)
      assert :ok = Importer.import_directory(import, @source_dir)

      # Add a new file
      file3 = Path.join(@source_dir, "photo3.jpg")
      File.write!(file3, "test content 3")

      # Import again - should only import the new file, and only read this file's metadata:
      MockExiftool
      |> expect(:read_as_json, 1, fn path ->
        filename = Path.basename(path)

        {:ok,
         %{
           "FileName" => filename,
           "CreateDate" => "2023-06-15 10:30:00",
           "MIMEType" => "image/jpeg"
         }}
      end)

      import = insert(:import)
      assert :ok = Importer.import_directory(import, @source_dir)

      # Check that we now have 3 photos in the database
      photo_count = Repo.aggregate(Photo, :count)
      assert photo_count == 3
    end
  end
end
