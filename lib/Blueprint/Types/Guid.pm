#! /usr/bin/perl

package Blueprint::Types::Guid;

use Essence::Strict;

use parent 'Blueprint::Types::Verify';

use Essence::UUID;

use Blueprint::Verify;

my $v_guid = v_guid();

sub infect
{
  my ($self, $meta) = @_;
  $meta->_SetConfig(':builder.new', \&__builder_new);
  return shift->next::method(@_);
}

sub _checker { return $v_guid }

sub __builder_new
{
  # my ($metaclass, $metaattr, $obj, $n) = @_;
  my @def = $_[1]->GetConfig(':default.new');
  return @def ? $def[0] : uuid_hex();
}

1
