#! /usr/bin/perl

package Blueprint::Types::Verify;

use Essence::Strict;

use parent 'Blueprint::Type';

use Blueprint::Verify;

sub new
{
  my $class = shift;
  my $v = (!$#_ && (ref($_[0]) eq 'CODE')) ? v_all(@_) : $_[0];
  return bless({ 'v' => $v }, $class);
}

sub _checker { return $_[0]->{'v'} }

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

sub infect
{
  my ($self, $meta) = @_;
  $self->_infect($meta, 'verify');
}

1
