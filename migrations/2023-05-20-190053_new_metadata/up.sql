alter table photos add column file_size_bytes integer not null default 0;
alter table photos add column image_height integer;
alter table photos add column image_width integer;
alter table photos add column mime_type text;
alter table photos add column iso integer;
alter table photos add column aperture real;
alter table photos add column shutter_speed text;
alter table photos add column focal_length text;
alter table photos add column make text;
alter table photos add column model text;
alter table photos add column lens_info text;
alter table photos add column lens_make text;
alter table photos add column lens_model text;