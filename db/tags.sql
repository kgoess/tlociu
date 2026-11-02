CREATE TABLE tags (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    -- tags are matched case-insensitively, "Horror" and "horror" are the same tag
    name_lc TEXT NOT NULL,
    -- who can see this tag on your entries, see entries.visibility
    visibility TEXT NOT NULL DEFAULT 'private' CHECK (visibility IN ('private', 'users', 'public')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, name_lc),
    FOREIGN KEY (user_id) REFERENCES users(id)
);
