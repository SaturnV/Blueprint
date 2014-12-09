#! /usr/bin/perl

package Blueprint::Types::OptTimestampUs;

use Essence::Strict;

use parent 'Blueprint::Types::Verify';

use Blueprint::Verify;

my $v_default = v_opt(v_datetime_us());

sub new
{
  my $class = shift;
  return bless({ 'v' => v_opt(v_datetime_us(@_)) }, $class);
}

sub _checker { return ref($_[0]) ? $_[0]->{'v'} : $v_default }

1
