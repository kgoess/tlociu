package kg::Tlociu::TMDB::Movie;
use 5.40.3;
use warnings;

use parent qw/TMDB::Movie/;

use JSON::MaybeXS qw/encode_json decode_json/;
use List::Util qw/first/;

sub new {
    my ($class) = shift;

    my $self = $class->SUPER::new(@_);

    bless $self, $class;

    return $self;
}

sub init_from_db ($self, $resultset) {

    my $tmdb_id = $self->id;

    my $row = $resultset->search({tmdb_id => $self->id})->first
        or return;

    $self->{_initted_from_db} = 1;
    $self->{_info}      = decode_json($row->info);
    $self->{_cast}      = decode_json($row->movie_cast);
    $self->{_trailers}  = decode_json($row->trailers);

    # unused
    #$self->{_images}   = $row->images;
    #$self->{_keywords} = $row->keywords;
    #$self->{_releases} = $row->releases;
    #$self->{_translations} = $row->translations;
    #$self->{_changes} = $row->changes;
    #$self->{_version} = $row->version;
    #$self->{_alternative_titles} = $row->alternative_titles;
}

=head2 maybe_save_to_db

$resultset is from Dancer2's DSL resultset('Movie')

=cut

sub maybe_save_to_db ($self, $resultset) {

    return if $self->{_initted_from_db};

    $resultset->create({
        tmdb_id    => $self->id,
        info       => encode_json($self->info),
        title      => encode_json($self->title),
        movie_cast => encode_json($self->_cast),
        trailers   => encode_json($self->trailers),
        # unused
        # images
        # keywords
        # releases
        # translations
        # changes
        # version
        # alternative_titles
    });

    $self->{_initted_from_db} = 1;
}

sub info ($self) {

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

sub youtube_trailer ($self) {
    my $trailers = $self->trailers;
    my $trailer = first { $_->{type} eq 'Trailer' } $trailers->{youtube}->@*;
    return 'http://youtu.be/' . $trailer->{source};
}

sub images { ... }
sub keywords { ... }
sub releases { ... }
sub translations { ... }
sub changes { ... }
sub version { ... }
sub alternative_titles { ... }

1;
