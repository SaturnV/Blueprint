#! /usr/bin/perl
# TODO: DB filters

package Blueprint::Types::Flag;

use Essence::Strict;

use parent 'Blueprint::Types::Verify';

use Blueprint::Verify;

my $v = v_bool();

sub infect
{
  my ($self, $meta, $config) = @_;

  my $mask = delete($config->{':mask'}) or
    $meta->Croak("No mask");
  $meta->_SetConfig('mask' => $mask);

  my $field = delete($config->{':field'});
  $meta->_SetConfig('field' => $field)
    if defined($field);

  $self->_infect($meta, 'Get');
  $self->_infect($meta, 'RawSet');

  return shift->next::method(@_);
}

sub _checker { return $v }

sub _Get
{
  #     0      1      2           3       4           5
  # my ($self, $next, $hook_name, $stash, $metaclass, $metaattr,
  #     6     7
  #     $obj, $n) = @_;
  my $field = $_[5]->GetConfig('field') // 'flags';
  my $mask = $_[5]->GetConfig('mask') or
    $_[5]->Croak("No mask");
  return (($_[6]->Get($field) // 0) & $mask) ? 1 : 0;
}

sub _RawSet
{
  #     0      1      2           3       4           5
  # my ($self, $next, $hook_name, $stash, $metaclass, $metaattr,
  #     6     7   8
  #     $obj, $n, $v) = @_;
  my $field = $_[5]->GetConfig('field') // 'flags';
  my $mask = $_[5]->GetConfig('mask') or
    $_[5]->Croak("No mask");
  my $old = $_[6]->Get($field) // 0;
  $_[6]->Set($field => ($_[8] ? $old | $mask : $old & ~$mask));
  return $_[8];
}

1
