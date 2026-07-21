
use 5.26.0;
use warnings;

use Test::More tests => 8;

use kg::Tlociu::Template::Plugin::YoutubeEmbed;

my $c = 'kg::Tlociu::Template::Plugin::YoutubeEmbed';

my $long_url = 'https://youtube.com/watch?v=vKIgSBSxUKE';
my $short_url = 'https://youtu.be/vKIgSBSxUKE';
my $expected_url = 'https://youtube.com/embed/vKIgSBSxUKE';
my $expected =
qr{\Q<iframe width="560" height="315"
    src="$expected_url"
    title="YouTube video player"
    frameborder="0"
    allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
    referrerpolicy="strict-origin-when-cross-origin"
    allowfullscreen
>
</iframe>};

like $c->filter($long_url), $expected, 'long_url at beginning of string';
like $c->filter(<<EOL), $expected, 'long_url middle of string, with punctuation at end';
foo
  bar $long_url. baz
bam
EOL
unlike $c->filter("xxx$long_url"), $expected, 'long_url needs a clean "https"';
unlike $c->filter(qq{a href="$long_url">}), $expected, 'long_url not in html attribute already';


like $c->filter($short_url), $expected, 'short_url at beginning of string';
like $c->filter(<<EOL), $expected, 'short_url middle of string, with punctuation at end';
foo
  bar $short_url. baz
bam
EOL
unlike $c->filter("xxx$short_url"), $expected, 'short_url needs a clean "https"';
unlike $c->filter(qq{a href="$short_url">}), $expected, 'short_url not in html attribute already';
