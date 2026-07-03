CREATE TABLE movies (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tmdb_id INTEGER NOT NULL,
    title TEXT NOT NULL, -- title just here as a human aid

    -- these from TMDB::Movie
    info TEXT,
    movie_cast TEXT, -- "cast" is a sql keyword, and is _cast in TMDB::Movie
    trailers TEXT,

    -- these from TMDB::Movie are yet unused/unimplemented

    images TEXT,
    keywords TEXT,
    releases TEXT,
    translations TEXT,
    changes TEXT,
    version TEXT,
    alternative_titles TEXT,

    is_deleted INTEGER CHECK (is_deleted IN (0, 1)) NOT NULL DEFAULT 0,
    modified_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
