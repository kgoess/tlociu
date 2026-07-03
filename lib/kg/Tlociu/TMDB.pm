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

sub movie { return kg::Tlociu::TMDB::Movie->new( session => shift->session, @_ ); }

1;
