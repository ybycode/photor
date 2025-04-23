-- Select the oldest photos not yet archived, up to a cumulative size of 1.5TB
-- (a LTO-5 cartridge):
with unarchived_photos as (
  select p.*
  from photos p
  left join archives_items ai on p.id = ai.item_id
  where ai.item_id is null
  order by p.create_date asc  -- oldest first
),
cumulative_sizes as (
  select
    *,
    sum(file_size_bytes) over (order by create_date asc) as running_total
  from unarchived_photos
)
select *
from cumulative_sizes
where running_total <= 1500000000000  -- 1.5tb in bytes
order by create_date asc;
