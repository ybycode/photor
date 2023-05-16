alter table photos
  drop column filename;

alter table photos
  drop column directory;

alter table photos
  add column path varchar not null;

-- the full hash had the wrong type:
alter table photos
  add column full_hash binary(128) not null default '';
create index photo_hash_index on photos(full_hash);

-- new column for the sha256 hash:
drop index full_sha256_hash_index;
alter table photos
  drop column full_sha256_hash;

