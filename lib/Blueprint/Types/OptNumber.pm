#! /usr/bin/perl

package Blueprint::Types::OptNumber;

use Essence::Strict;

use base 'Blueprint::Types::Verify';

use Blueprint::Verify;

my $v_default = v_opt(v_number());

sub new
{
  my $class = shift;
  return @_ ? $class->next::method(v_opt(v_all(v_number(), @_))) : $class;
}

sub _checker { return ref($_[0]) ? $_[0]->{'v'} : $v_default }

1
