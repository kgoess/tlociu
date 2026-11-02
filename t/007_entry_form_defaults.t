use 5.26.3;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/lib";

use HTTP::Request::Common;
use Test::More;

use TestHelper;

my $t = TestHelper->new;
my $user = $t->create_user;
$t->sign_in_as($user);

# the option that's selected in the <select name="$name">
sub selected_option {
    my ($content, $name) = @_;
    my ($select) = $content =~ m{(<select name="$name".*?</select>)}s
        or return 'no such select';
    my ($value) = $select =~ m{<option value="([^"]*)" selected>}
        or return 'nothing selected';
    return $value;
}

my $res = $t->request(GET '/entry/create');
ok $res->is_success, 'GET /entry/create';
like $res->content, qr{value="users" checked}, 'new entry defaults to "users"';
is selected_option($res->content, $_), 'private', "new entry: $_ defaults to private"
    foreach qw< watchlist_notes_visibility watched_notes_visibility >;

# An existing entry with NULL notes visibility still shows "same as entry"
my $entry = $t->create_entry($user,
    tmdb_id         => 1,
    title           => 'Some Film',
    watchlist_notes => 'notes',
    visibility      => 'public',
);
$res = $t->request(GET '/entry/' . $entry->id . '/update');
ok $res->is_success, 'GET /entry/:id/update';
is selected_option($res->content, $_), '', "existing entry: $_ is still same as entry"
    foreach qw< watchlist_notes_visibility watched_notes_visibility >;

done_testing;
