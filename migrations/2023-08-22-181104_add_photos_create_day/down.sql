DROP INDEX idx_create_day;

DROP TRIGGER update_create_day_after_insert;
DROP TRIGGER update_create_day_after_update;

ALTER TABLE photos DROP COLUMN create_day;
