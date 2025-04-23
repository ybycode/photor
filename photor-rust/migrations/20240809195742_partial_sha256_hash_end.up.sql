-- Basically we want "not null" on the partial_sha256_hash column.
-- default '' was also removed from the filename and directory fields.

create table photos_fixed (
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
  create_date text not null default '1970-01-01 00:00:00',
  create_day text,
  partial_sha256_hash text not null
);

insert into photos_fixed select * from photos;

drop table photos;

alter table photos_fixed rename to photos;

create index full_sha256_hash_index on photos(full_sha256_hash);
create trigger update_create_day_after_insert
after insert on photos
for each row
begin
   update photos set create_day = date(new.create_date) where rowid = new.rowid;
end;
create trigger update_create_day_after_update
after update of create_date on photos
for each row
begin
   update photos set create_day = date(new.create_date) where rowid = new.rowid;
end;
create index idx_create_day on photos(create_day);
create index photo_partial_sha256_hash_index on photos(partial_sha256_hash);
