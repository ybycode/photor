defmodule PhotorUi.Photos.Photo do
  use Ecto.Schema

  schema "photos" do
    field :filename, :string
    field :directory, :string

    field :full_sha256_hash, :string
    field :file_size_bytes, :integer
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
    field :create_day, :string
    field :partial_sha256_hash, :string
  end
end
