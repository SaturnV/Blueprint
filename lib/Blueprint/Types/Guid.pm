#! /usr/bin/perl

package Blueprint::Types::Guid;

use Essence::Strict;

use parent 'Blueprint::Type';

use Essence::UUID;

use Blueprint::Verify;

my $v_guid = v_guid();

sub infect
{
  my ($self, $meta) = @_;
  $self->_infect($meta, 'verify');
  $meta->_SetConfig(':builder.new', \&__builder_new);
}

sub _checker { return $v_guid }

sub __builder_new
{
  # my ($metaclass, $metaattr, $obj, $n) = @_;
  my @def = $_[1]->GetConfig(':default.new');
  return @def ? $def[0] : uuid_hex();
}

1
