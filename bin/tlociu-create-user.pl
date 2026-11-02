#!/usr/bin/env perl

=head1 NAME

tlociu-create-user.pl - add a row to the users table

=head1 SYNOPSIS

    bin/tlociu-create-user.pl --env development \
        --username alice --email alice@example.com

    Options:
        --env         development, production or unittest (required)
        --username    (required)
        --email       must match their Google/Apple sign-in email (required)
        --xid         public id for /users/:xid, generated if not given
        --created-at  e.g. '2026-11-01 18:30:00', defaults to now
        --is-deleted  0 or 1, defaults to 0
        --help

=head1 DESCRIPTION

Reads the database dsn from environments/<env>.yml, so relative dsns like
db/tlociu.sqlite are relative to the app directory, wherever you run this
from.

=cut

use 5.26.3;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/../lib";

use Getopt::Long;
use Pod::Usage;
use YAML qw/LoadFile/;

use kg::Tlociu::Schema;
use kg::Tlociu::Util::Xid qw/is_xid/;

my %opt;
GetOptions(\%opt, qw/
    env=s
    username=s
    email=s
    xid=s
    created-at=s
    is-deleted=i
    help
/) or pod2usage(2);
pod2usage(1) if $opt{help};

my @missing = grep { !defined $opt{$_} } qw/env username email/;
pod2usage("missing --" . join(', --', @missing)) if @missing;

if (defined $opt{xid} && !is_xid($opt{xid})) {
    die "--xid must be 10 base58 characters\n";
}

my $app_dir = "$Bin/..";
my $config_file = "$app_dir/environments/$opt{env}.yml";
-e $config_file or die "no config for environment '$opt{env}': $config_file\n";

my $config = LoadFile($config_file);
my $dsn = $config->{plugins}{'DBIx::Class'}{default}{dsn}
    or die "no plugins/DBIx::Class/default/dsn in $config_file\n";

chdir $app_dir or die "can't chdir to $app_dir: $!";
my $schema = kg::Tlociu::Schema->connect($dsn, '', '', { RaiseError => 1 });

my $user = $schema->resultset('User')->create({
    username => $opt{username},
    email    => $opt{email},
    (defined $opt{xid}          ? (xid        => $opt{xid})          : ()),
    (defined $opt{'created-at'} ? (created_at => $opt{'created-at'}) : ()),
    (defined $opt{'is-deleted'} ? (is_deleted => $opt{'is-deleted'}) : ()),
});

say "created user id " . $user->id . " in $dsn";
say "    username: " . $user->username;
say "    email:    " . $user->email;
say "    xid:      " . $user->xid;
say "their list:   /users/" . $user->xid;
