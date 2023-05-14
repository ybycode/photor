-- Your SQL goes here
alter table photos
  add column partial_hash text not null;

create index photo_partial_hash_index on photos(partial_hash);
