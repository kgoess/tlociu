-- Add user tags: tags (per user, each with its own visibility) and
-- entry_tags linking them to entries.
--
-- Back up the db first, then:
--
--     sqlite3 db/tlociu.sqlite < db/migrations/003-tags.sql

BEGIN TRANSACTION;

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

CREATE TABLE entry_tags (
    entry_id INTEGER NOT NULL,
    tag_id INTEGER NOT NULL,
    PRIMARY KEY (entry_id, tag_id),
    FOREIGN KEY (entry_id) REFERENCES entries(id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
);
CREATE INDEX entry_tags_tag_id ON entry_tags(tag_id);

COMMIT;
