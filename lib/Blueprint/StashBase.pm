#! /usr/bin/perl
# TODO This somewhat resembles Blueprint::MetaBase

package Blueprint::StashBase;

use Essence::Strict;

use parent 'Blueprint::InheritableData';

use Carp;

use Blueprint::Utils;

my $mod_name = __PACKAGE__;

sub new
{
  my $class = shift;
  my $self = bless(
      (ref($_[0]) eq 'HASH') ? shift : {}, $class);

  while (@_)
  {
    if (ref($_[0]) eq 'HASH')
    {
      my $h = shift;
      $self->SetWeak($_ => $h->{$_}) foreach (keys(%{$h}));
    }
    elsif (scalar(@_) > 1)
    {
      my ($n, $v) = (shift, shift);
      carp "$mod_name: Undefined value for hash key"
        unless defined($n);
      carp "$mod_name: Reference for hash key"
        if ref($n);
      $self->SetWeak($n => $v);
    }
    else
    {
      croak "$mod_name: Odd number of elements in hash constructor";
    }
  }

  return $self;
}

sub _GetAncestors
{
  my @ret;
  push(@ret, $_[0]->{':base'}) if $_[0]->{':base'};
  push(@ret, $_[0]->{':parent'}) if $_[0]->{':parent'};
  return @ret;
}

sub Get
{
  # my ($self, $n) = @_;
  return ($_[1] =~ /^:/) ?
      shift->_GetOwn(@_) :
      shift->_Get(@_);
}

sub GetOwn { return shift->_GetOwn(@_) }

sub Set { return shift->_Set(@_) }
sub SetWeak { return shift->_SetWeak(@_) }
sub Clear { return shift->_Clear(@_) }

sub GetFirst
{
  my ($s, $n) = @_;
  my $p;
  $s = $p while (!exists($s->{$n}) &&
                 ($p = $s->{':base'} || $s->{':parent'}));
  return $s->{$n};
}

sub SetToplevel
{
  my ($s, $p) = (shift);
  $s = $p while ($p = $s->{':base'} || $s->{':parent'});
  return $s->_Set(@_);
}

sub Singleton
{
  my ($s, $n, $default) = @_;
  my $ret = $s->GetFirst($n);
  $ret = $s->SetToplevel($n, $default)
    if (!defined($ret) && defined($default));
  return $ret;
}

1
