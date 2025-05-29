defmodule Photor.Repo.Migrations.RemoveCreateDayTrigger do
  use Ecto.Migration

  def up do
    # Drop the trigger that was automatically setting create_day
    execute "DROP TRIGGER IF EXISTS set_create_day"
  end

  def down do
    # Recreate the trigger if we need to rollback
    execute """
    CREATE TRIGGER set_create_day
    AFTER INSERT ON photos
    FOR EACH ROW
    WHEN NEW.create_day IS NULL AND NEW.create_date IS NOT NULL
    BEGIN
      UPDATE photos
      SET create_day = date(NEW.create_date)
      WHERE id = NEW.id;
    END;
    """
  end
end
