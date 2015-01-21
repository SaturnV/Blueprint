#! /usr/bin/perl
###### NAMESPACE ##############################################################

package Blueprint::Traits::_CompositeBase;

###### IMPORTS ################################################################

use Essence::Strict;

###### VARS ###################################################################

my $mod_name = __PACKAGE__;

###### METHODS ################################################################

# ==== Constructor ============================================================

sub assemble { return shift->__bp_run_hook('assemble', @_) }
sub get_components { return shift->__bp_run_hook('get_components', @_) }

# ==== Instance methods =======================================================

sub GetComponents { return shift->__bp_run_hook('GetComponents', @_) }

###############################################################################

1
