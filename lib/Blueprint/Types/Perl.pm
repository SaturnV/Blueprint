#! /usr/bin/perl
# Highly insecure on untrusted data!

package Blueprint::Types::Perl;

use Essence::Strict;

use parent 'Blueprint::Types::Verify';

use Data::Dumper;

use Blueprint::Verify;

our $V_Perl = v_ref('HASH', 'ARRAY');

sub infect
{
  # my ($self, $meta, $config) = @_;
  my ($self, $meta) = @_;
  $self->_infect($meta, 'SerializeToDb');
  $self->_infect($meta, 'deserialize_from_db');
  return shift->next::method(@_);
}

sub _checker { return $V_Perl }

sub _SerializeToDb
{
  #     0      1      2           3       4           5
  # my ($self, $next, $hook_name, $stash, $metaclass, $metaattr,
  #     6     7   8
  #     $obj, $n, $v) = @_;

  local $Data::Dumper::Sortkeys = 1;
  local $Data::Dumper::Indent = 0;
  local $Data::Dumper::Terse = 1;
  local $Data::Dumper::Pad = '';

  return ref($_[8]) ? Data::Dumper::Dumper($_[8]) : $_[8];
}

sub _deserialize_from_db
{
  #     0      1      2           3       4           5
  # my ($self, $next, $hook_name, $stash, $metaclass, $metaattr,
  #     6     7   8   9
  #     $obj, $n, $v, $db_hash) = @_;

  return $_[8] unless (defined($_[8]) && !ref($_[8]));

  my $ret = eval $_[8];
  if ($@)
  {
    my $class = ref($_[6]) || $_[6];
    die "_deserialize_from_db($class.$_[7] = '$_[8]'): $@\n";
  }

  return $ret;
}

1
