#! /usr/bin/perl

package Blueprint::Types::OptEmail;

use Essence::Strict;

use parent 'Blueprint::Types::Verify';

use Blueprint::Verify;

my $v_default = v_opt(v_email());

sub new
{
  my $class = shift;
  return bless({ 'v' => v_opt(v_email(@_)) }, $class);
}

sub _checker { return ref($_[0]) ? $_[0]->{'v'} : $v_default }

1
