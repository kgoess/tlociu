use 5.26.3;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/lib";

use Encode qw/decode_utf8 encode_utf8 is_utf8/;
use HTML::Entities qw/decode_entities/;
use HTTP::Request::Common;
use JSON::MaybeXS qw/decode_json/;
use Test::More tests => 6;

use TestHelper;

my $t = TestHelper->new;
$t->sign_in_as($t->create_user);

my $res;

my $post_content = q{title=L%27%C3%82ge+b%C3%AAte&tmdb_id=838844&watchlist_notes=testing+utf8&date_added=2026-07-09&watched=0&watched_notes=&date_watched=&visibility=private};
$post_content .= '&csrf_token=' . $t->csrf_token;
$res  = $t->request(POST '/entry/create', Content => $post_content);
ok $res->is_redirect, '[POST /] successful' or do {
    say STDERR $res->content;
};

$res = $t->request(GET '/');
ok $res->is_success, 'GET / ok';
my $content = $res->content;

$content =~ m{(<h2 class="entry-title"><a href="http://localhost/entry/1">(.+?)</a></h2>)} or die "can't find entry-title in /\n".$content;

my $h2 = $1;
my $title = $2;

# note that there's no "use utf8" in this file so these are all octets not logical characters
is $title, q{L&#39;Âge bête}, q{HTML title L'Âge bête};


my $schema = $t->schema;
my $rs;
$rs = $schema->resultset('Entry');
my $entry_from_db = $rs->find(1);
is encode_utf8($entry_from_db->title), q{L'Âge bête}, q{db entry title L'Âge bête}; 

$rs = $schema->resultset('Movie');
my $movie_from_db = $rs->find(1);
is encode_utf8($movie_from_db->title), q{L'Âge bête}, q{db movie title L'Âge bête}; 

my $title_from_info = decode_json($movie_from_db->info)->{title};
is $title_from_info, decode_utf8(q{L'Âge bête}), q{title from info json is L'Âge bête};
