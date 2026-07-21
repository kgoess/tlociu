package kg::Tlociu::Template::Plugin::YoutubeEmbed;

use 5.26.3;
use warnings;

use base qw( Template::Plugin::Filter );


my $embed = <<EOL;
<iframe width="560" height="315"
    src="<% url %>"
    title="YouTube video player"
    frameborder="0"
    allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
    referrerpolicy="strict-origin-when-cross-origin"
    allowfullscreen
>
</iframe>
EOL

sub filter {
    my ($self, $text) = @_;

    # based on https://daringfireball.net/2010/07/improved_regex_for_matching_urls
    while ($text =~ m{
        (?xi)
        (?:^|[^"])  # looking for something not in an href="" attribute
                    # or the beginning of the string
        \b
        (
          (?:
            https://(?:www\.)? # optional
            (?:
              youtube\.com|youtu\.be
            )
          )
          (?:                            # One or more:
            [^\s()<>{}\[\]]+                    # Run of non-space, non-()<>{}[]
          )+
          (?:                            # End with:
            [^\s`!()\[\]{};:'".,<>?«»“”‘’]      # not a space or one of these punct chars
          )
        )
    }xg) {
        my $this_embed = $embed;
        my $original_url = my $fixed_url = $1;
        $fixed_url =~ s{youtube.com/watch\?v=([^&]+)}{youtube.com/embed/$1}; # https://stackoverflow.com/a/25661346/514032
        $fixed_url =~ s{youtu.be/([^&/]+)}{youtube.com/embed/$1};
        $fixed_url =~ s/\bsi=.+(?:&|$)//;
        $this_embed =~ s/<% url %>/$fixed_url/;
        chomp $this_embed;
        $text =~ s/\Q$original_url/$this_embed/;
    }

    return $text;

}


1;
