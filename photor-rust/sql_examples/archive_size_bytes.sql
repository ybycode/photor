-- shows the archive size in bytes:
select sum(p.file_size_bytes)
from photos p
join archives_items ai on ai.item_id = p.id
join archives a on a.id = ai.archive_id
where a.id = 'my archive';
