
eval "$(perl -Mlocal::lib=/var/lib/tlociu)"

dbicdump -o dump_directory=./lib \
    -o components='["InflateColumn::DateTime"]' \
    -o datetime_undef_if_invalid=1 \
    kg::Tlociu::Schema dbi:SQLite:db/tlociu.sqlite '{ quote_char => "\"" }'
