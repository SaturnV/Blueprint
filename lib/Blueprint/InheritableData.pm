#! /usr/bin/perl

package Blueprint::InheritableData;

use Essence::Strict;

sub _GetOwn
{
  # my ($self, $n) = @_;
  my ($ret, $n) = @_;
  my $stop;

  my $k;
  my @keys = split(/\./, $n);
  while (@keys)
  {
    $k = shift(@keys);

    $stop = 1 if $ret->{':stop'};

    if (exists($ret->{$k}))
    {
      if (ref($ret = $ret->{$k}) ne 'HASH')
      {
        if (@keys)
        {
          $stop = 1;
          undef($ret);
        }
        elsif (ref($ret) ne 'ARRAY')
        {
          $stop = 1;
        }

        last;
      }
    }
    else
    {
      undef($ret);
      last;
    }
  }

  return ($ret, $stop) if wantarray;
  return $ret;
}

sub _GetInherited
{
  my ($self, $own) = (shift, shift);
  my @ret = defined($own) ? ($own) : ();

  my @bases = $self->_GetAncestors();
  push(@ret, shift(@bases)->_Get(@_))
    while (@bases && (!@ret || (ref($ret[0]) ~~ ['ARRAY', 'HASH'])));

  return Blueprint::Utils::merge(@ret);
}

sub _Get
{
  my $self = shift;
  my ($ret, $stop) = $self->_GetOwn(@_);
  return $stop ? ($ret) : $self->_GetInherited($ret, @_);
}

sub _Set
{
  # my ($self, $n, $v) = @_;
  my ($c, $n, $v) = @_;

  my @keys = split(/\./, $n);
  my $last = pop(@keys);
  $c = (ref($c->{$keys[0]}) eq 'HASH') ?
      $c->{shift(@keys)} :
      ($c->{shift(@keys)} = {})
    while @keys;

  return $c->{$last} = $v;
}

# TODO optimize
sub _SetWeak
{
  my ($self, $n) = (shift, @_);
  my ($v, $has_own) = $self->_GetOwn($n);
  return $has_own ? $v : $self->_Set(@_);
}

sub _Clear
{
  # my ($self, $n) = @_;
  my ($c, $n) = @_;

  my @keys = split(/\./, $n);
  my $last = pop(@keys);
  while (@keys)
  {
    $c = $c->{shift(@keys)};
    return unless (ref($c) eq 'HASH');
  }

  return delete($c->{$last});
}

1
