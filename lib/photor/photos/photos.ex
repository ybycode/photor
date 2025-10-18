defmodule Photor.Photos do
  alias Photor.Photos.Photo
  alias Photor.Repo

  def unique_create_day(), do: Photo.query_unique_create_day() |> Repo.all()

  def last_day(), do: Photo.query_last_day() |> Repo.one()

  def of_day(day),
    do:
      Photo.query_of_day(day)
      |> Photo.order_by_create_date()
      |> Photo.only_jpeg()
      |> Photo.load_thumbnails()
      |> Repo.all()

  def make_photo_path(%Photo{directory: directory, filename: filename}) do
    Path.join([directory, filename])
  end
end
