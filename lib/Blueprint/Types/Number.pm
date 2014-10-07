#! /usr/bin/perl

package Blueprint::Types::Number;

use Essence::Strict;

use base 'Blueprint::Types::Verify';

use Blueprint::Verify;

my $v_default = v_number();

sub new
{
  my $class = shift;
  return @_ ? $class->next::method($v_default, @_) : $class;
}

sub _checker { return ref($_[0]) ? $_[0]->{'v'} : $v_default }

1
