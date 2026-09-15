#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";

use kg::Tlociu;
use Plack::Builder;

builder {
    enable 'Deflater';
    enable 'Session';
    enable_if { $_[0]->{PATH_INFO} !~ m{/google-signin$} }
        'CSRFBlock';

    kg::Tlociu->to_app;
}



=begin comment
# use this block if you want to mount several applications on different path

use kg::Tlociu;
use kg::Tlociu_admin;

use Plack::Builder;

builder {
    mount '/'      => kg::Tlociu->to_app;
    mount '/admin' => kg::Tlociu_admin->to_app;
}

=end comment

=cut

