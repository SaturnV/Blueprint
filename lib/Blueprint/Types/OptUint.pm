#! /usr/bin/perl

package Blueprint::Types::OptUint;

use Essence::Strict;

use parent 'Blueprint::Types::Verify';

use Blueprint::Verify;

my $v_default = v_opt(v_uint());

sub new
{
  my $class = shift;
  return @_ ? $class->next::method(v_opt(v_all(v_uint(), @_))) : $class;
}

sub _checker { return ref($_[0]) ? $_[0]->{'v'} : $v_default }

1
