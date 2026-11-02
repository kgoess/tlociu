use 5.26.3;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/lib";

use HTTP::Request::Common;
use Test::More;

use TestHelper;
use kg::Tlociu::Util::Xid qw/new_xid is_xid/;

my $t = TestHelper->new;

my $alice = $t->create_user(username => 'alice');
my $bob   = $t->create_user(username => 'bob');

ok is_xid($alice->xid), 'new users get an xid';
isnt $alice->xid, $bob->xid, '...a different one each';

$t->create_entry($alice,
    tmdb_id         => 1,
    title           => 'Public Film',
    visibility      => 'public',
    watchlist_notes => 'public-watchlist-notes',
    watched         => 1,
    watched_notes   => 'public-film-secret-watched-notes',
    watched_notes_visibility => 'private',
);
$t->create_entry($alice,
    tmdb_id         => 2,
    title           => 'Mixed Film',
    visibility      => 'public',
    watchlist_notes => 'mixed-film-users-notes',
    watchlist_notes_visibility => 'users',
);
$t->create_entry($alice,
    tmdb_id         => 3,
    title           => 'Users Film',
    visibility      => 'users',
    watchlist_notes => 'users-film-notes',
);
$t->create_entry($alice,
    tmdb_id         => 4,
    title           => 'Private Film',
    visibility      => 'private',
    watchlist_notes => 'private-film-notes',
);
$t->create_entry($bob,
    tmdb_id         => 1,
    title           => 'Public Film',
    visibility      => 'public',
    watchlist_notes => 'bobs-notes',
);

my $alice_url = '/users/' . $alice->xid;

# what each viewer should and shouldn't see on alice's page
my %expect = (
    'signed out' => {
        sees     => [ 'Public Film', 'public-watchlist-notes', 'Mixed Film' ],
        not_sees => [ 'Users Film', 'Private Film', 'mixed-film-users-notes',
                      'users-film-notes', 'private-film-notes',
                      'public-film-secret-watched-notes', 'bobs-notes' ],
    },
    'bob' => {
        sees     => [ 'Public Film', 'public-watchlist-notes', 'Mixed Film',
                      'mixed-film-users-notes', 'Users Film', 'users-film-notes' ],
        not_sees => [ 'Private Film', 'private-film-notes',
                      'public-film-secret-watched-notes', 'bobs-notes' ],
    },
    'alice' => {
        sees     => [ 'Public Film', 'public-watchlist-notes', 'Mixed Film',
                      'mixed-film-users-notes', 'Users Film', 'users-film-notes',
                      'Private Film', 'private-film-notes',
                      'public-film-secret-watched-notes' ],
        not_sees => [ 'bobs-notes' ],
    },
);
my %viewer = ('signed out' => undef, bob => $bob, alice => $alice);

foreach my $who ('signed out', 'bob', 'alice') {
    $t->sign_in_as($viewer{$who});
    my $res = $t->request(GET $alice_url);
    ok $res->is_success, "$who: GET alice's page" or diag $res->status_line;
    my $content = $res->content;
    like $content, qr/alice&#39;s list|alice's list/, "$who: page says whose list it is";
    unlike $content, qr{/entry/\d}, "$who: no links to edit entries";
    foreach my $text (@{ $expect{$who}{sees} }) {
        like $content, qr/\Q$text\E/, "$who sees $text";
    }
    foreach my $text (@{ $expect{$who}{not_sees} }) {
        unlike $content, qr/\Q$text\E/, "$who doesn't see $text";
    }
}

$t->sign_in_as(undef);
my $res = $t->request(GET '/users/' . new_xid());
is $res->code, 404, 'unknown xid is a 404';
$res = $t->request(GET '/users/1');
is $res->code, 404, 'a users.id is a 404';
$res = $t->request(GET '/users/<script>');
is $res->code, 404, 'garbage is a 404';
unlike $res->content, qr/<script>/, '...and is not echoed back';

$t->sign_in_as($alice);
$res = $t->request(GET '/');
ok $res->is_success, 'alice: GET /';
like $res->content, qr{\Q/users/${\ $alice->xid }\E}, 'front page has the share link';

done_testing;
