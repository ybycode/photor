defmodule Photor.Imports.Import do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @timestamps_opts [type: :utc_datetime_usec]
  schema "imports" do
    has_many :photos, Photor.Photos.Photo

    timestamps(inserted_at: :started_at, updated_at: false)
  end

  @doc """
  Creates a changeset for an import.
  """
  def new_changeset() do
    cast(%__MODULE__{}, %{}, [])
  end

  @doc """
  Creates a query for the most recent import.
  """
  def query_most_recent do
    from i in __MODULE__,
      order_by: [desc: i.started_at],
      limit: 1
  end
end
