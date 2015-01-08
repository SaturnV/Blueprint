#! /usr/bin/perl
# TODO: DB filters

package Blueprint::Types::InverseFlag;

use Essence::Strict;

use parent 'Blueprint::Types::Flag';

sub _Get
{
  #     0      1      2           3       4           5
  # my ($self, $next, $hook_name, $stash, $metaclass, $metaattr,
  #     6     7
  #     $obj, $n) = @_;
  my ($self, @rest) = @_;
  return $self->next::method(@rest) ? 0 : 1;
}

sub _RawSet
{
  #     0      1      2           3       4           5
  # my ($self, $next, $hook_name, $stash, $metaclass, $metaattr,
  #     6     7   8
  #     $obj, $n, $v) = @_;
  my ($self, @rest) = @_;
  $rest[7] = $rest[7] ? 0 : 1;
  return $self->next::method(@rest) ? 0 : 1;
}

1
