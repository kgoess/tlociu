use utf8;
package kg::Tlociu::Schema::Result::Movie;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

kg::Tlociu::Schema::Result::Movie

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime");

=head1 TABLE: C<movies>

=cut

__PACKAGE__->table("movies");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 tmdb_id

  data_type: 'integer'
  is_nullable: 0

=head2 title

  data_type: 'text'
  is_nullable: 0

=head2 info

  data_type: 'text'
  is_nullable: 1

=head2 movie_cast

  data_type: 'text'
  is_nullable: 1

=head2 trailers

  data_type: 'text'
  is_nullable: 1

=head2 images

  data_type: 'text'
  is_nullable: 1

=head2 keywords

  data_type: 'text'
  is_nullable: 1

=head2 releases

  data_type: 'text'
  is_nullable: 1

=head2 translations

  data_type: 'text'
  is_nullable: 1

=head2 changes

  data_type: 'text'
  is_nullable: 1

=head2 version

  data_type: 'text'
  is_nullable: 1

=head2 alternative_titles

  data_type: 'text'
  is_nullable: 1

=head2 is_deleted

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=head2 modified_at

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 1

=head2 created_at

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "tmdb_id",
  { data_type => "integer", is_nullable => 0 },
  "title",
  { data_type => "text", is_nullable => 0 },
  "info",
  { data_type => "text", is_nullable => 1 },
  "movie_cast",
  { data_type => "text", is_nullable => 1 },
  "trailers",
  { data_type => "text", is_nullable => 1 },
  "images",
  { data_type => "text", is_nullable => 1 },
  "keywords",
  { data_type => "text", is_nullable => 1 },
  "releases",
  { data_type => "text", is_nullable => 1 },
  "translations",
  { data_type => "text", is_nullable => 1 },
  "changes",
  { data_type => "text", is_nullable => 1 },
  "version",
  { data_type => "text", is_nullable => 1 },
  "alternative_titles",
  { data_type => "text", is_nullable => 1 },
  "is_deleted",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "modified_at",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 1,
  },
  "created_at",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 1,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2026-07-03 21:14:55
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:0xfHYf/0yMkEOHe6MCaX2g

use Encode qw/is_utf8 encode_utf8 decode_utf8/;

foreach my $colname (qw/title/) {
    __PACKAGE__->inflate_column($colname, {
        inflate => sub { my $s = shift; is_utf8($s) ? $s : decode_utf8($s) },
        deflate => sub { my $s = shift; is_utf8($s) ? encode_utf8($s) : $s },
    });
}

1;
