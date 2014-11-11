#! /usr/bin/perl

package Blueprint::Types::OptGuid;

use Essence::Strict;

use parent 'Blueprint::Types::Verify';

use Essence::UUID;

use Blueprint::Verify;

my $v_opt_guid = v_opt(v_guid());

sub new { return $_[0] }
sub _checker { return $v_opt_guid }

1
