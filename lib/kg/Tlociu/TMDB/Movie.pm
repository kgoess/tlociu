=head1 NAME
=encoding utf8

kg::Tlociu::TMDB::Movie - wrapper for TMDB::Movie

=head1 SYNOPSIS

    my $TMDB = kg::Tlociu::TMDB->new(apikey => $apikey, debug => 0);
    my $movie = $TMDB->movie(id => $tmdb_id);
    say $movie->title;

=head1 DESCRIPTION

This is a wrapper subclass for TMDB::Movie from CPAN. That module is rather
naïve about how it makes API requests to tmdb.org. For instance if you request
$movie->title, $movie->year and $movie->tagline, it'll make an API request to
/movie/$id for each of those, to get the JSON blob that contains all of them,
rather than storing the JSON blob in the object. I should get around to filing
a PR for TMDB to make it that much smarter.

This wrapper also allows me to store the JSON blobs in the database so that we
don't have to go out to the API again.

=head1 METHODS

=cut

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

=head2 init_from_db

Checks in the database and initializes ourself from the data if it's present,
so that we don't have to call out to the tmdb.org API.

$resultset is a DBIx::Class resultset object, e.g. resultset('Movie') in
Dancer2's DSL.

Only info, _cast and trailers are implemented yet, just because
that's all I need so far.

=cut

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

Returns early if we were initialized from the db, otherwise saves a row to the
movies table with the json blobs we got from the tmdb.org API.

$resultset is a DBIx::Class resultset, possibly from Dancer2's DSL
resultset('Movie')

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

=head2 info

Overrides the superclass info() and stores the result in $self->{_info}.

=cut

sub info ($self) {

    if (!$self->{_info}) {
        $self->{_info} = $self->SUPER::info;
    }
    return $self->{_info};
}

=head2 info

Overrides the superclass _cast() and stores the result in $self->{_cast}.

The superclass _cast() handles both cast() and crew()

=cut

sub _cast {
    my ($self) = @_;

    if (!$self->{_cast}) {
        $self->{_cast} = $self->SUPER::_cast;
    }
    return $self->{_cast};
}

=head2 trailers

Overrides the superclass trailers() and stores the result in
$self->{_trailers}.

=cut

sub trailers {
    my ($self) = @_;

    if (!$self->{_trailers}) {
        $self->{_trailers} = $self->SUPER::trailers;
    }
    return $self->{_trailers};
}

=head2 youtube_trailer

Gets the first type eq 'Trailer' from the trailers and prepends the
https://youtu.be onto it.

=cut

sub youtube_trailer ($self) {
    my $trailers = $self->trailers;
    my $trailer = first { $_->{type} eq 'Trailer' } $trailers->{youtube}->@*;
    return 'http://youtu.be/' . $trailer->{source};
}

=head2 director

Overrides the parent class directory().

Clauded noticed that the parent class regex-matches any crew job containing "Director",
which also picks up e.g. Director of Photography, Assistant Director

=cut

sub director ($self) {
    my @names = map { $_->{name} } grep { $_->{job} eq 'Director' } $self->crew;
    return @names if wantarray;
    return \@names;
}

=head2 unimplemented: images, keywords, releases, translations, changes, version, alternative_titles

Just because I have no need of them yet.

=cut

sub images { ... }
sub keywords { ... }
sub releases { ... }
sub translations { ... }
sub changes { ... }
sub version { ... }
sub alternative_titles { ... }

1;
