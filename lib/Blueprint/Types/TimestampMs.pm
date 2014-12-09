#! /usr/bin/perl

package Blueprint::Types::TimestampMs;

use Essence::Strict;

use parent 'Blueprint::Types::Verify';

use Essence::Time qw( fmt_gmtime_ms );

use Blueprint::Verify;

my $v_dtms = v_datetime_ms();

sub infect
{
  my ($self, $meta) = @_;
  $meta->_SetConfig(':builder.new', \&__builder_new);
  return shift->next::method(@_);
}

sub _checker { return $v_dtms }

sub __builder_new
{
  # my ($metaclass, $metaattr, $obj, $n) = @_;
  my @def = $_[1]->GetConfig(':default.new');
  return @def ? $def[0] : fmt_gmtime_ms();
}

1
