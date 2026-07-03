
eval "$(perl -Mlocal::lib=/var/lib/tlociu)"

dbicdump -o dump_directory=./lib \
    -o inflect_singular='sub { my $word = shift; $word =~ s/^movies$/movie/; return $word; }' \
    -o components='["InflateColumn::DateTime"]' \
    -o datetime_undef_if_invalid=1 \
    -o moniker_map='{ movies => "Movie" }' \
    kg::Tlociu::Schema dbi:SQLite:db/tlociu.sqlite '{ quote_char => "\"" }'


noting for later:
    For complex dumps, put your options into a config file (e.g., schema.conf or a
    perl script).If using a Perl configuration file (schema.pm), specify the
    mapping like this:
    {
        inflect_singular => sub {
            my $word = shift;
            # Force "movies" to singularize as "movie"
            if ($word eq 'movies') {
                return 'movie';
            }
            # Fallback to standard DBIx::Class::Schema::Loader rules
            return $word;
        }
    }
    Then dump using your configuration file:
        dbicdump -o config_file=schema.pm MyApp::Schema 'dbi:SQLite:my_database.db'

