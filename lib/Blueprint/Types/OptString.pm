#! /usr/bin/perl

package Blueprint::Types::OptString;

use Essence::Strict;

use base 'Blueprint::Types::Verify';

use Blueprint::Verify;

my $v_default = v_opt(v_string());

sub new
{
  my $class = shift;
  return bless({ 'v' => v_opt(v_string(@_)) }, $class);
}

sub _checker { return ref($_[0]) ? $_[0]->{'v'} : $v_default }

1
