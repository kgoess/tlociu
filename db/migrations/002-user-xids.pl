#!/usr/bin/env perl

=head1 NAME

002-user-xids.pl - add users.xid and give every existing user one

=head1 SYNOPSIS

Back up the db first, then:

    perl db/migrations/002-user-xids.pl db/tlociu.sqlite

=head1 DESCRIPTION

SQLite's ALTER TABLE ADD COLUMN can't add a UNIQUE column, so this adds the
column and a unique index on it. A Perl script rather than a .sql file because
SQLite can't generate the base58 ids itself.

Safe to run again: it skips adding the column if it's already there and only
fills in users that don't have an xid yet.

=cut

use 5.26.3;
use warnings;

use DBI;
use FindBin qw/$Bin/;
use lib "$Bin/../../lib";

use kg::Tlociu::Util::Xid qw/new_xid/;

my $db_file = shift or die "usage: $0 path/to/tlociu.sqlite\n";
-e $db_file or die "no such file $db_file\n";

my $dbh = DBI->connect("dbi:SQLite:dbname=$db_file", '', '', {
    RaiseError => 1,
    AutoCommit => 0,
});

my $has_xid = grep { $_->{name} eq 'xid' }
    @{ $dbh->selectall_arrayref('PRAGMA table_info(users)', { Slice => {} }) };

if (!$has_xid) {
    $dbh->do('ALTER TABLE users ADD COLUMN xid TEXT');
    $dbh->do('CREATE UNIQUE INDEX users_xid_unique ON users(xid)');
    say "added users.xid";
}

my $user_ids = $dbh->selectcol_arrayref('SELECT id FROM users WHERE xid IS NULL');
my $sth = $dbh->prepare('UPDATE users SET xid = ? WHERE id = ?');
foreach my $id (@$user_ids) {
    $sth->execute(new_xid(), $id);
}
$dbh->commit;

say "set xid for " . scalar(@$user_ids) . " users";
