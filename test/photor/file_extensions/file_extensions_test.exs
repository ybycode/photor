defmodule Photor.FileExtensionsTest do
  use ExUnit.Case

  alias Photor.FileExtensions

  @photo_compressed {:photo, :compressed}
  @photo_raw {:photo, :raw}
  @video_compressed {:video, :compressed}

  describe "extension_info/1" do
    test "works" do
      [
        {"jpg", @photo_compressed},
        {"JPG", @photo_compressed},
        {"raf", @photo_raw},
        {"RAF", @photo_raw},
        {"jpeg", @photo_compressed},
        {"mp4", @video_compressed},
        {"MP4", @video_compressed}
      ]
      |> Enum.each(fn {extension, expected_result} ->
        assert FileExtensions.extension_info(extension) == expected_result
      end)
    end
  end
end
