defmodule Photor.Repo.Migrations.CreateImports do
  use Ecto.Migration

  def change do
    create table(:imports) do
      timestamps(inserted_at: :started_at, updated_at: false)
    end

    alter table(:photos) do
      add :import_id, references(:imports, on_delete: :nilify_all)
    end

    create index(:photos, [:import_id])
  end
end
