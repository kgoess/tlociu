=head1 NAME

=encoding utf8

kg::Tlociu::Plugin::Auth - adds auth keywords to the dancer2 DSL

=head1 SYNOPSIS

In kg::Tlociu:

    use kg::Tlociu::Plugin::Auth;

    post '/edit/' => requires_login sub {
                       ↑   ↑   ↑
        ...etc...
    }

=head1 DESCRIPTION

This uses the Dancer2 plumbing to set up some DSL auth keywords
that we can attach to our routes.

=cut

package kg::Tlociu::Plugin::Auth;
use warnings;
use 5.26.3;

use Dancer2::Plugin;

=head2 requires_login

=cut

plugin_keywords requires_login => sub {
    my ($plugin, $route_sub, @args) = @_;

    return sub {
        my ($self) = @_;

        my $user = $self->app->request->var('signed_in_as')
            or return $self->redirect($self->request->uri_for('/signin') => 303);

        $route_sub->($self, @args);
    };
};

1;
