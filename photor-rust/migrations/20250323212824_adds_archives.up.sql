create table archives (
  -- uuid stored as text
  id text primary key not null,
  media_type text not null,
  inserted_at text not null
);

create table archive_tags (
    archive_id integer not null,
    tag text not null,
    foreign key (archive_id) references archives(id) on delete cascade,
    unique (archive_id, tag)
);

create table archives_holders (
  id integer primary key not null,
  archive_id text not null,
  name text not null,
  given_from text,
  back_on text,

  foreign key (archive_id) references archives (id) on delete cascade
);

create table archives_items (
  id integer primary key not null,
  archive_id text not null,
  item_id integer not null,
  inserted_at text not null,

  foreign key (archive_id) references archives (id) on delete cascade,
  foreign key (item_id) references photos (id) on delete cascade
);
