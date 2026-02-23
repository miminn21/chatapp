-- Migration: add bio to users, add edited_at to messages
-- Run once against your chatapp_db database

ALTER TABLE users ADD COLUMN IF NOT EXISTS bio TEXT DEFAULT NULL AFTER status_message;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS edited_at DATETIME DEFAULT NULL AFTER deleted_at;
