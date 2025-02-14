-- Add down migration script here
ALTER TABLE photos drop COLUMN inserted_at;
