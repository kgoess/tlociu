CREATE TABLE entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tmdb_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    title TEXT NOT NULL,
    title_lc TEXT NOT NULL,
    watchlist_notes TEXT,
    -- NULL means "same as the entry's visibility"
    watchlist_notes_visibility TEXT CHECK (watchlist_notes_visibility IN ('private', 'users', 'public')),
    date_added TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    watched BOOLEAN NOT NULL DEFAULT 0 CHECK (watched IN (0, 1)),
    watched_notes TEXT,
    -- NULL means "same as the entry's visibility"
    watched_notes_visibility TEXT CHECK (watched_notes_visibility IN ('private', 'users', 'public')),
    date_watched TIMESTAMP,
    is_deleted INTEGER CHECK (is_deleted IN (0, 1)) NOT NULL DEFAULT 0,
    -- 'users' means other people signed in to tlociu
    visibility TEXT NOT NULL DEFAULT 'private' CHECK (visibility IN ('private', 'users', 'public')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    -- modified_at TIMESTAMP
    -- deleted_at TIMESTAMP
    UNIQUE(user_id, tmdb_id)
    FOREIGN KEY (user_id) REFERENCES users(id)
);
