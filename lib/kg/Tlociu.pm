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

Connecting this to
https://developer.themoviedb.org/reference/intro/getting-started will let me
answer the question, "what do I want to watch tonight?"

This uses kg::Tlociu::TMDB as a rapper around the TMDB library from CPAN. That
library doesn't cache HTTP requests and is unnecessarily profligate in making
them. The wrapper also also me to store the lookups in SQLite so as not to have
to repeat them at all.

=head1 Routes

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


=head2 get /

get / front page, list entries
(maybe should be /entry/ ?)

=cut

get '/' => sub {
    my @entries = resultset('Entry')->search(
        { user_id => 1 },
        { order_by => [ qw/watched title/ ] },
    )->all;
    my %posters;
    foreach my $entry (@entries) {
        # TODO might be faster/easier to store the poster in the entries table
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

=head2 post /search-title

Handles the AJAX search for title from the /entry/create-search page.

The results are formatted and displayed on the page by javascript in
views/entry/create-search.tt.

=cut

post '/search-title' => sub {
    my $title = body_parameters->get('title');

    # first search for any existing watchlist entries so they don't get dups
    my @watchlist_results = resultset('Entry')->search({
        user_id => 1,
        title_lc => { like => lc("%$title%") },
    });
    my @watchlist_entries;
    foreach my $res (@watchlist_results) {
        #my $movie = $TMDB->movie(id => $res->tmdb_id);
        #$movie->init_from_db(resultset('Movie'));
        push @watchlist_entries, {
            title           => $res->title,
            id              => $res->id,
            created_at      => $res->created_at->ymd,
            watchlist_notes => $res->watchlist_notes,
            #poster_img      => 'https://image.tmdb.org/t/p/' . $movie->poster,
        }
    }
    my %on_watchlist;
    $on_watchlist{$_->tmdb_id} = 1 for @watchlist_results;

    # now ask TMDB directly
    my @tmdb_results = $TMDB->search->movie($title);
    @tmdb_results = grep { ! $on_watchlist{$_->{id}} } @tmdb_results;

    send_as JSON => {
        watchlist_entries => \@watchlist_entries,
        tmdb_results => \@tmdb_results,
    };
};

=head2 get /entry/12345

Display a single entry

=cut

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

=head2 get /entry/create-search

The first step in creating a new watchlist entry. This is a textbox to search
for movie title. Clicking through will lead you to /entry/create.

=cut

get '/entry/create-search' => sub {
    template 'entry/create-search', {
        search_url => uri_for('/search-title'),
        img_base_url    => 'https://image.tmdb.org/t/p/',
    };
};


=head2 get /entry/create

The second step in creating a new watchlist entry. An empty form with tmdb_id
and title already filled in as hidden inputs.

=cut

get '/entry/create' => sub {
    my $params = query_parameters();
    if ($params->{tmdb_id} && $params->{tmdb_id} =~ /^[0-9]{,20}$/) {
        my $movie = $TMDB->movie(id => $params->{tmdb_id});
        $movie->init_from_db(resultset('Movie'));
        var tmdb_id => $movie->id;
        var title => $movie->title;
    }

    var date_added => DateTime->now(time_zone => 'floating')->ymd('-');
    template 'entry/create-update', {
       post_to => uri_for('/entry/create'),
    };
};

=head2 post /entry/create

Accepts the form submission from the /entry/create page. Saves to the entries
table, checks the movies table and if necessary makes a TMDB call and to add a
row to movies.

=cut

post '/entry/create' => sub {
    my $params = body_parameters();
    var $_ => $params->{ $_ } foreach qw< title >;
    my @missing = grep { $params->{$_} eq '' } qw< tmdb_id title watchlist_notes >;
    if (@missing) {
        var missing => join ",", @missing;
        warning "Missing parameters: " . var 'missing';
        forward '/entry/create', {}, { method => 'GET' };
    }

    my $movie = $TMDB->movie(id => $params->{tmdb_id});
    $movie->init_from_db(resultset('Movie'));
    $movie->maybe_save_to_db(resultset('Movie'));

    my $entry = do {
        try {
            my %create_params = (
                user_id         => 1,
                tmdb_id         => $movie->id,
                title           => $movie->title,
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

=head2 get, post /entry/12345/update

Show page to edit an existing entry and handle the results.

=cut

get '/entry/:id/update' => sub {
    my $id = route_parameters->get('id');
    my $entry = resultset('Entry')->search({ id => $id, user_id => 1 })->first;
    var $_ => $entry->$_ foreach qw< title tmdb_id watched watchlist_notes watched_notes is_public >;
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
            watched         => $params->{watched},
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


=head2 get, post /entry/12345/delete

Asks yes/no to delete the entry and handles the result.

=cut

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
