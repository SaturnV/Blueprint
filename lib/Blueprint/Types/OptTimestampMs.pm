#! /usr/bin/perl

package Blueprint::Types::OptTimestampMs;

use Essence::Strict;

use base 'Blueprint::Types::Verify';

use Blueprint::Verify;

my $v_default = v_opt(v_datetime_ms());

sub new
{
  my $class = shift;
  return bless({ 'v' => v_opt(v_datetime_ms(@_)) }, $class);
}

sub _checker { return ref($_[0]) ? $_[0]->{'v'} : $v_default }

1
