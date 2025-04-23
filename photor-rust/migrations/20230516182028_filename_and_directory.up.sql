alter table photos
  add column filename text not null default '';

alter table photos
  add column directory text not null default '';

alter table photos
  drop column path;

-- the full hash had the wrong type:
drop index photo_hash_index;
alter table photos
  drop column full_hash;

-- new column for the sha256 hash:
alter table photos
  add column full_sha256_hash text not null default '';
create index full_sha256_hash_index on photos(full_sha256_hash);

