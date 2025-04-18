defmodule Photor.Photos do
  alias Photor.Photos.Photo
  alias Photor.Repo

  def unique_create_day(), do: Photo.query_unique_create_day() |> Repo.all()

  def last_day(), do: Photo.query_last_day() |> Repo.one()

  def of_day(day), do: Photo.query_of_day(day) |> Repo.all()
end
