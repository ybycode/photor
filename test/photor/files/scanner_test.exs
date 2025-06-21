defmodule Photor.Files.ScannerTest do
  use ExUnit.Case

  alias Photor.Files.Scanner
  alias Photor.Files.File, as: File_

  # Create a temporary directory structure for testing
  setup do
    # Create a temp directory
    tmp_dir = Path.join(System.tmp_dir!(), "photor_scanner_test_#{:rand.uniform(1000)}")
    File.mkdir_p!(tmp_dir)

    # Create some subdirectories
    sub_dir1 = Path.join(tmp_dir, "subdir1")
    sub_dir2 = Path.join(tmp_dir, "subdir2")
    File.mkdir_p!(sub_dir1)
    File.mkdir_p!(sub_dir2)

    # Create some test files
    File.write!(Path.join(tmp_dir, "photo1.jpg"), "test")
    File.write!(Path.join(tmp_dir, "photo2.JPG"), "test")
    File.write!(Path.join(tmp_dir, "raw1.dng"), "test")
    File.write!(Path.join(sub_dir1, "video1.mp4"), "test")
    File.write!(Path.join(sub_dir2, "photo3.jpeg"), "test")
    File.write!(Path.join(sub_dir2, "document.txt"), "test")

    on_exit(fn -> File.rm_rf!(tmp_dir) end)

    {:ok, tmp_dir: tmp_dir, sub_dir1: sub_dir1, sub_dir2: sub_dir2}
  end

  describe "scan_directory/2" do
    test "finds all media files recursively", %{tmp_dir: tmp_dir} do
      {:ok, [file1 | _rest] = files} = Scanner.scan_directory(tmp_dir)

      # Should find 5 media files (3 photos, 1 raw, 1 video)
      assert length(files) == 5

      # Check that we have the right types
      photo_files = Enum.filter(files, fn %{type: type} -> type.medium == :photo end)
      video_files = Enum.filter(files, fn %{type: type} -> type.medium == :video end)

      # 3 jpg/jpeg + 1 raw
      assert length(photo_files) == 4
      assert length(video_files) == 1

      # Verify file extensions
      extensions = Enum.map(files, fn %{type: type} -> type.extension end)
      assert "jpg" in extensions
      assert "JPG" in extensions
      assert "jpeg" in extensions
      assert "dng" in extensions
      assert "mp4" in extensions

      assert %File_{
               path: _,
               type: %{type: :compressed, extension: "jpg", medium: :photo},
               bytesize: 4,
               access: :read_write
             } = file1
    end

    test "finds files in current directory only when recursive is false", %{tmp_dir: tmp_dir} do
      {:ok, files} = Scanner.scan_directory(tmp_dir, recursive: false)

      # Should find 3 media files in the root dir only (2 jpg, 1 raw)
      assert length(files) == 3

      # All paths should be in the root directory
      Enum.each(files, fn %{path: path} ->
        assert Path.dirname(path) == tmp_dir
      end)
    end

    test "filters by media type", %{tmp_dir: tmp_dir} do
      # Only look for compressed photos
      {:ok, files} = Scanner.scan_directory(tmp_dir, types: [{:photo, :compressed}])

      assert length(files) == 3

      Enum.each(files, fn %{type: type} ->
        assert type.medium == :photo
        assert type.type == :compressed
      end)

      # Only look for videos
      {:ok, files} = Scanner.scan_directory(tmp_dir, types: [{:video, :compressed}])

      assert length(files) == 1
      [%{type: type}] = files
      assert type.medium == :video
      assert type.type == :compressed
    end

    test "returns error for non-existent directory" do
      assert {:error, _} = Scanner.scan_directory("/non/existent/directory")
    end
  end
end
