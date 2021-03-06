#! /usr/bin/perl

package Blueprint::Types::String;

use Essence::Strict;

use parent 'Blueprint::Types::Verify';

use Blueprint::Verify;

my $v_default = v_string();

sub new
{
  my $class = shift;
  return bless({ 'v' => v_string(@_) }, $class);
}

sub _checker { return ref($_[0]) ? $_[0]->{'v'} : $v_default }

1
