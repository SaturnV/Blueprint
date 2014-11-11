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

sub infect
{
  my ($self, $meta) = @_;
  $self->_infect($meta, 'verify');
}

1
