#! /usr/bin/perl

package Blueprint::Types::TimestampUs;

use Essence::Strict;

use base 'Blueprint::Type';

use Essence::Time qw( fmt_gmtime_us );

use Blueprint::Verify;

my $v_dtus = v_datetime_us();

sub infect
{
  my ($self, $meta) = @_;
  $self->_infect($meta, 'verify');
  $meta->_SetConfig(':builder.new', \&__builder_new);
}

sub _checker { return $v_dtus }

sub __builder_new
{
  # my ($metaclass, $metaattr, $obj, $n) = @_;
  my @def = $_[1]->GetConfig(':default.new');
  return @def ? $def[0] : fmt_gmtime_us();
}

1
