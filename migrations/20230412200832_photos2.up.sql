alter table photos
  add column full_hash binary(128) not null default '';
