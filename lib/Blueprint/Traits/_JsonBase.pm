#! /usr/bin/perl

package Blueprint::Traits::_JsonBase;

use Essence::Strict;

sub SerializeToJson
{
  # my ($self, @fields) = @_;
  return shift->__bp_run_hook('SerializeToJson', @_);
}

1
