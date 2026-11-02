=head1 NAME

TestHelper - fresh test db and signed-in requests for kg::Tlociu tests

=head1 SYNOPSIS

    use FindBin qw/$Bin/;
    use lib "$Bin/lib";
    use TestHelper;

    my $t = TestHelper->new;    # deploys a fresh db/unittest.sqlite
    my $user = $t->create_user;
    $t->sign_in_as($user);

    my $res = $t->request(GET '/');
    $res = $t->post('/entry/create', [ title => ..., ... ]);

=head1 DESCRIPTION

Signing in for real needs a Google or Apple JWT, so this replaces
kg::Tlociu::FederatedAuth->check_google_auth with a stub that returns whoever
was passed to sign_in_as. Everything else (the before hook that reads the login
cookies, requires_login, the CSRF check) runs as usual.

The real JWT checking should get its own tests, not these.

=cut

package TestHelper;

use 5.26.3;
use warnings;

BEGIN { $ENV{DANCER_ENVIRONMENT} = 'unittest' };

use Crypt::URandom qw/urandom/;
use Digest::SHA qw/hmac_sha256_hex/;
use HTTP::Request::Common qw/POST/;
use JSON::MaybeXS qw/encode_json/;
use Plack::Test;

use kg::Tlociu;
use kg::Tlociu::FederatedAuth;
use kg::Tlociu::Util::Cookie qw/CSRFToken GoogleToken LoginMethod/;

my $Signed_in_as;

{
    no warnings 'redefine';
    *kg::Tlociu::FederatedAuth::check_google_auth = sub {
        return $Signed_in_as
            ? ($Signed_in_as, undef)
            : (undef, [401, 'not signed in (TestHelper stub)']);
    };
}

# FIXME should get this from the unittest.yml config instead?
my $Test_db = 'db/unittest.sqlite';

sub new {
    my ($class) = @_;

    my $self = bless {}, $class;
    $self->{schema} = setup_test_db();
    $self->{test}   = Plack::Test->create(kg::Tlociu->to_app);
    $self->{csrf_token} = make_csrf_token();
    return $self;
}

sub schema     { $_[0]->{schema} }
sub csrf_token { $_[0]->{csrf_token} }

sub setup_test_db {
    if (-e $Test_db) {
        unlink $Test_db or die "can't unlink $Test_db $!";
    }
    my $schema = kg::Tlociu::Schema->connect("dbi:SQLite:dbname=$Test_db", '', '');
    $schema->deploy;
    return $schema;
}

sub create_user {
    my ($self, %args) = @_;

    state $n = 0;
    $n++;
    return $self->schema->resultset('User')->create({
        username => "testuser$n",
        email    => "testuser$n\@example.com",
        %args,
    });
}

# Puts a movie in the movies table so the app finds it there instead of
# calling the TMDB API.
sub create_movie {
    my ($self, $tmdb_id, $title) = @_;

    return $self->schema->resultset('Movie')->find_or_create({
        tmdb_id    => $tmdb_id,
        title      => $title,
        info       => encode_json({
            id                => $tmdb_id,
            title             => $title,
            release_date      => '1980-01-30',
            origin_country    => ['FR'],
            original_language => 'fr',
            runtime           => 90,
            poster_path       => "/poster$tmdb_id.jpg",
        }),
        movie_cast => encode_json({
            cast => [],
            crew => [ { name => 'Jane Director', job => 'Director' } ],
        }),
        trailers   => encode_json({ youtube => [], quicktime => [] }),
    });
}

# Creates an entry for $user, and its movie. $fields has at least title and
# tmdb_id.
sub create_entry {
    my ($self, $user, %fields) = @_;

    $self->create_movie($fields{tmdb_id}, $fields{title});
    return $self->schema->resultset('Entry')->create({
        user_id => $user->id,
        %fields,
    });
}

# Pass undef to sign out.
sub sign_in_as {
    my ($self, $user) = @_;
    $Signed_in_as = $user;
}

# Sends the request with the login and CSRF cookies. Set them as a header
# rather than with a cookie jar, since the CSRF cookie is "secure" and a jar
# won't send it to http://localhost.
sub request {
    my ($self, $req) = @_;

    my %cookies = (CSRFToken() => $self->{csrf_token});
    if ($Signed_in_as) {
        $cookies{ LoginMethod() } = 'google';
        $cookies{ GoogleToken() } = 'test-token';
    }
    $req->header(Cookie => join '; ', map { "$_=$cookies{$_}" } sort keys %cookies);

    return $self->{test}->request($req);
}

# POST a form, with the csrf_token added.
sub post {
    my ($self, $path, $form) = @_;
    return $self->request(POST $path, [ @$form, csrf_token => $self->{csrf_token} ]);
}

# Same scheme as the CSRF hook in kg::Tlociu.
sub make_csrf_token {
    my $random_val = unpack("H*", urandom(32));
    my $signature = hmac_sha256_hex($random_val, kg::Tlociu::config()->{csrf_secret});
    return "$random_val.$signature";
}

1;
