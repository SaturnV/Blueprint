#! /usr/bin/perl

package Blueprint::Types::OptPerl;

use Essence::Strict;

use parent 'Blueprint::Types::Perl';

use Blueprint::Verify;

our $V_OptPerl = v_opt($Blueprint::Types::Perl::V_Perl);

sub _checker { return $V_OptPerl }
