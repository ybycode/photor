defmodule Photor.Photos.Photo do
  use Ecto.Schema

  import Ecto.Query

  schema "photos" do
    field :filename, :string
    field :directory, :string

    field :file_size_bytes, :integer
    field :partial_sha256_hash, :string
    field :full_sha256_hash, :string

    field :image_height, :integer
    field :image_width, :integer
    field :mime_type, :string
    field :iso, :integer
    field :aperture, :float
    field :shutter_speed, :string
    field :focal_length, :string
    field :make, :string
    field :model, :string
    field :lens_info, :string
    field :lens_make, :string
    field :lens_model, :string
    field :create_date, :naive_datetime
    field :create_day, :date
  end

  def query_unique_create_day() do
    from(p in __MODULE__,
      select: p.create_day,
      distinct: true,
      order_by: [desc: p.create_day]
    )
  end

  def query_last_day() do
    from(p in __MODULE__,
      select: p.create_day,
      order_by: [desc: p.create_day],
      limit: 1
    )
  end

  def query_of_day(day) do
    from(p in __MODULE__,
      where: p.create_day == ^day
    )
  end
end
