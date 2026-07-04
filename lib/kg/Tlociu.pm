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

use feature 'try';
no warnings 'experimental::try';

use DateTime;
use Dancer2;
use Dancer2::Plugin::DBIx::Class;

use kg::Tlociu::TMDB;

our $VERSION = '0.1';

my $apikey = `cat ~/.tmdb`;
chomp $apikey;
my $TMDB = kg::Tlociu::TMDB->new(apikey => $apikey, debug => 1);

# get / front page, list entries
# (maybe should be /entry/ ?)
get '/' => sub {
    my @entries = resultset('Entry')->search({ user_id => 1 })->all;
    my %posters;
    foreach my $entry (@entries) {
        my $movie = $TMDB->movie(id => $entry->tmdb_id);
        $movie->init_from_db(resultset('Movie'));
        $posters{$entry->id} = $movie->poster;
    }
    template 'index', {
        entries  => \@entries,
        posters  => \%posters,
        base_url => 'https://image.tmdb.org/t/p/',
    };
};

# handles the AJAX search from /entry/create-search
post '/search-title' => sub {
     my $title = body_parameters->get('title');
     say STDERR "incoming title is $title";

    my @watchlist_results = resultset('Entry')->search({
        user_id => 1,
        title_lc => { like => lc("%$title%") },
    });

    my @watchlist_entries;
    foreach my $res (@watchlist_results) {
        my $movie = $TMDB->movie(id => $res->tmdb_id);
        $movie->init_from_db(resultset('Movie'));
        push @watchlist_entries, {
            title           => $res->title,
            id              => $res->id,
            created_at      => $res->created_at->ymd,
            watchlist_notes => $res->watchlist_notes,
            poster_img      => 'https://image.tmdb.org/t/p/' . $movie->poster,
        }
    }

    send_as JSON => {
        watchlist_entries => \@watchlist_entries,
    };
};

# get (basic entry display)
# :id must be typed as Int or this route also swallows GET /entry/create,
# since Dancer2 matches routes in declaration order
get '/entry/:id[Int]' => sub {
    my $id = route_parameters->get('id');
    my $entry = resultset('Entry')->search({ id => $id, user_id => 1 })->first;
    my $movie = $TMDB->movie(id => $entry->tmdb_id);
    $movie->init_from_db(resultset('Movie'));

    template 'entry/index', {
       entry => $entry,
       movie => $movie,
       # from config "secure_base_url": "https://image.tmdb.org/t/p/",
       # "poster_sizes": [
       #    "w92",
       #    "w154",
       #    "w185",
       #    "w342",
       #    "w500",
       #    "w780",
       #    "original"
       # "backdrop_sizes": [
       #    "w300",
       #    "w780",
       #    "w1280",
       #    "original"
       base_url => 'https://image.tmdb.org/t/p/',
       trailer => $movie->youtube_trailer,
   };
};

get '/entry/create-search' => sub {
    template 'entry/create-search', {
        search_url => uri_for('/search-title'),
    };
};

# create
get '/entry/create' => sub {
    var date_added => DateTime->now(time_zone => 'floating')->ymd('-');
    template 'entry/create-update', {
       post_to => uri_for('/entry/create'),
    };
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
                tmdb_id         => $params->get('tmdb_id'),
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

# update
get '/entry/:id/update' => sub {
    my $id = route_parameters->get('id');
    my $entry = resultset('Entry')->search({ id => $id, user_id => 1 })->first;
    var $_ => $entry->$_ foreach qw< title tmdb_id watchlist_notes watched_notes is_public >;
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
