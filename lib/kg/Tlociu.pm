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

# perl-5.26.3 under rocky-8.10
# perl-5.40.2 under rocky-10
use Try::Tiny;
# use feature 'try';
# no warnings 'experimental::try';

use Crypt::URandom qw(urandom);
use DateTime;
use List::Util qw/max/;
use Digest::SHA qw(hmac_sha256_hex);
use Dancer2;
use Dancer2::Plugin::DBIx::Class;
use Locale::Language qw/code2language/;
use Switch::Plain qw/sswitch/;


use kg::Tlociu::FederatedAuth;
use kg::Tlociu::Plugin::Auth; # implements requires_login
use kg::Tlociu::Util::Cookie qw/LoginMethod LoginSession GoogleToken CSRFToken AppleToken/;
use kg::Tlociu::Util::Xid qw/is_xid/;
use kg::Tlociu::Schema::Result::Entry; # for is_valid_visibility
use kg::Tlociu::Schema::Result::Tag;
use kg::Tlociu::TMDB;

our $VERSION = '0.1';

my $Entry = 'kg::Tlociu::Schema::Result::Entry';
my $Tag   = 'kg::Tlociu::Schema::Result::Tag';

my $tmdb_apikey = load_tmdb_apikey();
my $TMDB = kg::Tlociu::TMDB->new(apikey => $tmdb_apikey, debug => config->{tmdb_debug});

=head2 get /

get / front page, list entries
(maybe should be /entry/ ?)

=cut

get '/' => requires_login sub {
    my $current_user = var 'signed_in_as';
    return show_list($current_user, 'private', '/',
        share_url => $current_user->xid && uri_for('/users/' . $current_user->xid),
    );
};

=head2 get /users/:xid

A user's list as the viewer is allowed to see it: their public entries for
anybody, plus their 'users' entries if you're signed in, or everything if it's
your own list. This is the link from "Share my list". Doesn't require login.

Both lists can be filtered by tag, e.g. /?tag=horror&tag=Kurosawa shows
entries with both tags.

=cut

get '/users/:xid' => sub {
    my $owner = owner_from_xid(route_parameters->get('xid'));
    if (!$owner) {
        status 'not_found';
        return "No list found at that address";
    }
    my $viewer_level = viewer_level($owner);
    return show_list($owner, $viewer_level, '/users/' . $owner->xid,
        read_only  => 1,
        list_owner => $owner->username,
        title      => $owner->username . "'s list",
        tags_url   => uri_for('/users/' . $owner->xid . '/tags'),
    );
};

sub owner_from_xid {
    my ($xid) = @_;
    return is_xid($xid) && resultset('User')->search({
        xid        => $xid,
        is_deleted => 0,
    })->first;
}

# 'private' for the owner (sees everything), 'users' for anybody else signed
# in, 'public' for everybody else
sub viewer_level {
    my ($owner) = @_;
    my $viewer = var 'signed_in_as';
    return !$viewer                  ? 'public'
         : $viewer->id == $owner->id ? 'private'
         :                             'users';
}

# Renders $owner's list as seen by a viewer at $viewer_level, filtered by any
# ?tag= params. $list_path is where this list lives, for the tag links.
sub show_list {
    my ($owner, $viewer_level, $list_path, %template_params) = @_;

    my ($tag_search, $tag_filter) = tag_filter($owner, $viewer_level, $list_path);
    my @rows = resultset('Entry')->search(
        {
            'me.user_id'    => $owner->id,
            'me.is_deleted' => 0,
            'me.visibility' => { -in => $Entry->visibilities_seen_by($viewer_level) },
            %$tag_search,
        },
        { order_by => [ qw/me.watched me.title/ ] },
    )->all;
    my ($movies, $posters) = load_movies(\@rows);
    my $tags_by_entry = $Tag->tags_by_entry(schema, $owner->id, $viewer_level);

    # Only hand the template what this viewer may see, so a template change
    # can't leak notes or tags they shouldn't see.
    my @entries = map {
        my $row = $_;
        +{
            (map { $_ => $row->$_ } qw< id title watched date_added date_watched >),
            (map { $_ => $row->notes_seen_by($_, $viewer_level) ? $row->$_ : undef }
                qw< watchlist_notes watched_notes >),
            tags => [ map { tag_for_template($_, $viewer_level) }
                @{ $tags_by_entry->{ $row->id } || [] } ],
        };
    } @rows;

    my @filter_names = $tag_filter ? @{ $tag_filter->{names} } : ();
    my %active = map { lc($_) => 1 } @filter_names;
    my @filter_tags = map {
        +{
            name       => $_->{name},
            count      => $_->{count},
            active     => $active{ lc $_->{name} },
            filter_url => uri_for($list_path, {
                tag => [ @filter_names, $_->{name} ],
            }),
        }
    } $Tag->counts(schema, $owner->id, $viewer_level);

    return template 'index', {
        entries     => \@entries,
        movies      => $movies,
        posters     => $posters,
        base_url    => 'https://image.tmdb.org/t/p/',
        list_path   => $list_path,
        tag_filter  => $tag_filter,
        filter_tags => \@filter_tags,
        %template_params,
    };
}

# Only the owner gets to see each tag's visibility
sub tag_for_template {
    my ($tag, $viewer_level) = @_;
    return {
        name => $tag->name,
        ($viewer_level eq 'private' ? (visibility => $tag->visibility) : ()),
    };
}

# The ?tag= filter for the entry lists. Returns ($search, $filter): $search
# is conditions for the entries search, $filter is for the template, with the
# tag names, links that drop each one, and a link to clear them all.
#
# Tags the viewer can't see match nothing, same as tags that don't exist, so
# the filter can't be used to find out the names of private tags.
sub tag_filter {
    my ($owner, $viewer_level, $list_path) = @_;

    my (@names, %seen);
    foreach my $raw (query_parameters->get_all('tag')) {
        my ($name, $err) = $Tag->normalize_name($raw);
        next if $err || $name eq '' || $seen{lc $name}++;
        push @names, $name;
    }
    return {}, undef unless @names;

    my (@conditions, $matches_nothing);
    foreach my $name (@names) {
        my $tag = $Tag->find_for_user(schema, $owner->id, $name);
        if (!$tag || !$tag->seen_by($viewer_level)) {
            $matches_nothing = 1;
            last;
        }
        push @conditions, { 'me.id' => { -in =>
            resultset('EntryTag')->search({ tag_id => $tag->id })
                ->get_column('entry_id')->as_query
        } };
    }

    my $filter = {
        names     => \@names,
        multiple  => @names > 1,
        clear_url => uri_for($list_path),
        tags      => [ map {
            my $name = $_;
            my @rest = grep { $_ ne $name } @names;
            +{
                name       => $name,
                remove_url => @rest ? uri_for($list_path, { tag => \@rest })
                                    : uri_for($list_path),
            };
        } @names ],
    };
    my $search = $matches_nothing ? { 'me.id' => undef } : { -and => \@conditions };
    return $search, $filter;
}

# Returns hashrefs of entry id => kg::Tlociu::TMDB::Movie and entry id =>
# poster path for the given entries.
sub load_movies {
    my ($entries) = @_;

    my (%movies, %posters);
    foreach my $entry (@$entries) {
        # TODO might be faster/easier to store the poster in the entries table
        my $movie = $TMDB->movie(id => $entry->tmdb_id);
        $movie->init_from_db(resultset('Movie'));
        $posters{$entry->id} = $movie->poster;
        $movies{$entry->id} = $movie;
    }
    return \%movies, \%posters;
}

=head2 get /tags, post /tags/12345, post /tags/12345/delete

Your tag cloud, plus a list of all your tags where you can rename them, set
who can see each one, or delete them.

=cut

get '/tags' => requires_login sub {
    my $current_user = var 'signed_in_as';

    my @counts = $Tag->counts(schema, $current_user->id, 'private');
    my %count_for = map { $_->{id} => $_->{count} } @counts;
    my @tags = map {
        +{
            id         => $_->id,
            name       => $_->name,
            visibility => $_->visibility,
            count      => $count_for{ $_->id } // 0,
        }
    } resultset('Tag')->search(
        { user_id => $current_user->id },
        { order_by => 'name_lc' },
    )->all;

    template 'tags', {
        title        => 'Tags',
        heading      => 'Your tags',
        cloud        => tag_cloud('/', @counts),
        manage_tags  => \@tags,
        current_csrf => cookie(CSRFToken),
    };
};

post '/tags/:id[Int]' => requires_login sub {
    my $tag = own_tag(route_parameters->get('id'))
        or return not_found_tag();
    my $params = body_parameters();

    my ($name, $err) = $Tag->normalize_name($params->{name});
    $err ||= 'Tag names can\'t be empty' if $name eq '';
    $err ||= 'Invalid visibility' unless $Entry->is_valid_visibility($params->{visibility});
    if (!$err) {
        my $other = $Tag->find_for_user(schema, $tag->user_id, $name);
        $err = qq{You already have a tag called "} . $other->name . '"'
            if $other && $other->id != $tag->id;
    }
    if ($err) {
        var error_message => $err;
        warning $err;
        forward '/tags', {}, { method => 'GET' };
    }

    $tag->update({ name => $name, visibility => $params->{visibility} });
    redirect uri_for '/tags';
};

post '/tags/:id[Int]/delete' => requires_login sub {
    my $tag = own_tag(route_parameters->get('id'))
        or return not_found_tag();
    $tag->delete;
    redirect uri_for '/tags';
};

=head2 get /users/:xid/tags

Someone's tag cloud, with only the tags and entries you may see.

=cut

get '/users/:xid/tags' => sub {
    my $owner = owner_from_xid(route_parameters->get('xid'));
    if (!$owner) {
        status 'not_found';
        return "No list found at that address";
    }
    my $list_path = '/users/' . $owner->xid;
    template 'tags', {
        title    => $owner->username . "'s tags",
        heading  => $owner->username . "'s tags",
        cloud    => tag_cloud($list_path, $Tag->counts(schema, $owner->id, viewer_level($owner))),
        list_url => uri_for($list_path),
    };
};

sub own_tag {
    my ($id) = @_;
    return resultset('Tag')->search({
        id      => $id,
        user_id => (var 'signed_in_as')->id,
    })->first;
}

sub not_found_tag {
    status 'not_found';
    return "No such tag";
}

# Adds a size from 1 to 5 to each of @counts (from $Tag->counts), on a log
# scale so one huge tag doesn't make all the others tiny, and a link to the
# list at $list_path filtered by that tag.
# (CORE::log because Dancer2's log keyword is the logger.)
sub tag_cloud {
    my ($list_path, @counts) = @_;

    my $max = max(1, map { $_->{count} } @counts);
    return [ map {
        +{
            %$_,
            size => $max == 1 ? 2 : 1 + int(4 * CORE::log($_->{count}) / CORE::log($max) + 0.5),
            url  => uri_for($list_path, { tag => $_->{name} }),
        }
    } @counts ];
}

=head2 get /search-title

Handles the AJAX search for title from the /entry/create-search page.

The results are formatted and displayed on the page by javascript in
views/entry/create-search.tt.

=cut

get '/search-title' => requires_login sub {
    my $title = query_parameters->get('title');
    my $current_user = var 'signed_in_as';

    # first search for any existing watchlist entries so they don't get dups
    my @watchlist_results = resultset('Entry')->search({
        user_id => $current_user->id,
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
    $_->{original_language_name} = code2language($_->{original_language}) // 'none'
        for @tmdb_results;
    # origin_country isn't in these search results, bummer

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
get '/entry/:id[Int]' => requires_login sub {
    my $id = route_parameters->get('id');
    my $current_user = var 'signed_in_as';
    my $entry = resultset('Entry')->search({
        id => $id,
        user_id => $current_user->id,
    })->first;

    my $movie = $TMDB->movie(id => $entry->tmdb_id);
    $movie->init_from_db(resultset('Movie'));

    template 'entry/index', {
       entry => $entry,
       movie => $movie,
       tags  => [ map { tag_for_template($_, 'private') }
           $entry->tags->search({}, { order_by => 'tag.name_lc' })->all ],
       # from /config "secure_base_url": "https://image.tmdb.org/t/p/",
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

get '/entry/create-search' => requires_login sub {
    template 'entry/create-search', {
        search_url => uri_for('/search-title'),
        img_base_url    => 'https://image.tmdb.org/t/p/',
    };
};


=head2 get /entry/create

The second step in creating a new watchlist entry. An empty form with tmdb_id
and title already filled in as hidden inputs.

=cut

get '/entry/create' => requires_login sub {
    my $params = query_parameters();
    if ($params->{tmdb_id} && $params->{tmdb_id} =~ /^[0-9]{0,20}$/) {
        my $movie = $TMDB->movie(id => $params->{tmdb_id});
        $movie->init_from_db(resultset('Movie'));
        var tmdb_id => $movie->id;
        var title => $movie->title;
    }

    var date_added => DateTime->now(time_zone => 'floating')->ymd('-');
    # New entries' notes start out private. Only here, not in the template,
    # because an empty value means "same as entry" on existing entries.
    var $_ => 'private' foreach qw< watchlist_notes_visibility watched_notes_visibility >;
    template 'entry/create-update', {
       post_to => uri_for('/entry/create'),
       current_csrf => cookie(CSRFToken),
       user_tags => user_tag_names(var 'signed_in_as'),
    };
};

=head2 post /entry/create

Accepts the form submission from the /entry/create page. Saves to the entries
table, checks the movies table and if necessary makes a TMDB call and to add a
row to movies.

=cut

post '/entry/create' => requires_login sub {
    my $params = body_parameters();
    var $_ => $params->{ $_ } foreach qw< title >;
    my @missing = grep { $params->{$_} eq '' } qw< tmdb_id title watchlist_notes >;
    if (@missing) {
        my $err = "Missing parameters: ".join ", ", @missing;
        var error_message => $err;
        warning $err;
        forward '/entry/create', $params, { method => 'GET' };
    }
    if (my $err = visibility_params_error($params)) {
        var error_message => $err;
        warning $err;
        forward '/entry/create', $params, { method => 'GET' };
    }
    my ($tag_names, $tags_err) = $Tag->parse_names($params->{tags});
    if ($tags_err) {
        var error_message => $tags_err;
        warning $tags_err;
        forward '/entry/create', $params, { method => 'GET' };
    }

    my $current_user = var 'signed_in_as';
    my @existing = resultset('Entry')->search({
        user_id => $current_user->id,
        tmdb_id => $params->{tmdb_id},
    });
    if (@existing) {
        var error_message => "You already have an entry in your list for that movie.";
        forward '/entry/create', $params, { method => 'GET' };
    }

    my $movie = $TMDB->movie(id => $params->{tmdb_id});
    $movie->init_from_db(resultset('Movie'));
    $movie->maybe_save_to_db(resultset('Movie'));

    my $entry = do {
        try {
            my %create_params = (
                user_id         => $current_user->id,
                tmdb_id         => $movie->id,
                title           => $movie->title,
                watchlist_notes => $params->get('watchlist_notes'),
                date_added      => $params->get('date_added'),
                date_watched    => $params->get('date_watched') || undef,
                watched         => $params->{watched},
                watched_notes   => $params->get('watched_notes'),
                visibility      => $params->{visibility},
                watchlist_notes_visibility => $params->{watchlist_notes_visibility} || undef,
                watched_notes_visibility   => $params->{watched_notes_visibility} || undef,
            );
            my $entry = resultset('Entry')->create(\%create_params);
            $entry->set_tag_names($tag_names);
            $entry;
        }
        # 5.40 try/catch catch( $e ) {
        catch {
            my $e = $_;
            error "Database error: $e";
            var error_message => 'A database error occurred; your entry could not be created.';
            forward '/entry/create', $params, { method => 'GET' };
        };
    };
    redirect uri_for "/entry/" . $entry->id; # redirect does not need a return
};

=head2 get, post /entry/12345/update

Show page to edit an existing entry and handle the results.

=cut

get '/entry/:id/update' => requires_login sub {
    my $id = route_parameters->get('id');
    my $current_user = var 'signed_in_as';
    my $entry = resultset('Entry')->search({
        id => $id,
        user_id => $current_user->id,
    })->first;
    if( !$entry ) {
        status 'not_found';
        return "Attempt to load non-existent entry $id";
    }
    var $_ => $entry->$_ foreach qw<
        title tmdb_id watched watchlist_notes watched_notes
        visibility watchlist_notes_visibility watched_notes_visibility
    >;
    foreach my $field (qw< date_added date_watched >) {
        next unless $entry->$field;
        var $field => DateTime::Format::SQLite->format_date($entry->$field);
    }
    var tags => join ', ', map { $_->name }
        $entry->tags->search({}, { order_by => 'tag.name_lc' })->all;
    if (my $set_watched = query_parameters->get('set_watched')) {
        var changing_watched => $set_watched;
        if ($set_watched eq 'yes') {
            var watched => 'checked';
        } else {
            var watched => undef;
        }
    }
    template 'entry/create-update', {
       post_to => uri_for("/entry/$id/update"),
       current_csrf => cookie(CSRFToken),
       user_tags => user_tag_names($current_user),
    };
};
post '/entry/:id/update' => requires_login sub {
    my $id = route_parameters->get('id');
    my $current_user = var 'signed_in_as';
    my $entry = resultset('Entry')->search({
        id => $id,
        user_id => $current_user->id
    })->first;
    if( !$entry ) {
        status 'not_found';
        return "Attempt to update non-existent entry $id";
    }
    my $params = body_parameters();
    var $_ => $params->{ $_ } foreach qw<
        title watchlist_notes date_added watched_notes date_watched
        visibility watchlist_notes_visibility watched_notes_visibility
    >;
    my @missing = grep { $params->{$_} eq '' } qw< title >;
    if( @missing ) {
        var missing => join ",", @missing;
        warning "Missing parameters: " . var 'missing';
        forward "/entry/$id/update", {}, { method => 'GET' };
    }
    if (my $err = visibility_params_error($params)) {
        var error_message => $err;
        warning $err;
        forward "/entry/$id/update", {}, { method => 'GET' };
    }
    my ($tag_names, $tags_err) = $Tag->parse_names($params->{tags});
    if ($tags_err) {
        var error_message => $tags_err;
        warning $tags_err;
        forward "/entry/$id/update", {}, { method => 'GET' };
    }
    try {
        $entry->update({
            title           => $params->{title},
            watchlist_notes => $params->{watchlist_notes},
            date_added      => $params->{date_added},
            date_watched    => $params->{date_watched} || undef,
            watched         => $params->{watched},
            watched_notes   => $params->{watched_notes},
            visibility      => $params->{visibility},
            watchlist_notes_visibility => $params->{watchlist_notes_visibility} || undef,
            watched_notes_visibility   => $params->{watched_notes_visibility} || undef,
        });
        # leave the tags alone if the form didn't have a tags field
        $entry->set_tag_names($tag_names) if defined $params->{tags};
    }
    # 5.40 try/catch catch( $e ) {
    catch {
        my $e = $_;
        error "Database error: $e";
        var error_message => 'A database error occurred; your entry could not be updated',
        forward "/entry/$id/update", {}, { method => 'GET' };
    };
    redirect uri_for "/entry/" . $entry->id; # redirect does not need a return
};


=head2 get, post /entry/12345/delete

Asks yes/no to delete the entry and handles the result.

=cut

get '/entry/:id/delete' => requires_login sub {
    my $id = route_parameters->get('id');
    my $current_user = var 'signed_in_as';
    my $entry = resultset('Entry')->search({
        user_id => $current_user->id,
        id => $id,
    })->first
        or halt qq{No entry found for id "$id"};
    template 'entry/delete', {
       id => $id,
       title => $entry->title,
       current_csrf => cookie(CSRFToken),
   };
};
post '/entry/:id/delete' => sub {
    my $id = route_parameters->get('id');
    my $current_user = var 'signed_in_as';
    # Always default to not destroying data
    my $delete_it = body_parameters->get('delete_it')
        or redirect uri_for "/entry/$id";
    if ($delete_it ne 'yes') {
        redirect uri_for "/entry/$id";
    }
    my $entry = resultset('Entry')->search({
        user_id => $current_user->id,
        id => $id,
     })->first
        or halt qq{No entry found for id "$id"} ;
    $entry->delete;
    redirect uri_for "/";
};

=head2 get /signin

=cut

get '/signin' => sub {
    template signin => {
        google_client_id => config->{google_client_id},
        apple_client_id  => config->{apple_client_id},
    };
};

=head2 get /privacy

The privacy policy. Google's OAuth consent-screen verification requires this
to be publicly accessible (no login) on the app's own domain, so no
requires_login here.

=cut

get '/privacy' => sub {
    template privacy => {
        title => 'Privacy Policy',
    };
};

=head2 get /terms

The terms of service, also public for the Google OAuth consent screen.

=cut

get '/terms' => sub {
    template terms => {
        title => 'Terms of Service',
    };
};

=head2 get /signout

=cut

get '/signout' => sub {
    cookie LoginSession, '', expires => "-1 hours";
    cookie LoginMethod,  '', expires => "-1 hours";
    redirect '/signin', 302;
};


=head2 before hook for login

This "before" hook is set up to catch every dancer2 request, check for the
LoginMethod cookie and associated login cookie, and if they check out then put
the "signed_in_as" user resultset object in the var() stash.

TODO: It also creates an kg::Tlociu::Auditor in the var() stash under "auditor".

See kg::Tlociu::FederatedAuth for what sets these cookies.

We might not need this for static assets like images or css. Could screen
on the Accept header, Content Negotiation.

=cut

hook before => sub {
    my $login_cookie = cookie LoginMethod
        or return;

    my $login_method = $login_cookie->value;

    my $signed_in_as;

    sswitch ($login_method) {
        case 'google': {
            my $google_token = cookie GoogleToken
                or return;
            my ($user, $err) = kg::Tlociu::FederatedAuth
                ->check_google_auth(
                    $google_token, # the jwt
                    schema,
                    config->{google_oauth_keys_cache_dir},
                    config->{google_client_id},
                );
            if ($err) {
                my ($code, $msg) = @$err;
                warn qq{hook before check_google_auth: "$msg" for token '$google_token"};
                return;
            }
            $signed_in_as = $user;
        }
        case 'apple': {
            my $apple_token = cookie AppleToken
                or return;
            my ($user, $err) = kg::Tlociu::FederatedAuth
                ->check_apple_auth(
                    $apple_token, # the jwt
                    schema,
                    config->{apple_oauth_keys_cache_dir},
                    config->{apple_client_id},
                );
            if ($err) {
                my ($code, $msg) = @$err;
                warn qq{hook before check_apple_auth: "$msg" for token '$apple_token"};
                return;
            }
            $signed_in_as = $user;
        }
        #case 'session': {
        #    # this handles both facebook and bacds signins
        #    my $session_cookie = cookie LoginSession
        #        or return;
        #
        #    my ($programmer, $err) = bacds::Scheduler::FederatedAuth
        #        ->check_session_cookie($session_cookie);
        #
        #    if ($err) {
        #        warn qq{hook before session: "$err" for $session_cookie};
        #        return;
        #    };
        #
        #    $signed_in_as = $programmer;
        #}
    }
    if ($signed_in_as) {
        var signed_in_as => $signed_in_as;
        #var auditor => bacds::Scheduler::Auditor->new(
        #    programmer => $signed_in_as,
        #    http_method => request->method,
        #);
    }
};

=head2 before hooks for CSRF

=cut


# --- generate CSRF token for the frontend context ---
hook before => sub {
    # If the cookie doesn't exist, generate a stateless CSRF token
    if (!cookie CSRFToken) {
        # 1. Generate 32 bytes of secure random data encoded as hex
        my $random_val = unpack("H*", urandom(32));

        # 2. Cryptographically sign the token using an HMAC
        my $csrf_secret = config->{csrf_secret};
        my $signature = hmac_sha256_hex($random_val, $csrf_secret);
        my $final_token = "$random_val.$signature";

        # 3. Drop the cookie. It must be accessible via frontend JS
        # so HttpOnly is omitted, but SameSite and Secure protect it.
        cookie CSRFToken() => $final_token, # the () is required here
            path     => '/',
            secure   => 1,             # Requires HTTPS
            same_site => 'Lax';        # Protects cross-origin requests
    }
};

# --- Middleware: Validate CSRF token on state-changing requests ---
hook before => sub {
    my $method = request->method;
    my $path = request->path;

    # Only validate state-changing HTTP methods
    # Need to skip /*-signin, which has their own csrf protections
    if ($method =~ /^(POST|PUT|DELETE|PATCH)$/i &&
        $path !~ m{/google-signin$}             &&
        $path !~ m{/apple-signin$}
    ) {

        # Extract token from the incoming custom request header
        my $submitted_token = request_header('X-CSRF-Token')
                           || body_parameters->get('csrf_token');

        # Extract token from the browser cookie
        my $cookie = cookie CSRFToken;

        if (!$cookie) {
            send_error("CSRF Validation Failed: Missing cookie.", 403);
        }

        my $cookie_token = $cookie->value();

        # Halt if either token is completely missing
        if (!$submitted_token || !$cookie_token) {
            send_error("CSRF Validation Failed: Missing token.", 403);
        }

        # Stateless Security Rule 1: The header token must exactly match the cookie token
        if ($submitted_token ne $cookie_token) {
            send_error("CSRF Validation Failed: Token mismatch.", 403);
        }

        # Stateless Security Rule 2: Verify the cryptographic signature on the server side
        my ($random_val, $signature) = split(/\./, $cookie_token);
        my $csrf_secret = config->{csrf_secret};
        my $expected_signature = hmac_sha256_hex($random_val, $csrf_secret);

        if (!$signature || $signature ne $expected_signature) {
            send_error("CSRF Validation Failed: Invalid token signature.", 403);
        }
    }
};

=head2 /google-signin

login credential checking redirector

A request to /signin will show a login-with-google button and
others.

Click on that and you'll get a "Sign in with Google: Choose
an account to continue to..." page.

Continuing with that will redirect you here.

This endpoint will verify your credential information and set up a
session.

See also kg::Tlociu::FederatedAuth->check_google_auth.

=cut

post '/google-signin' => sub {
    my $jwt = params->{credential}
        or send_error 'missing parameter "credential"' => 400;

    my ($res, $err) = kg::Tlociu::FederatedAuth->check_google_auth(
        $jwt,
        schema,
        config->{google_oauth_keys_cache_dir},
        config->{google_client_id},
    );

    if ($err) {
        my ($code, $msg) = @$err;
        warning "google-signin->check_google_auth returned error $code $msg\n";
        send_error $msg => $code;
    }

    cookie GoogleToken, $jwt,     expires => "1 week";
    cookie LoginMethod, 'google', expires => "1 week";
    redirect '/' => 303;
};

=head2 /apple-signin

Same as /google-signin but for the Sign in with Apple button.

The signin page's AppleID.auth.init() is configured with usePopup:false and
this endpoint as the redirectURI, so after the user authenticates with Apple,
Apple POSTs form params here: "id_token" (a JWT), "code", "state", and (first
sign-in only) "user".

See also kg::Tlociu::FederatedAuth->check_apple_auth.

=cut

post '/apple-signin' => sub {
    my $jwt = params->{id_token}
        or send_error 'missing parameter "id_token"' => 400;

    my ($res, $err) = kg::Tlociu::FederatedAuth->check_apple_auth(
        $jwt,
        schema,
        config->{apple_oauth_keys_cache_dir},
        config->{apple_client_id},
    );

    if ($err) {
        my ($code, $msg) = @$err;
        warning "apple-signin->check_apple_auth returned error $code $msg\n";
        send_error $msg => $code;
    }

    cookie AppleToken,  $jwt,     expires => "72 hours";
    cookie LoginMethod, 'apple',  expires => "72 hours";
    redirect '/' => 303;
};

# Checks the visibility form params, returns an error message if any are bad.
# An empty notes visibility means "same as the entry".
sub visibility_params_error {
    my ($params) = @_;

    my @bad;
    push @bad, 'visibility'
        unless $Entry->is_valid_visibility($params->{visibility});
    foreach my $field (qw< watchlist_notes_visibility watched_notes_visibility >) {
        my $value = $params->{$field};
        next if !defined $value || $value eq '';
        push @bad, $field unless $Entry->is_valid_visibility($value);
    }
    return @bad ? "Invalid visibility for: " . join ", ", @bad : '';
}

# All of $user's tag names, for the suggestions on the entry form
sub user_tag_names {
    my ($user) = @_;
    return [ map { $_->name } resultset('Tag')->search(
        { user_id => $user->id },
        { order_by => 'name_lc' },
    )->all ];
}

sub load_tmdb_apikey {
    my $apikey_path = config->{tmdb_apikey}
        or die "please configure tmpdb_apikey in ".app()->environment.".yml or config.yml";
    $apikey_path =~ s/~/$ENV{HOME}/;
    open my $apikey_fh, '<', $apikey_path
        or die "can't read apikey file at $apikey_path: $!";
    my $apikey = <$apikey_fh>;
    close $apikey_fh;
    chomp $apikey;
    return $apikey;
}


true;
