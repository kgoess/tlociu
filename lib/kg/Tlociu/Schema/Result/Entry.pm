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

=head2 tmdb_id

  data_type: 'integer'
  is_nullable: 0

=head2 user_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 title

  data_type: 'text'
  is_nullable: 0

=head2 title_lc

  data_type: 'text'
  is_nullable: 0

=head2 watchlist_notes

  data_type: 'text'
  is_nullable: 1

=head2 watchlist_notes_visibility

  data_type: 'text'
  is_nullable: 1

=head2 date_added

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 1

=head2 watched

  data_type: 'boolean'
  default_value: 0
  is_nullable: 0

=head2 watched_notes

  data_type: 'text'
  is_nullable: 1

=head2 watched_notes_visibility

  data_type: 'text'
  is_nullable: 1

=head2 date_watched

  data_type: 'timestamp'
  is_nullable: 1

=head2 is_deleted

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=head2 visibility

  data_type: 'text'
  default_value: 'private'
  is_nullable: 0

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
  "user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "title",
  { data_type => "text", is_nullable => 0 },
  "title_lc",
  { data_type => "text", is_nullable => 0 },
  "watchlist_notes",
  { data_type => "text", is_nullable => 1 },
  "watchlist_notes_visibility",
  { data_type => "text", is_nullable => 1 },
  "date_added",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 1,
  },
  "watched",
  { data_type => "boolean", default_value => 0, is_nullable => 0 },
  "watched_notes",
  { data_type => "text", is_nullable => 1 },
  "watched_notes_visibility",
  { data_type => "text", is_nullable => 1 },
  "date_watched",
  { data_type => "timestamp", is_nullable => 1 },
  "is_deleted",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "visibility",
  { data_type => "text", default_value => "private", is_nullable => 0 },
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

=head2 C<user_id_tmdb_id_unique>

=over 4

=item * L</user_id>

=item * L</tmdb_id>

=back

=cut

__PACKAGE__->add_unique_constraint("user_id_tmdb_id_unique", ["user_id", "tmdb_id"]);

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


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2026-11-02 02:42:24
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:+Lot3Gi3lVeBx87nZUvYWg

use Encode qw/is_utf8 encode_utf8 decode_utf8/;


# # Hook for new inserts
sub insert {
    my $self = shift;

    # Check if a username is set, then set the lowercase version
    if (defined $self->title) {
        $self->title_lc( lc($self->title) );
    }

    return $self->next::method(@_);
}

# Hook for updates, if you want to keep it synced when the main column changes
sub update {
    my $self = shift;

    if ($self->is_column_changed('title') && defined $self->title) {
        $self->title_lc( lc($self->title) );
    }

    return $self->next::method(@_);
}

# Visibility levels, least to most visible. 'users' means other people signed
# in to tlociu.
my %VISIBILITY_RANK = (private => 0, users => 1, public => 2);

sub is_valid_visibility {
    my ($class, $visibility) = @_;
    return defined $visibility && exists $VISIBILITY_RANK{$visibility};
}

# Who can see the notes in $notes_col ('watchlist_notes' or 'watched_notes').
# A NULL ${notes_col}_visibility means "same as the entry", and notes are
# never more visible than the entry they're on.
sub notes_visibility {
    my ($self, $notes_col) = @_;

    my $visibility_col = "${notes_col}_visibility";
    my $entry_visibility = $self->visibility;
    my $notes_visibility = $self->$visibility_col // return $entry_visibility;

    return $VISIBILITY_RANK{$notes_visibility} < $VISIBILITY_RANK{$entry_visibility}
        ? $notes_visibility
        : $entry_visibility;
}

foreach my $colname (qw/title title_lc watchlist_notes watched_notes/) {
    __PACKAGE__->inflate_column($colname, {
        inflate => sub { my $s = shift; is_utf8($s) ? $s : decode_utf8($s) },
        deflate => sub { my $s = shift; is_utf8($s) ? encode_utf8($s) : $s },
    });
}

1;
