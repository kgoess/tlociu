CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL UNIQUE,
    email TEXT NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_deleted INTEGER CHECK (is_deleted IN (0, 1)) NOT NULL DEFAULT 0
    -- modified_at TIMESTAMP
    -- deleted_at TIMESTAMP
);
