use 5.26.3;
use warnings;

BEGIN { $ENV{DANCER_ENVIRONMENT} = 'unittest' };

use Test::More;

use kg::Tlociu;

my $Entry = 'kg::Tlociu::Schema::Result::Entry';

ok $Entry->is_valid_visibility($_), "$_ is a valid visibility"
    foreach qw< private users public >;
ok !$Entry->is_valid_visibility($_), "'$_' is not a valid visibility"
    foreach ('', 'friends', 'Public', '1');
ok !$Entry->is_valid_visibility(undef), 'undef is not a valid visibility';

my $schema = kg::Tlociu::Schema->connect('dbi:SQLite:dbname=:memory:');
my $rs = $schema->resultset('Entry');

# [entry visibility, notes visibility, expected effective notes visibility]
my @cases = (
    [ 'public', undef, 'public' ],
    [ 'users', undef, 'users' ],
    [ 'private', undef, 'private' ],
    [ 'public', 'users', 'users' ],
    [ 'public', 'private', 'private' ],
    [ 'users', 'private', 'private' ],
    # notes can't be more visible than the entry
    [ 'private', 'public', 'private' ],
    [ 'private', 'users', 'private' ],
    [ 'users', 'public', 'users' ],
);
foreach my $case (@cases) {
    my ($entry_vis, $notes_vis, $expected) = @$case;
    my $entry = $rs->new_result({
        visibility                 => $entry_vis,
        watchlist_notes_visibility => $notes_vis,
        watched_notes_visibility   => $notes_vis,
    });
    my $label = "entry $entry_vis, notes " . ($notes_vis // 'same as entry');
    is $entry->notes_visibility('watchlist_notes'), $expected, "watchlist_notes: $label";
    is $entry->notes_visibility('watched_notes'),   $expected, "watched_notes: $label";
}

is kg::Tlociu::visibility_params_error({ visibility => 'users' }), '',
    'entry visibility only is ok';
is kg::Tlociu::visibility_params_error({
        visibility                 => 'public',
        watchlist_notes_visibility => '',
        watched_notes_visibility   => 'private',
    }), '', 'empty notes visibility means same as entry';
like kg::Tlociu::visibility_params_error({}), qr/visibility/,
    'missing entry visibility is an error';
like kg::Tlociu::visibility_params_error({
        visibility               => 'public',
        watched_notes_visibility => 'friends',
    }), qr/watched_notes_visibility/, 'bad notes visibility is an error';

done_testing;
