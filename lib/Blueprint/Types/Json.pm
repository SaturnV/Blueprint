#! /usr/bin/perl

package Blueprint::Types::Json;

use Essence::Strict;

use parent 'Blueprint::Type';

use JSON;

use Blueprint::Verify;

our $V_Json = v_ref('HASH', 'ARRAY');

sub infect
{
  my ($self, $meta) = @_;
  $self->_infect($meta, 'verify');
  $self->_infect($meta, 'SerializeToDb');
  $self->_infect($meta, 'deserialize_from_db');
}

sub _checker { return $V_Json }

sub _SerializeToDb
{
  #     0      1      2           3       4           5
  # my ($self, $next, $hook_name, $stash, $metaclass, $metaattr,
  #     6     7   8
  #     $obj, $n, $v) = @_;
  return ref($_[8]) ? to_json($_[8]) : $_[8];
}

sub _deserialize_from_db
{
  #     0      1      2           3       4           5
  # my ($self, $next, $hook_name, $stash, $metaclass, $metaattr,
  #     6     7   8   9
  #     $obj, $n, $v, $db_hash) = @_;
  return (defined($_[8]) && ($_[8] =~ /^[\[\{]/)) ? from_json($_[8]) : $_[8];
}

1
