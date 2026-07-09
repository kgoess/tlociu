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
        'TMDB' => '1.2.2',
        'YAML'       => 0,
        'Class::Method::Modifiers' => 0,
        'Dancer2'     => '2.1.0',
        'Dancer2::Plugin::DBIx::Class' => '1.1001',
        'DBIx::Class' => '0.082844',
        'DBD::SQLite' => 0,
        'DBIx::Class::Schema::Loader' => 0,
        'DateTime::Format::SQLite' => 0,
        'Locale::Language' => 0,
        'Locale::Country' => 0,
        'Moo' => 0,
        'SQL::Translator' => '1.66',
        'WWW::Form::UrlEncoded' => '0.26',
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'kg-Tlociu-*' },
);

# this should eventually go into the rpm .spec file, but doing it this way will
# let us iterate on it faster
sub MY::postamble {
    return <<'MAKE_FRAG';

# install the .psgi and other dancer2 supporting files

APPDIR=/var/www/tlociu
LIBDIR=/var/lib/tlociu

app-install:
	@if [ -n "$$(find * -name '*.sw?')" ] ; then echo -e "\n*****************\n*** Please exit vim and make sure there aren't any *.sw? files in the installation tree. ***\n*******************\n" ; false; fi
	install -d $(APPDIR) --mode 2775 --group dev
	install bin/app.psgi $(APPDIR)
	install config.yml   $(APPDIR)
	install README.md    $(APPDIR)
	install -d $(APPDIR)/environments  --mode 2775 --group dev
	install -d $(APPDIR)/views         --mode 2775 --group dev
	install -d $(APPDIR)/views/layouts --mode 2775 --group dev
	install -d $(APPDIR)/public        --mode 2775 --group dev
	install -d $(APPDIR)/public/images --mode 2775 --group dev
	install -d $(APPDIR)/public/js     --mode 2775 --group dev
	install -d $(APPDIR)/public/css    --mode 2775 --group dev
	install -d $(APPDIR)/private       --mode 2770 --group apache
	find environments -type f -exec install -Dm 664 "{}" "$(APPDIR)/{}" \;
	find views -type f -exec install -Dm 664 "{}" "$(APPDIR)/{}" \;
	find public -type f -exec install -Dm 664 "{}" "$(APPDIR)/{}" \;
	install -d $(LIBDIR)/db            --mode 2770 --group apache

# the httpd.conf requires sudo, so keeping it separate (it won't change often)
httpd-conf-install:
	@if [ ! $$(id -u) = 0 ]; then echo -e "\n*****************\n*** You need to run this with sudo: 'sudo make httpd-conf-install'***\n*******************\n" ; false; fi
	install apache/tlociu.conf /etc/httpd/conf.d/tlociu.conf
	@echo -e "\n*****************\n*** Done! Now do 'sudo systemctl restart httpd'***\n*******************\n"

MAKE_FRAG
}

