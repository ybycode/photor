-- This file should undo anything in `up.sql`
alter table photos
  drop column partial_hash;
