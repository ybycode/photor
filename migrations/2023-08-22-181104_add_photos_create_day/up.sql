-- Add a new column to store the date part of create_date
ALTER TABLE photos ADD COLUMN create_day text;

-- Create triggers for inserts and updates:
CREATE TRIGGER update_create_day_after_insert
AFTER INSERT ON photos
FOR EACH ROW
BEGIN
   UPDATE photos SET create_day = DATE(new.create_date) WHERE rowid = new.rowid;
END;

CREATE TRIGGER update_create_day_after_update
AFTER UPDATE OF create_date ON photos
FOR EACH ROW
BEGIN
   UPDATE photos SET create_day = DATE(new.create_date) WHERE rowid = new.rowid;
END;

-- Populate the new column with date part of create_date
UPDATE photos SET create_day = DATE(create_date);

-- Create an index on the new column
CREATE INDEX idx_create_day ON photos(create_day);
