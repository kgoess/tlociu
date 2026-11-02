-- Replace entries.is_public (0/1) with entries.visibility
-- ('private'/'users'/'public') and add per-notes visibility columns.
--
-- SQLite can't alter CHECK constraints, so this rebuilds the table.
-- Back up the db first, then:
--
--     sqlite3 db/tlociu.sqlite < db/migrations/001-visibility-levels.sql

PRAGMA foreign_keys = OFF;

BEGIN TRANSACTION;

CREATE TABLE entries_new (
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

INSERT INTO entries_new (
    id, tmdb_id, user_id, title, title_lc,
    watchlist_notes, date_added, watched, watched_notes, date_watched,
    is_deleted, visibility, created_at
)
SELECT
    id, tmdb_id, user_id, title, title_lc,
    watchlist_notes, date_added, watched, watched_notes, date_watched,
    is_deleted,
    CASE is_public WHEN 1 THEN 'public' ELSE 'private' END,
    created_at
FROM entries;

DROP TABLE entries;
ALTER TABLE entries_new RENAME TO entries;

COMMIT;

PRAGMA foreign_keys = ON;
