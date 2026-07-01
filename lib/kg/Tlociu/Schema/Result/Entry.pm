use utf8;
package kg::Tlociu::Schema::Result::Entry;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

kg::Tlociu::Schema::Result::Entry

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

=head1 TABLE: C<entries>

=cut

__PACKAGE__->table("entries");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 user_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 title

  data_type: 'text'
  is_nullable: 0

=head2 watchlist_notes

  data_type: 'text'
  is_nullable: 1

=head2 date_added

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 1

=head2 watched_notes

  data_type: 'text'
  is_nullable: 1

=head2 date_watched

  data_type: 'timestamp'
  is_nullable: 1

=head2 is_deleted

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=head2 is_public

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=head2 created_at

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "title",
  { data_type => "text", is_nullable => 0 },
  "watchlist_notes",
  { data_type => "text", is_nullable => 1 },
  "date_added",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 1,
  },
  "watched_notes",
  { data_type => "text", is_nullable => 1 },
  "date_watched",
  { data_type => "timestamp", is_nullable => 1 },
  "is_deleted",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "is_public",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
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

=head1 UNIQUE CONSTRAINTS

=head2 C<user_id_title_unique>

=over 4

=item * L</user_id>

=item * L</title>

=back

=cut

__PACKAGE__->add_unique_constraint("user_id_title_unique", ["user_id", "title"]);

=head1 RELATIONS

=head2 user

Type: belongs_to

Related object: L<kg::Tlociu::Schema::Result::User>

=cut

__PACKAGE__->belongs_to(
  "user",
  "kg::Tlociu::Schema::Result::User",
  { id => "user_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2026-05-13 05:37:13
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:cqp/FzA1LnhI6AJYHQTIZQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
