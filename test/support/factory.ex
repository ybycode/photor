defmodule Photor.Factory do
  # with Ecto

  use ExMachina.Ecto, repo: Photor.Repo

  alias Photor.Photos.Photo
  alias Photor.Imports.Import
  alias Photor.Photos.Thumbnails.Thumbnail

  def photo_factory do
    %Photo{
      filename: sequence(:filename, &"photo-#{&1}.jpg"),
      directory: sequence("some/dir"),
      file_size_bytes: 100,
      create_date: NaiveDateTime.utc_now(),
      partial_sha256_hash: sequence(:partial_sha256_hash, fn n -> "fake-hash-#{n}" end)
    }
  end

  def import_factory do
    %Import{}
  end

  def thumbnail_factory do
    %Thumbnail{
      height: sequence(:height, [100, 400, 1200]),
      width: sequence(:height, [100, 400, 1200]),
      size_name: sequence(:size_name, ["small", "medium", "large"]),
      photo: build(:photo)
    }
  end
end
