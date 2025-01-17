defmodule PhotorUiWeb.PageController do
  use PhotorUiWeb, :controller

  alias PhotorUi.Photos

  def home(conn, _params) do
    _date = Photos.last_day() |> IO.inspect(label: :dattttte)
    redirect(conn, to: ~p"/2022-04-16")
  end

  def album(conn, %{"date" => date}) do
    IO.inspect(date, label: :date_from_args)
    photos = Photos.of_day(date)
    render(conn, :album, date: date, photos: photos)
  end

  # defp maybe_date(date_str) do
  #   with {:ok, date} <- Date.from_iso8601(date_str) do
  #     date
  #   else
  #     {:error, _} ->
  #       nil
  #   end
  # end
end
