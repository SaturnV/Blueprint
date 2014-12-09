#! /usr/bin/perl

package Blueprint::Types::Timestamp;

use Essence::Strict;

use parent 'Blueprint::Types::Verify';

use Essence::Time qw( fmt_gmtime_s );

use Blueprint::Verify;

my $v_dts = v_datetime();

sub infect
{
  # my ($self, $meta, $config) = @_;
  my ($self, $meta) = @_;
  $meta->_SetConfig(':builder.new', \&__builder_new);
  return shift->next::method(@_);
}

sub _checker { return $v_dts }

sub __builder_new
{
  # my ($metaclass, $metaattr, $obj, $n) = @_;
  my @def = $_[1]->GetConfig(':default.new');
  return @def ? $def[0] : fmt_gmtime_s();
}

1
