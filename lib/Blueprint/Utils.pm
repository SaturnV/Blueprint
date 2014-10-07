#! /usr/bin/perl
###### NAMESPACE ##############################################################

package Blueprint::Utils;

###### IMPORTS ################################################################

use Essence::Strict;

use List::MoreUtils qw( any all );
use Essence::Merge qw( merge_arrays merge_hashes );
use Time::HiRes;

###### EXPORTS ################################################################

use Exporter qw( import );
our @EXPORT_OK = qw(
    $ReNameComponent $ReName
    $ReAttrMethods $ReClassMethods $ReInstanceMethods
    classify to_classname
    get_independent_isa get_super_metaclasses
    merge );

###### VARS ###################################################################

# To be used as part of more complex regexps
our $ReNameComponent = qr/(?:[A-Za-z_]\w*)/;
our $ReName = qr/(?:$ReNameComponent(\.$ReNameComponent)*)/;

# Standalone
our $ReClassMethods = qr/^(?:new|verify)\z/;
our $ReInstanceMethods =
     qr/^(?:_Initialize|Clone|(?:Get|Set|Clear)Dirty|Edit)\z/;
our $ReAttrMethods = qr/^(?:_InitializeAttribute|Get|(?:_|Raw)?Set|verify)\z/;

###### SUBS ###################################################################

# ==== Classes ================================================================

sub classify { return ref($_[0]) || $_[0] }

sub to_classname
{
  my ($str, $prefix) = @_;

  if ($str =~ /^[0-9a-z_]+\z/)
  {
    my $uss = ($str =~ /^(_+)/) ? $1 : '';
    $str = ucfirst($str);
    $str =~ s/_([0-9a-z])/uc($1)/eg;
    $str = $uss . $str;

    $str = $prefix . $str
      if defined($str);
  }

  return $str;
}

sub get_independent_isa
{
  my (@ret, $base_meta);
  my %done = ( $_[0] => 1 );
  foreach my $base_class (@{mro::get_linear_isa($_[0])})
  {
    next if $done{$base_class};
    $done{$_} = 1 foreach (@{mro::get_linear_isa($base_class)});
    push(@ret, $base_class);
  }
  return @ret;
}

sub get_super_metaclasses
{
  my @ret;

  my %done;
  my ($method, $metaclass);
  foreach my $base_class (get_independent_isa(@_))
  {
    next if $done{$base_class};
    next unless ($method = $base_class->can('get_metaclass'));
    next unless ($metaclass = $base_class->$method());
    push(@ret, $metaclass);
  }

  return @ret;
}

sub merge
{
  return merge_hashes(grep { ref($_) eq 'HASH' } @_)
    if (ref($_[0]) eq 'HASH');
  return merge_arrays(grep { ref($_) eq 'ARRAY' } @_)
    if (ref($_[0]) eq 'ARRAY');
  return @_ ? ($_[0]) : ();
}

###############################################################################

1
