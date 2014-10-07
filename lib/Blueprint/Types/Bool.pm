#! /usr/bin/perl

package Blueprint::Types::Bool;

use Essence::Strict;

use base 'Blueprint::Types::Verify';

use Blueprint::Verify;

my $v_default = v_bool();

sub new { return $_[0] }
sub _checker { return $v_default }

1
