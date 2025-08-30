defmodule Photor.Photos.Thumbnails.Thumbnail do
  use Ecto.Schema
  import Ecto.Changeset

  @timestamps_opts [type: :utc_datetime_usec]
  schema "thumbnails" do
    field :height, :integer
    field :width, :integer
    # "small", "medium", "large"
    field :size_name, :string
    belongs_to :photo, Photor.Photos.Photo
    timestamps(updated_at: false)
  end

  def create_changeset(attrs) do
    cast(%__MODULE__{}, attrs, [
      :photo_id,
      :width,
      :height,
      :size_name
    ])
    |> validate_required([
      :photo_id,
      :width,
      :height,
      :size_name
    ])
    |> assoc_constraint(:photo)
  end
end
