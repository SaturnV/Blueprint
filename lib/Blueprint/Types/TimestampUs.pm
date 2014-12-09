#! /usr/bin/perl

package Blueprint::Types::TimestampUs;

use Essence::Strict;

use parent 'Blueprint::Types::Verify';

use Essence::Time qw( fmt_gmtime_us );

use Blueprint::Verify;

my $v_dtus = v_datetime_us();

sub infect
{
  # my ($self, $meta, $config) = @_;
  my ($self, $meta) = @_;
  $meta->_SetConfig(':builder.new', \&__builder_new);
  return shift->next::method(@_);
}

sub _checker { return $v_dtus }

sub __builder_new
{
  # my ($metaclass, $metaattr, $obj, $n) = @_;
  my @def = $_[1]->GetConfig(':default.new');
  return @def ? $def[0] : fmt_gmtime_us();
}

1
