use 5.26.3;
use warnings;
use utf8;

use FindBin qw/$Bin/;
use lib "$Bin/lib";

use Encode qw/encode_utf8/;
use HTTP::Request::Common;
use Test::More;

use TestHelper;

my $Tag = 'kg::Tlociu::Schema::Result::Tag';

#
# parsing the entry form's tags field
#
is_deeply [ $Tag->parse_names("Horror, light   entertainment ,horror,, ") ],
    [ [ 'Horror', 'light entertainment' ], '' ],
    'parse_names trims, collapses spaces, drops empties and case-insensitive dups';
is_deeply [ $Tag->parse_names('') ], [ [], '' ], 'empty string is no tags';
my (undef, $err) = $Tag->parse_names('x' x 51);
like $err, qr/at most 50/, 'tags over 50 characters are an error';

my $t = TestHelper->new;
my $schema = $t->schema;
my $alice = $t->create_user(username => 'alice');
my $bob   = $t->create_user(username => 'bob');

sub tag_names_for {
    my ($entry_id) = @_;
    my $entry = $schema->resultset('Entry')->find($entry_id);
    return [ map { $_->name } $entry->tags->search({}, { order_by => 'tag.name_lc' })->all ];
}

sub update_form {
    my (%fields) = @_;
    return [
        title      => 'Film One',
        date_added => '2026-11-01',
        watched    => 0,
        visibility => 'public',
        %fields,
    ];
}

#
# saving tags from the entry form
#
$t->sign_in_as($alice);
$t->create_movie(101, 'Film One');
my $res = $t->post('/entry/create', [
    tmdb_id         => 101,
    title           => 'Film One',
    watchlist_notes => 'notes',
    date_added      => '2026-11-01',
    watched         => 0,
    visibility      => 'public',
    tags            => 'Horror, light   entertainment , horror',
]);
ok $res->is_redirect, 'POST /entry/create with tags' or diag $res->content;
my $entry1 = $schema->resultset('Entry')->search({ user_id => $alice->id, tmdb_id => 101 })->first;
is_deeply tag_names_for($entry1->id), [ 'Horror', 'light entertainment' ], 'new entry got its tags';
is $schema->resultset('Tag')->search({ user_id => $alice->id, name => 'Horror' })->first->visibility,
    'private', 'new tags start out private';

my $horror_id = $schema->resultset('Tag')->search({ name => 'Horror' })->first->id;
$res = $t->post('/entry/' . $entry1->id . '/update', update_form(tags => 'HORROR, Kurosawa'));
ok $res->is_redirect, 'POST update with tags';
is_deeply tag_names_for($entry1->id), [ 'Horror', 'Kurosawa' ],
    '"HORROR" matched the existing Horror tag, light entertainment taken off';
is $schema->resultset('Tag')->search({ name_lc => 'horror' })->count, 1, '...without a second horror tag';
is $schema->resultset('Tag')->search({ name => 'Horror' })->first->id, $horror_id, '...same tag as before';
ok $schema->resultset('Tag')->search({ name => 'light entertainment' })->first,
    'an unused tag sticks around';

$res = $t->post('/entry/' . $entry1->id . '/update', update_form());
is_deeply tag_names_for($entry1->id), [ 'Horror', 'Kurosawa' ], 'a form without a tags field leaves tags alone';

$res = $t->post('/entry/' . $entry1->id . '/update', update_form(tags => 'x' x 51));
like $res->content, qr/at most 50/, 'too-long tag shows an error';
is_deeply tag_names_for($entry1->id), [ 'Horror', 'Kurosawa' ], '...and changes nothing';

$res = $t->request(GET '/entry/' . $entry1->id . '/update');
like $res->content, qr/name="tags" id="tags" value="Horror, Kurosawa"/, 'edit form shows the tags';
like $res->content, qr/data-tag="light entertainment"/, '...and suggests your other tags';

# a second, private entry with Horror on it
my $entry2 = $t->create_entry($alice, tmdb_id => 102, title => 'Film Two', visibility => 'private');
$entry2->set_tag_names([ 'horror' ]);
is_deeply tag_names_for($entry2->id), [ 'Horror' ], 'set_tag_names matches case-insensitively too';

#
# filtering your own list
#
sub titles_on {
    my ($path) = @_;
    my $res = $t->request(GET $path);
    ok $res->is_success, "GET $path" or diag $res->status_line;
    my @titles = $res->content =~ m{<h2 class="entry-title">(?:<a [^>]*>)?([^<]+)}g;
    return [ sort @titles ], $res->content;
}

my ($titles, $content) = titles_on('/');
is_deeply $titles, [ 'Film One', 'Film Two' ], 'unfiltered list';
unlike $content, qr/class="tag-filter"/, '...no tag filter bar';
like $content, qr{class="tag tag-private" href="[^"]*\?tag=Horror"}, 'cards have tag links, private ones marked';

($titles, $content) = titles_on('/?tag=horror');
is_deeply $titles, [ 'Film One', 'Film Two' ], '?tag=horror, case-insensitive';
like $content, qr/class="tag-filter"/, '...shows the active filter';

($titles) = titles_on('/?tag=horror&tag=Kurosawa');
is_deeply $titles, [ 'Film One' ], 'two tags means entries with both';

($titles, $content) = titles_on('/?tag=Kurosawa&tag=light+entertainment');
is_deeply $titles, [], 'no entries with both';
like $content, qr/No entries with all of those tags/, '...says so';

($titles) = titles_on('/?tag=nonexistent');
is_deeply $titles, [], 'unknown tag matches nothing';

#
# tag privacy on someone else's list
#
my $kurosawa = $schema->resultset('Tag')->search({ name => 'Kurosawa' })->first;
$res = $t->post("/tags/$horror_id", [ name => 'Horror', visibility => 'users' ]);
ok $res->is_redirect, 'set Horror to signed-in users';

my $alice_list = '/users/' . $alice->xid;

$t->sign_in_as(undef);
($titles, $content) = titles_on($alice_list);
is_deeply $titles, [ 'Film One' ], 'signed out: public entry only';
unlike $content, qr/Horror|Kurosawa/, 'signed out: no users or private tags anywhere on the page';
($titles, my $private_tag_page) = titles_on("$alice_list?tag=Horror");
is_deeply $titles, [], 'signed out: filtering by a users tag matches nothing';
(undef, my $unknown_tag_page) = titles_on("$alice_list?tag=Zzzzzz");
s/Horror|Zzzzzz/TAG/g for $private_tag_page, $unknown_tag_page;
is $private_tag_page, $unknown_tag_page, '...and looks just like a tag that does not exist';

$t->sign_in_as($bob);
($titles, $content) = titles_on($alice_list);
is_deeply $titles, [ 'Film One' ], 'bob: sees the public entry';
like $content, qr/>Horror</, 'bob: sees the users tag';
unlike $content, qr/Kurosawa/, 'bob: does not see the private tag';
unlike $content, qr/tag-private/, 'bob: tags are not marked private/public for him';
($titles) = titles_on("$alice_list?tag=horror");
is_deeply $titles, [ 'Film One' ], 'bob: can filter by the users tag';
($titles) = titles_on("$alice_list?tag=Kurosawa");
is_deeply $titles, [], 'bob: filtering by the private tag matches nothing';

#
# tag clouds
#
$res = $t->request(GET "$alice_list/tags");
ok $res->is_success, "bob: GET alice's tag cloud";
like $res->content, qr{>Horror</a>}, '...has Horror';
like $res->content, qr{title="1 entry">Horror}, '...counting only the entry bob can see';
unlike $res->content, qr/Kurosawa|light entertainment/, '...not private or unused tags';
unlike $res->content, qr/tag-manage/, '...and no settings';

$t->sign_in_as(undef);
$res = $t->request(GET "$alice_list/tags");
ok $res->is_success, "signed out: GET alice's tag cloud";
unlike $res->content, qr/Horror|Kurosawa/, '...shows no tags';

$t->sign_in_as($alice);
$res = $t->request(GET '/tags');
ok $res->is_success, 'alice: GET /tags';
like $res->content, qr{title="2 entries">Horror}, '...cloud counts all her entries';
like $res->content, qr{value="light entertainment"}, '...settings list unused tags too';

#
# renaming, deleting
#
$res = $t->post("/tags/$horror_id", [ name => 'kurosawa', visibility => 'users' ]);
like $res->content, qr/already have a tag called &quot;Kurosawa&quot;|already have a tag called "Kurosawa"/,
    "can't rename onto another tag";
$res = $t->post("/tags/$horror_id", [ name => '  Scary  stuff ', visibility => 'public' ]);
ok $res->is_redirect, 'rename Horror';
my $renamed = $schema->resultset('Tag')->find($horror_id);
is $renamed->name, 'Scary stuff', '...trimmed';
is $renamed->name_lc, 'scary stuff', '...name_lc updated';
is $renamed->visibility, 'public', '...visibility updated';
$res = $t->post("/tags/$horror_id", [ name => 'x', visibility => 'friends' ]);
like $res->content, qr/Invalid visibility/, 'bad visibility is an error';

$t->sign_in_as($bob);
$res = $t->post("/tags/$horror_id", [ name => 'mine now', visibility => 'public' ]);
is $res->code, 404, "bob can't change alice's tag";
$res = $t->post("/tags/$horror_id/delete", []);
is $res->code, 404, "bob can't delete alice's tag";

$t->sign_in_as($alice);
$res = $t->post('/tags/' . $kurosawa->id . '/delete', []);
ok $res->is_redirect, 'delete Kurosawa';
ok !$schema->resultset('Tag')->find($kurosawa->id), '...tag is gone';
is $schema->resultset('EntryTag')->search({ tag_id => $kurosawa->id })->count, 0, '...and its links';

$res = $t->post('/entry/' . $entry2->id . '/delete', [ delete_it => 'yes' ]);
ok $res->is_redirect, 'delete an entry';
is $schema->resultset('EntryTag')->search({ entry_id => $entry2->id })->count, 0,
    "...its tag links go with it";

#
# non-ASCII tag names
#
$res = $t->post('/entry/' . $entry1->id . '/update', update_form(tags => encode_utf8('Ça va, 日本')));
ok $res->is_redirect, 'tags with non-ASCII names';
$entry1->discard_changes;
is_deeply tag_names_for($entry1->id), [ 'Ça va', '日本' ], '...saved';
$res = $t->post('/entry/' . $entry1->id . '/update', update_form(tags => encode_utf8('ÇA VA')));
is_deeply tag_names_for($entry1->id), [ 'Ça va' ], '...and matched case-insensitively';
($titles) = titles_on('/?tag=%C3%A7a+va');
is_deeply $titles, [ 'Film One' ], '...and filterable';

done_testing;
