# kg::Tlociu - The Language of Cinema Is Universal

Hey, let's put on a movie. What do you want to watch tonight?

Wanting to have a movie watchlist, I was frustrated with letterboxd, and even
tmdb's features, because they didn't let me annotate *why* the film ended up on
the list. Recommended by Alice? Disrecommended by Bob? NYTimes Review? Saw a
trailer for it at the theater before seeing The Station Agent? I'd be looking
at my list on a Sunday evening and it's just a list of names with no context.

This is a simple Perl Dancer2 DBIx::Class web app backed by a SQLite database
that uses the API from The Movie Database:
https://developer.themoviedb.org/reference/intro/getting-started
([Why that one?](https://dev.to/zuplo/whats-the-best-movie-database-api-imdb-vs-tmdb-vs-omdb-b24))

Add a film to your list. Add some notes. Mark it watched. Add some comments.
That's it.

It uses the TMDB library [from CPAN](https://metacpan.org/pod/TMDB).

Track watchlist and films seen (The Language Of Cinema Is Universal)

Database schema is in [this directory](https://github.com/kgoess/tlociu/tree/master/db)

See the [screenshots
directory](https://github.com/kgoess/tlociu/tree/master/screenshots) for
screenshots of it in action.

# TODO features

- add CSRF tokens for forms
- add basic users
- add "signin with" buttons for google at least, maybe apple
- see the FIXMEs in style.css change those random colors to use var()s
- add gzip middleware
- add unit tests, any tests
- add tags
- add other fields: DP, Cinematographer,...?
- add sorting--Actor, Director, Writer, DP, Cinematographer...
- click on an actor's name to see other films on your lists by that actor
- scale the main list to work at hundreds or thousands of entries, maybe pagination?
- DONE make installable, run under mod_perl?
- DONE check error reporting on update screen, I think it's being squelched
- DONE add basic sorting to the watch list--by date, by director
- DONE conditional formatting for already watched films on the list
- DONE make watch/watched button clickable to update the entry

let mark as watched w/o going into edit screen
sort options: watched/unwatched, by date, alpha, director


## What's the name?

For a couple of decades starting in 1997 Landmark Theaters would run
[this cinema snipe](https://www.youtube.com/watch?v=Dl3XS-nuRSE)
(or [5.1 channel audio](https://www.youtube.com/watch?v=JwtJmW8nmOc)]) before films.
I imprint on little things [like](https://youtu.be/1KjTZDLZYG4?si=rh6UcGvG7DtN6V4M&t=12)
[that](https://www.youtube.com/watch?v=aLX00mcWxnM).

# Developer Notes:

## Your Environment:

    # perlbrew use perl-5.40.3 for rocky-10, otherwise rocky-8 installed Perl is 5.26.3
    eval "$(perl -Mlocal::lib=/var/lib/tlociu)"

## Making changes to the db tables.

The dev db is pointed to from environment/development.yml, is db/tlociu.sqlite. Make your changes to that db
and run this to update the files in lib/kg/Tlociu/Schema/:

    dbicdump -o dump_directory=./lib \
        -o components='["InflateColumn::DateTime"]' \
        -o datetime_undef_if_invalid=1 \
        -o moniker_map='{ movies => "Movie" }' \
        kg::Tlociu::Schema dbi:SQLite:db/tlociu.sqlite '{ quote_char => "\"" }'

