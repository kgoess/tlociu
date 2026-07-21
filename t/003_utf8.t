use 5.26.3;
use warnings;

BEGIN { $ENV{DANCER_ENVIRONMENT} = 'unittest' };

use Encode qw/decode_utf8 encode_utf8 is_utf8/;
use HTML::Entities qw/decode_entities/;
use HTTP::Request::Common;
use JSON::MaybeXS qw/decode_json/;
use Plack::Test;
use Test::More tests => 6;

use kg::Tlociu;

setup_test_db();

my $app = kg::Tlociu->to_app;

my $test = Plack::Test->create($app);

my $res;

my $post_content = q{title=L%27%C3%82ge+b%C3%AAte&tmdb_id=838844&watchlist_notes=testing+utf8&date_added=2026-07-09&watched=0&watched_notes=&date_watched=&is_public=0};
$res  = $test->request(POST '/entry/create', Content => $post_content);
ok $res->is_redirect, '[POST /] successful' or do {
    say STDERR $res->content;
};

$res = $test->request(GET '/');
ok $res->is_success, 'GET / ok';
my $content = $res->content;

$content =~ m{(<h2 class="entry-title"><a href="http://localhost/entry/1">(.+?)</a></h2>)} or die "can't find entry-title in /\n".$content;

my $h2 = $1;
my $title = $2;

# note that there's no "use utf8" in this file so these are all octets not logical characters
is $title, q{L&#39;Âge bête}, q{HTML title L'Âge bête};


my %dbi_params;
my $schema = kg::Tlociu::Schema->connect($ENV{TEST_DSN}, '', '', \%dbi_params);
my $rs;
$rs = $schema->resultset('Entry');
my $entry_from_db = $rs->find(1);
is encode_utf8($entry_from_db->title), q{L'Âge bête}, q{db entry title L'Âge bête}; 

$rs = $schema->resultset('Movie');
my $movie_from_db = $rs->find(1);
is encode_utf8($movie_from_db->title), q{L'Âge bête}, q{db movie title L'Âge bête}; 

my $title_from_info = decode_json($movie_from_db->info)->{title};
is $title_from_info, decode_utf8(q{L'Âge bête}), q{title from info json is L'Âge bête};





sub setup_test_db {
    #my $test_script = basename $0, '.t';
    #mkdir "$Bin/testdbs"; # might already exist, that's ok
    #my $test_db = "$Bin/testdbs/testdb.$test_script.sqlite";
    my $test_db = 'db/unittest.sqlite';

    if (-e $test_db) {
        unlink $test_db or die "can't unlink $test_db $!";
    }

    # FIXME should get DSN from the unittest.yml config instead?
    $ENV{TEST_DSN} = "dbi:SQLite:dbname=$test_db";
    # load an on-disk test database and deploy the required tables
    kg::Tlociu::Schema->connection($ENV{TEST_DSN},'','');
    kg::Tlociu::Schema->load_namespaces;
    kg::Tlociu::Schema->deploy;
}

