defmodule Photor.Repo.Migrations.DropCreateDayTriggers do
  use Ecto.Migration

  def up do
    execute "DROP TRIGGER IF EXISTS update_create_day_after_insert"
    execute "DROP TRIGGER IF EXISTS update_create_day_after_update"
  end

  def down do
    execute """
    CREATE TRIGGER update_create_day_after_insert
    after insert on photos
    for each row
    begin
       update photos set create_day = date(new.create_date) where rowid = new.rowid;
    end;
    """

    execute """
    CREATE TRIGGER update_create_day_after_update
    after update of create_date on photos
    for each row
    begin
       update photos set create_day = date(new.create_date) where rowid = new.rowid;
    end;
    """
  end
end
