use utf8;
package kg::Tlociu::Schema::Result::Tag;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

kg::Tlociu::Schema::Result::Tag

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

=head1 TABLE: C<tags>

=cut

__PACKAGE__->table("tags");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 user_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 name

  data_type: 'text'
  is_nullable: 0

=head2 name_lc

  data_type: 'text'
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
  "user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 0 },
  "name_lc",
  { data_type => "text", is_nullable => 0 },
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

=head2 C<user_id_name_lc_unique>

=over 4

=item * L</user_id>

=item * L</name_lc>

=back

=cut

__PACKAGE__->add_unique_constraint("user_id_name_lc_unique", ["user_id", "name_lc"]);

=head1 RELATIONS

=head2 entry_tags

Type: has_many

Related object: L<kg::Tlociu::Schema::Result::EntryTag>

=cut

__PACKAGE__->has_many(
  "entry_tags",
  "kg::Tlociu::Schema::Result::EntryTag",
  { "foreign.tag_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

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

=head2 entries

Type: many_to_many

Composing rels: L</entry_tags> -> entry

=cut

__PACKAGE__->many_to_many("entries", "entry_tags", "entry");


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2026-11-02 06:04:13
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:yd3p+yeGBYA/au5bkSJHXg


use Encode qw/is_utf8 encode_utf8 decode_utf8/;

my $Entry = 'kg::Tlociu::Schema::Result::Entry';

our $Max_name_length = 50;

sub insert {
    my $self = shift;
    $self->name_lc( lc $self->name ) if defined $self->name;
    return $self->next::method(@_);
}

sub update {
    my $self = shift;
    $self->set_inflated_columns(@_) if @_;
    if ($self->is_column_changed('name') && defined $self->name) {
        $self->name_lc( lc $self->name );
    }
    return $self->next::method();
}

# entry_tags has ON DELETE CASCADE, but foreign keys are only enforced where
# the connection turns on PRAGMA foreign_keys, so don't count on it
sub delete {
    my $self = shift;
    $self->entry_tags->delete;
    return $self->next::method(@_);
}

foreach my $colname (qw/name name_lc/) {
    __PACKAGE__->inflate_column($colname, {
        inflate => sub { my $s = shift; is_utf8($s) ? $s : decode_utf8($s) },
        deflate => sub { my $s = shift; is_utf8($s) ? encode_utf8($s) : $s },
    });
}

# Search conditions don't go through the deflate above, so do it by hand
sub _db_string { my $s = shift; is_utf8($s) ? encode_utf8($s) : $s }

=head2 normalize_name

Trims and collapses whitespace. Returns ($name, $error), $name is '' for an
all-whitespace name.

=cut

sub normalize_name {
    my ($class, $name) = @_;

    $name //= '';
    $name =~ s/^\s+|\s+$//g;
    $name =~ s/\s+/ /g;
    if ($name =~ /,/) {
        return $name, "Tag names can't have commas in them";
    }
    if (length $name > $Max_name_length) {
        return $name, "Tag names can be at most $Max_name_length characters";
    }
    return $name, '';
}

=head2 parse_names

Splits the comma-separated tags from the entry form. Returns (\@names, $error).
Duplicates are dropped case-insensitively, keeping the first spelling.

=cut

sub parse_names {
    my ($class, $string) = @_;

    my (@names, %seen);
    foreach my $raw (split /,/, $string // '') {
        my ($name, $error) = $class->normalize_name($raw);
        return [], $error if $error;
        next if $name eq '' || $seen{lc $name}++;
        push @names, $name;
    }
    return \@names, '';
}

=head2 find_for_user, find_or_create_for_user

Tags are looked up by name case-insensitively, so "horror" finds "Horror".
New tags start out private.

=cut

sub find_for_user {
    my ($class, $schema, $user_id, $name) = @_;
    return $schema->resultset('Tag')->search({
        user_id => $user_id,
        name_lc => _db_string(lc $name),
    })->first;
}

sub find_or_create_for_user {
    my ($class, $schema, $user_id, $name) = @_;
    return $class->find_for_user($schema, $user_id, $name)
        || $schema->resultset('Tag')->create({
            user_id    => $user_id,
            name       => $name,
            visibility => 'private',
        });
}

sub seen_by {
    my ($self, $viewer_level) = @_;
    return scalar grep { $_ eq $self->visibility }
        @{ $Entry->visibilities_seen_by($viewer_level) };
}

=head2 tags_by_entry

Returns { entry id => [ tags, sorted by name ] } for all of $owner_id's
entries, with only the tags a viewer at $viewer_level may see.

=cut

sub tags_by_entry {
    my ($class, $schema, $owner_id, $viewer_level) = @_;

    my @links = $schema->resultset('EntryTag')->search(
        {
            'tag.user_id'    => $owner_id,
            'tag.visibility' => { -in => $Entry->visibilities_seen_by($viewer_level) },
        },
        { prefetch => 'tag', order_by => 'tag.name_lc' },
    )->all;

    my %by_entry;
    push @{ $by_entry{ $_->entry_id } }, $_->tag foreach @links;
    return \%by_entry;
}

=head2 counts

Returns a list of { id, name, visibility, count } for $owner_id's tags that a
viewer at $viewer_level may see, counting only entries they may see. Tags on
no visible entries are left out. Sorted by name.

=cut

sub counts {
    my ($class, $schema, $owner_id, $viewer_level) = @_;

    my $seen = $Entry->visibilities_seen_by($viewer_level);
    my @rows = $schema->resultset('Tag')->search(
        {
            'me.user_id'       => $owner_id,
            'me.visibility'    => { -in => $seen },
            'entry.visibility' => { -in => $seen },
            'entry.is_deleted' => 0,
        },
        {
            join      => { entry_tags => 'entry' },
            columns   => [qw/ me.id me.name me.name_lc me.visibility /],
            '+select' => [ { count => 'entry_tags.entry_id', -as => 'entry_count' } ],
            '+as'     => [ 'entry_count' ],
            group_by  => [qw/ me.id me.name me.name_lc me.visibility /],
            order_by  => 'me.name_lc',
        },
    )->all;

    return map {
        +{
            id         => $_->id,
            name       => $_->name,
            visibility => $_->visibility,
            count      => $_->get_column('entry_count'),
        }
    } @rows;
}

1;
