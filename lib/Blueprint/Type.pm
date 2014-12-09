#! /usr/bin/perl

package Blueprint::Type;

use Essence::Strict;

use parent 'Essence::Logger::Mixin';

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

1
