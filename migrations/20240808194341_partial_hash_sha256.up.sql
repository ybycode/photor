-- Add up migration script here
drop index photo_partial_hash_index;

alter table photos
  drop column partial_hash;

alter table photos
  add column partial_sha256_hash text not null;

create index photo_partial_sha256_hash_index on photos(partial_sha256_hash);
