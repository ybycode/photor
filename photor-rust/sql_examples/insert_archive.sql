insert into archives (id, media_type, inserted_at)
values ('my archive', 'LTO5', datetime('now'));

insert into archives_items (archive_id, item_id, inserted_at)
select 'my archive', id, datetime('now') from photos
where directory || '/' || filename in (
  '2024-02-24/DSCF1093.MOV',
  '2024-02-24/DSCF1094.MOV',
  '2024-02-24/DSCF1095.MOV',
  '2024-02-24/DSCF1096.JPG',
  '2024-02-24/DSCF1096.RAF',
  '2024-02-24/DSCF1097.JPG',
  '2024-02-24/DSCF1097.RAF',
  '2024-02-24/DSCF1098.JPG',
  '2024-02-24/DSCF1098.RAF',
  '2024-02-24/DSCF1099.JPG',
  '2024-02-24/DSCF1099.RAF',
  '2024-02-24/DSCF1100.JPG',
  '2024-02-24/DSCF1100.RAF',
  '2024-02-24/DSCF1101.JPG',
  '2024-02-24/DSCF1101.RAF',
  '2024-02-24/DSCF1102.JPG',
  '2024-02-24/DSCF1102.RAF',
  '2024-02-24/DSCF1103.JPG',
  '2024-02-24/DSCF1103.RAF',
  '2024-02-24/DSCF1104.JPG',
  '2024-02-24/DSCF1104.RAF',
  '2024-02-24/DSCF1105.JPG',
  '2024-02-24/DSCF1105.RAF',
  '2024-02-24/DSCF1106.JPG',
  '2024-02-24/DSCF1106.RAF',
  '2024-02-24/DSCF1107.JPG',
  '2024-02-24/DSCF1107.RAF',
  '2024-02-24/DSCF1108.JPG',
  '2024-02-24/DSCF1108.RAF',
  '2024-02-24/DSCF1109.JPG',
  '2024-02-24/DSCF1109.RAF',
  '2024-02-24/DSCF1110.JPG',
  '2024-02-24/DSCF1110.RAF',
);
