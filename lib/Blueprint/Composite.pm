#! /usr/bin/perl
###### NAMESPACE ##############################################################

package Blueprint::Composite;

###### IMPORTS ################################################################

use Essence::Strict;

use parent 'Blueprint';

use Essence::Merge;
use Blueprint::Utils;
use Blueprint::Composite::MetaClass;
use Carp;

###### VARS ###################################################################

my $mod_name = __PACKAGE__;

###### METHODS ################################################################

# ==== Build ==================================================================

sub blueprint
{
  my $class = ref($_[0]) || $_[0];
  croak "$class is a composite class. "
      . "The blueprint method is not implemented";
}

sub composite
{
  my ($class, $config, @components) = @_;
  $class = ref($class) if ref($class);

  mro::set_mro($class, 'c3');

  croak "$class is a composite class. "
      . "It should not have superclasses"
    if Blueprint::Utils::get_super_metaclasses($class);

  # Create metaclass
  $config->{':components'} =
      $config->{':components'} ?
          Essence::Merge::merge_arrays(
              $config->{':components'},
              \@components) :
          \@components;
  my $metaclass = Blueprint::Composite::MetaClass->new($class, [], $config);

  return $Blueprint::Classes{$class} = $metaclass;
}

# ==== Constructor ============================================================

sub assemble { return shift->__bp_run_hook('assemble', @_) }

# ==== Instance methods =======================================================

sub GetComponents { return shift->__bp_run_hook('GetComponents', @_) }

###############################################################################

1
