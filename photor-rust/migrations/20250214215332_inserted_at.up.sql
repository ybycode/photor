-- Step 1: Add the new column as nullable
ALTER TABLE photos ADD COLUMN inserted_at TEXT;

-- Step 2: Update the existing rows to set inserted_at to the value of create_date
UPDATE photos SET inserted_at = create_date;

-- Step 3: Alter the column to add the NOT NULL constraint
-- SQLite does not support directly altering a column to add NOT NULL, so we need to recreate the table.
-- Begin by renaming the existing table
ALTER TABLE photos RENAME TO photos_old;

-- Step 4: Create the new table with the desired schema (including inserted_at as NOT NULL)
CREATE TABLE photos (
  id integer primary key not null,
  filename text not null,
  directory text not null,
  full_sha256_hash text not null default '',
  file_size_bytes bigint not null,
  image_height integer,
  image_width integer,
  mime_type text,
  iso integer,
  aperture real,
  shutter_speed text,
  focal_length text,
  make text,
  model text,
  lens_info text,
  lens_make text,
  lens_model text,
  create_date text not null,
  create_day text,
  partial_sha256_hash text not null,
  inserted_at text not null
);

-- Step 5: Copy data from the old table to the new table
INSERT INTO photos
SELECT id, filename, directory, full_sha256_hash, file_size_bytes, image_height, image_width, mime_type, iso, aperture, shutter_speed, focal_length, make, model, lens_info, lens_make, lens_model, create_date, create_day, partial_sha256_hash, inserted_at
FROM photos_old;

-- Step 6: Drop the old table
DROP TABLE photos_old;

-- Step 7: Recreate the indexes and trigger:

CREATE INDEX full_sha256_hash_index on photos(full_sha256_hash);
CREATE TRIGGER update_create_day_after_insert
after insert on photos
for each row
begin
   update photos set create_day = date(new.create_date) where rowid = new.rowid;
end;
CREATE TRIGGER update_create_day_after_update
after update of create_date on photos
for each row
begin
   update photos set create_day = date(new.create_date) where rowid = new.rowid;
end;
CREATE INDEX idx_create_day on photos(create_day);
CREATE INDEX photo_partial_sha256_hash_index on photos(partial_sha256_hash);
