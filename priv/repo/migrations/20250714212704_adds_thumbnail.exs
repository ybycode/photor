defmodule Photor.Repo.Migrations.AddsThumbnail do
  use Ecto.Migration

  def change do
    create table(:thumbnails) do
      add :width, :integer, null: false
      add :height, :integer, null: false
      # "S", "M", "L"
      add :size_name, :string, null: false
      add :photo_id, references(:photos, on_delete: :delete_all), null: false

      timestamps(updated_at: false)
    end
  end
end
