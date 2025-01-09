defmodule PhotorUiWeb.PageController do
  use PhotorUiWeb, :controller

  alias PhotorUi.Photos

  def home(conn, params) do
    IO.inspect(params)

    date = maybe_date(params["date"]) || Photos.last_day()
    photos = Photos.of_day(date) |> IO.inspect()
    render(conn, :home, date: date, photos: photos)
  end

  defp maybe_date(nil), do: nil

  defp maybe_date(date_str) do
    with {:ok, date} <- Date.from_iso8601(date_str) do
      date
    else
      {:error, _} ->
        nil
    end
  end
end
