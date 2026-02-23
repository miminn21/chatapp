-- Consolidated ChatApp Schema (Ready for Railway)
-- Includes: Base Tables, FCM Tokens, Bio, and Message Editing

CREATE TABLE IF NOT EXISTS users (
  id             VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
  phone          VARCHAR(20)  UNIQUE NOT NULL,
  name           VARCHAR(100) NOT NULL,
  email          VARCHAR(100) DEFAULT NULL,
  password       VARCHAR(255) NOT NULL,
  avatar         MEDIUMBLOB   DEFAULT NULL,
  cover_photo    MEDIUMBLOB   DEFAULT NULL,
  status_message VARCHAR(255) DEFAULT 'Hey there! I am using ChatApp.',
  bio            TEXT         DEFAULT NULL,
  fcm_token      VARCHAR(255) DEFAULT NULL,
  is_online      BOOLEAN      DEFAULT FALSE,
  last_seen      DATETIME     DEFAULT CURRENT_TIMESTAMP,
  created_at     DATETIME     DEFAULT CURRENT_TIMESTAMP,
  updated_at     DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS contacts (
  id              VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
  user_id         VARCHAR(36) NOT NULL,
  contact_user_id VARCHAR(36) NOT NULL,
  nickname        VARCHAR(100) DEFAULT NULL,
  created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id)         REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (contact_user_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE KEY uq_contact (user_id, contact_user_id)
);

CREATE TABLE IF NOT EXISTS conversations (
  id         VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
  type       ENUM('dm','group') NOT NULL DEFAULT 'dm',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS groups_info (
  id              VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
  conversation_id VARCHAR(36) NOT NULL UNIQUE,
  name            VARCHAR(100) NOT NULL,
  description     VARCHAR(255) DEFAULT '',
  avatar          MEDIUMBLOB   DEFAULT NULL,
  created_by      VARCHAR(36) NOT NULL,
  created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
  FOREIGN KEY (created_by)      REFERENCES users(id)         ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS conversation_members (
  id              VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
  conversation_id VARCHAR(36) NOT NULL,
  user_id         VARCHAR(36) NOT NULL,
  role            ENUM('admin','member') DEFAULT 'member',
  joined_at       DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id)         REFERENCES users(id)         ON DELETE CASCADE,
  UNIQUE KEY uq_member (conversation_id, user_id)
);

CREATE TABLE IF NOT EXISTS messages (
  id              VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
  conversation_id VARCHAR(36) NOT NULL,
  sender_id       VARCHAR(36) NOT NULL,
  type            ENUM('text','image','video','audio','file','system') NOT NULL DEFAULT 'text',
  content         TEXT NOT NULL,
  reply_to        VARCHAR(36) DEFAULT NULL,
  deleted_at      DATETIME    DEFAULT NULL,
  edited_at       DATETIME    DEFAULT NULL,
  created_at      DATETIME    DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
  FOREIGN KEY (sender_id)       REFERENCES users(id)         ON DELETE CASCADE,
  FOREIGN KEY (reply_to)        REFERENCES messages(id)      ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS message_status (
  id         VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
  message_id VARCHAR(36) NOT NULL,
  user_id    VARCHAR(36) NOT NULL,
  status     ENUM('sent','delivered','read') DEFAULT 'sent',
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id)    REFERENCES users(id)    ON DELETE CASCADE,
  UNIQUE KEY uq_status (message_id, user_id)
);

-- Performance indexes
CREATE INDEX idx_messages_conv   ON messages(conversation_id, created_at);
CREATE INDEX idx_conv_member_user ON conversation_members(user_id);
CREATE INDEX idx_contacts_user   ON contacts(user_id);
