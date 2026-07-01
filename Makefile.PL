use strict;
use warnings;
use ExtUtils::MakeMaker;

# Normalize version strings like 6.30_02 to 6.3002,
# so that we can do numerical comparisons on it.
my $eumm_version = $ExtUtils::MakeMaker::VERSION;
$eumm_version =~ s/_//;

WriteMakefile(
    NAME                => 'kg::Tlociu',
    AUTHOR              => q{YOUR NAME <youremail@example.com>},
    VERSION_FROM        => 'lib/kg/Tlociu.pm',
    ABSTRACT            => 'YOUR APPLICATION ABSTRACT',
    ($eumm_version >= 6.3001
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'YAML'       => 0,
        'Class::Method::Modifiers' => 0,
        'Dancer2'     => 2.1.0,
        'Dancer2::Plugin::DBIx::Class' => 2.1.0,
        'DBIx::Class' => 0.082844,
        'DBD::SQLite' => 0,
        'DBIx::Class::Schema::Loader' => 0,
        'DateTime::Format::SQLite' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'kg-Tlociu-*' },
);
