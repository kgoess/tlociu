=head1 NAME

kg::Tlociu::TMDB

=head1 SYNOPSIS

    my $TMDB = kg::Tlociu::TMDB->new(apikey => $apikey, debug => 0);
    my $movie = $TMDB->movie(id => $tmdb_id);
    say $movie->title;

=head1 DESCRIPTION

This is a wrapper subclass for the TMDB library from CPAN. All it does it let
me use the kg::Tlociu::TMDB::Movie wrapper, q.v., instead of TMDB::Movie.

=cut

package kg::Tlociu::TMDB;

use 5.40.3;
use warnings;

use parent qw/TMDB/;

use kg::Tlociu::TMDB::Movie;

sub new {
    my ($class) = shift;

    my $self = $class->SUPER::new(@_);

    return bless $self, $class;
}

sub movie { return kg::Tlociu::TMDB::Movie->new(session => shift->session, @_) }

1;
