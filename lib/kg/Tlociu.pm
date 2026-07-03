=head1 NAME

kg::Tlociu - track watchlist and films seen (The Language Of Cinema Is Universal)

=head1 SYNOPSIS

In bin/app.psgi:

    builder {
        kg::Tlociu->to_app;
    }

then:

    $ plackup -r bin/app.psgi

=head1 DESCRIPTION

I got frustrated with letterboxd. I just want a place to drop a note when I
hear about a film that sounds interesting with when and where I heard of it.
"Bob said watching this was the worst two hours of his life, sounds fun!"

This is a Perl web app using Dancer2 and DBIx::Class with a SQLite data
store.

Connecting this with https://www.omdbapi.com/ or
https://developer.themoviedb.org/reference/intro/getting-started will let me
answer the question, "what do I want to watch tonight?"
https://dev.to/zuplo/whats-the-best-movie-database-api-imdb-vs-tmdb-vs-omdb-b24


=cut

package kg::Tlociu;
use Dancer2;
use Dancer2::Plugin::DBIx::Class;
use feature 'try';
no warnings 'experimental::try';

our $VERSION = '0.1';

get '/' => sub {
    my @entries = resultset('Entry')->search({ user_id => 1 })->all;
    template 'index', { entries => \@entries };
};

# create
get '/entry/create' => sub {
    template 'entry/create-update', { post_to => uri_for '/entry/create' };
};
post '/entry/create' => sub {
    my $params = body_parameters();
    var $_ => $params->{ $_ } foreach qw< title >;
    my @missing = grep { $params->{$_} eq '' } qw< title >;
    if (@missing) {
        var missing => join ",", @missing;
        warning "Missing parameters: " . var 'missing';
        forward '/entry/create', {}, { method => 'GET' };
    }
    my $entry = do {
        try {
            my %create_params = (
                user_id         => 1,
                title           => $params->get('title'),
                watchlist_notes => $params->get('watchlist_notes'),
                date_added      => $params->get('date_added'),
                watched_notes   => $params->get('watched_notes'),
                date_watched    => $params->get('date_watched') || undef,
            );
            resultset('Entry')->create(\%create_params);
        }
        catch( $e ) {
            error "Database error: $e";
            var error_message => 'A database error occurred; your entry could not be created';
            forward '/entry/create', {}, { method => 'GET' };
        }
    };
    redirect uri_for "/entry/" . $entry->id; # redirect does not need a return
};

# get
get '/entry/:id' => sub {
    my $id = route_parameters->get('id');
    my $entry = resultset('Entry')->search({ id => $id, user_id => 1 })->first;
    template 'entry/index', { entry => $entry };
};

# update
get '/entry/:id/update' => sub {
    my $id = route_parameters->get('id');
    my $entry = resultset('Entry')->search({ id => $id, user_id => 1 })->first;
    var $_ => $entry->$_ foreach qw< title watchlist_notes watched_notes is_public >;
    foreach my $field (qw< date_added date_watched >) {
        next unless $entry->$field;
        var $field => DateTime::Format::SQLite->format_date($entry->$field);
    }
    template 'entry/create-update', { post_to => uri_for "/entry/$id/update" };
};
post '/entry/:id/update' => sub {
    my $id = route_parameters->get('id');
    my $entry = resultset('Entry')->search({ id => $id, user_id => 1 })->first;
    if( !$entry ) {
        status 'not_found';
        return "Attempt to update non-existent entry $id";
    }
    my $params = body_parameters();
    var $_ => $params->{ $_ } foreach qw< title watchlist_notes date_added watched_notes date_watched is_public >;
    my @missing = grep { $params->{$_} eq '' } qw< title >;
    if( @missing ) {
        var missing => join ",", @missing;
        warning "Missing parameters: " . var 'missing';
        forward "/entry/$id/update", {}, { method => 'GET' };
    }
    try {
        $entry->update({
            title           => $params->{title},
            watchlist_notes => $params->{watchlist_notes},
            date_added      => $params->{date_added},
            watched_notes   => $params->{watched_notes},
            date_watched    => $params->{date_watched} || undef,
            is_public       => $params->{is_public},
        });
    }
    catch( $e ) {
        error "Database error: $e";
        var error_message => 'A database error occurred; your entry could not be updated',
        forward "/entry/$id/update", {}, { method => 'GET' };
    }
    redirect uri_for "/entry/" . $entry->id; # redirect does not need a return
};

# delete
get '/entry/:id/delete' => sub {
    my $id = route_parameters->get('id');
    my $entry = resultset('Entry')->search({ user_id => 1, id => $id })->first
        or halt qq{No entry found for id "$id"} ;
    template 'entry/delete', { id => $id, title => $entry->title };
};
post '/entry/:id/delete' => sub {
    my $id = route_parameters->get('id');
    # Always default to not destroying data
    my $delete_it = body_parameters->get('delete_it')
        or redirect uri_for "/entry/$id";
    if ($delete_it ne 'yes') {
        redirect uri_for "/entry/$id";
    }
    my $entry = resultset('Entry')->search({ user_id => 1, id => $id })->first
        or halt qq{No entry found for id "$id"} ;
    $entry->delete;
    redirect uri_for "/";
};


true;
