#! /usr/bin/perl

package Blueprint::Types::Email;

use Essence::Strict;

use base 'Blueprint::Types::Verify';

use Blueprint::Verify;

my $v_default = v_email();

sub new
{
  my $class = shift;
  return bless({ 'v' => v_email(@_) }, $class);
}

sub _checker { return ref($_[0]) ? $_[0]->{'v'} : $v_default }

1
