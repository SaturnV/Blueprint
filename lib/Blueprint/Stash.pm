#! /usr/bin/perl

package Blueprint::Stash;

use Essence::Strict;

use base 'Blueprint::StashBase';

use Exporter qw( import );
our @EXPORT_OK = qw( S );

sub S { return __PACKAGE__->new(@_) }

1
