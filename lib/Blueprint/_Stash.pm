#! /usr/bin/perl

package Blueprint::_Stash;

use Essence::Strict;

use base 'Blueprint::StashBase';

sub IsInsideMethod
{
  # my ($self, $method) = @_;
  my ($s, $m) = @_;
  my $t;

  while ($s)
  {
    last if (defined($t = $s->{':method'}) && ($t ~~ $m));
    $s = $s->{':parent'};
  }

  return $s;
}

1
