CREATE TABLE entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tmdb_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    title TEXT NOT NULL,
    title_lc TEXT NOT NULL,
    watchlist_notes TEXT,
    date_added TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    watched_notes TEXT,
    date_watched TIMESTAMP,
    is_deleted INTEGER CHECK (is_deleted IN (0, 1)) NOT NULL DEFAULT 0,
    is_public INTEGER CHECK (is_public IN (0, 1)) NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    -- modified_at TIMESTAMP
    -- deleted_at TIMESTAMP
    UNIQUE(user_id, title)
    UNIQUE(user_id, title_lc)
    FOREIGN KEY (user_id) REFERENCES users(id)
);
