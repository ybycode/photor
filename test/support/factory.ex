defmodule Photor.Factory do
  # with Ecto

  use ExMachina.Ecto, repo: Photor.Repo

  alias Photor.Photos.Photo
  alias Photor.Imports.Import

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
end
