package kg::Tlociu::TMDB::Movie;
use 5.40.3;
use warnings;

use parent qw/TMDB::Movie/;

sub new {
    my ($class) = shift;

    my $self = $class->SUPER::new(@_);

    return bless $self, $class;
}

sub info {
    my ($self) = @_;

    if (!$self->{_info}) {
        $self->{_info} = $self->SUPER::info;
    }
    return $self->{_info};
}

# _cast handles both cast() and crew()
sub _cast {
    my ($self) = @_;

    if (!$self->{_cast}) {
        $self->{_cast} = $self->SUPER::_cast;
    }
    return $self->{_cast};
}

sub trailers {
    my ($self) = @_;

    if (!$self->{_trailers}) {
        $self->{_trailers} = $self->SUPER::trailers;
    }
    return $self->{_trailers};
}

sub images {
    my ($self) = @_;

    if (!$self->{_images}) {
        $self->{_images} = $self->SUPER::images;
    }
    return $self->{_images};
}

sub keywords { ... }
sub releases { ... }
sub translations { ... }
sub changes { ... }
sub version { ... }
sub alternative_titles { ... }

1;
