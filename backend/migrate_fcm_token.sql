-- Migration to add FCM token for push notifications
ALTER TABLE users ADD COLUMN fcm_token VARCHAR(255) DEFAULT NULL;
