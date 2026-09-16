#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";


# use this block if you don't need middleware, and only have a single target Dancer app to run here
use kg::Tlociu;

kg::Tlociu->to_app;

=begin comment
# use this block if you want to include middleware such as Plack::Middleware::Deflater

use kg::Tlociu;
use Plack::Builder;

builder {
    enable 'Deflater';
    kg::Tlociu->to_app;
}

=end comment

=cut

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

