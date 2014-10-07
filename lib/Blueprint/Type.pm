#! /usr/bin/perl

package Blueprint::Type;

use Essence::Strict;

use base 'Essence::Logger::Mixin';

use Blueprint::Verify;

sub _infect
{
  my ($self, $meta, $hook_name, $cb) = @_;
  $cb = "_$hook_name" if (scalar(@_) < 4);

  $self->Croak("Can only infect attributes")
    unless $meta->isa('Blueprint::MetaAttribute');

  my $sub;
  $sub = ref($cb) ? $cb : sub { $self->$cb(@_) }
    if defined($cb);

  $meta->_AddHook($hook_name, 'type', $sub);
}

sub _verify
{
  #     0      1      2           3       4           5
  # my ($self, $next, $hook_name, $stash, $metaclass, $metaattr,
  #     6     7   8
  #     $obj, $n, $v) = @_;

  my $v = $_[0]->_checker();

  return ($#_ >= 8) ? verify($_[8], $v) : verify_not_exists($v)
    if defined(wantarray);

  my $error = ($#_ >= 8) ? verify($_[8], $v) : verify_not_exists($v);
  return unless $error;

  $_[5]->Croak($error);
}

1
