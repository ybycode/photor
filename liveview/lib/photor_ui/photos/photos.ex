defmodule PhotorUi.Photos do
  alias PhotorUi.Photos.Photo
  alias PhotorUi.Repo

  def last_day(), do: Photo.query_last_day() |> Repo.one()

  def of_day(day), do: Photo.query_of_day(day) |> Repo.all()
end
