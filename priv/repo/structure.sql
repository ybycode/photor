CREATE TABLE _sqlx_migrations (
    version BIGINT PRIMARY KEY,
    description TEXT NOT NULL,
    installed_on TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    success BOOLEAN NOT NULL,
    checksum BLOB NOT NULL,
    execution_time BIGINT NOT NULL
);
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
CREATE TABLE archives (
  -- uuid stored as text
  id text primary key not null,
  media_type text not null,
  inserted_at text not null
);
CREATE TABLE archive_tags (
    archive_id integer not null,
    tag text not null,
    foreign key (archive_id) references archives(id) on delete cascade,
    unique (archive_id, tag)
);
CREATE TABLE archives_holders (
  id integer primary key not null,
  archive_id text not null,
  name text not null,
  given_from text,
  back_on text,

  foreign key (archive_id) references archives (id) on delete cascade
);
CREATE TABLE archives_items (
  id integer primary key not null,
  archive_id text not null,
  item_id integer not null,
  inserted_at text not null,

  foreign key (archive_id) references archives (id) on delete cascade,
  foreign key (item_id) references photos (id) on delete cascade
);
CREATE TABLE IF NOT EXISTS "schema_migrations" ("version" INTEGER PRIMARY KEY, "inserted_at" TEXT);
