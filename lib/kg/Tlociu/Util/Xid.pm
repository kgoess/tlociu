=head1 NAME

kg::Tlociu::Util::Xid - short random public ids for users

=head1 SYNOPSIS

    use kg::Tlociu::Util::Xid qw/new_xid is_xid/;

    my $xid = new_xid();    # e.g. 'k7Qm3xT9pR'
    is_xid($xid) or die;

=head1 DESCRIPTION

users.id would let anybody iterate through everybody's lists, so the
shareable /users/:xid URL uses this instead: 10 random characters from the
base58 alphabet (no 0, O, I or l, so it's easy to read out loud). That's
about 4 x 10^17 possibilities, so guessing one isn't practical.

=cut

package kg::Tlociu::Util::Xid;

use 5.16.0;
use warnings;

use Crypt::URandom qw/urandom/;
use Exporter 'import';
our @EXPORT_OK = qw/new_xid is_xid/;

my @Alphabet = split //, '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
my $Xid_length = 10;

sub new_xid {
    my $xid = '';
    while (length $xid < $Xid_length) {
        foreach my $byte (unpack 'C*', urandom($Xid_length)) {
            # skip the top of the range so every character is equally likely
            next if $byte >= 4 * @Alphabet;
            $xid .= $Alphabet[ $byte % @Alphabet ];
            last if length $xid == $Xid_length;
        }
    }
    return $xid;
}

sub is_xid {
    my ($s) = @_;
    return defined $s && $s =~ /^[1-9A-HJ-NP-Za-km-z]{$Xid_length}$/;
}

1;
