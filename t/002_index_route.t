use strict;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/lib";

use HTTP::Request::Common;
use Test::More tests => 4;

use TestHelper;

my $t = TestHelper->new;

my $res = $t->request(GET '/');
ok $res->is_redirect, '[GET /] redirects when signed out';
like $res->header('Location'), qr{/signin$}, '...to /signin';

$t->sign_in_as($t->create_user);

$res = $t->request(GET '/');
ok $res->is_success, '[GET /] successful when signed in' or diag $res->status_line;
like $res->content, qr/<html/i, '...and returns a page';
