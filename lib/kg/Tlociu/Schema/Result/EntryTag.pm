use utf8;
package kg::Tlociu::Schema::Result::EntryTag;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

kg::Tlociu::Schema::Result::EntryTag

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

=head1 TABLE: C<entry_tags>

=cut

__PACKAGE__->table("entry_tags");

=head1 ACCESSORS

=head2 entry_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 tag_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "entry_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "tag_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</entry_id>

=item * L</tag_id>

=back

=cut

__PACKAGE__->set_primary_key("entry_id", "tag_id");

=head1 RELATIONS

=head2 entry

Type: belongs_to

Related object: L<kg::Tlociu::Schema::Result::Entry>

=cut

__PACKAGE__->belongs_to(
  "entry",
  "kg::Tlociu::Schema::Result::Entry",
  { id => "entry_id" },
  { is_deferrable => 0, on_delete => "CASCADE", on_update => "NO ACTION" },
);

=head2 tag

Type: belongs_to

Related object: L<kg::Tlociu::Schema::Result::Tag>

=cut

__PACKAGE__->belongs_to(
  "tag",
  "kg::Tlociu::Schema::Result::Tag",
  { id => "tag_id" },
  { is_deferrable => 0, on_delete => "CASCADE", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2026-11-02 06:04:13
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:DbkQb/fm36SOr93j3xNStw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
