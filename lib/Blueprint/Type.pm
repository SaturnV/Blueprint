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

# sub _ExampleHook
# {
#   #     0      1      2           3       4           5
#   # my ($self, $next, $hook_name, $stash, $metaclass, $metaattr,
#   #     6     7
#   #     $obj, @rest) = @_;
#  shift; return shift->(@_);
# }

1
