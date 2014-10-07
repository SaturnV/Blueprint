#! /usr/bin/perl

package Blueprint::Types::OptJson;

use Essence::Strict;

use base 'Blueprint::Types::Json';

use Blueprint::Verify;

our $V_OptJson = v_opt($Blueprint::Types::Json::V_Json);

sub _checker { return $V_OptJson }

1
