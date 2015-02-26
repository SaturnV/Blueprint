#! /usr/bin/perl
# Speed is not an issue for now
###### NAMESPACE ##############################################################

package Blueprint;

###### IMPORTS ################################################################

use Essence::Strict;

use Carp;

use Blueprint::Utils qw( $ReName );
use Blueprint::MetaClass;
use Blueprint::_Stash;

###### VARS ###################################################################

my $mod_name = __PACKAGE__;

our %Classes;

###### METHODS ################################################################

# ==== Internals ==============================================================

sub __bp_run_hook
{
  # my ($obj, $hook_name, @rest) = @_;
  my ($obj, $hook_name) = (shift, shift);
  my @ret;

  # Stash setup
  my ($stash, $parent, $base);
  $stash = Blueprint::_Stash->new(
      { ':method' => $hook_name });

  $base = shift
    if (Scalar::Util::blessed($_[0]) &&
        $_[0]->isa('Blueprint::StashBase'));

  if (ref($obj))
  {
    $stash->Set(':parent' => $parent)
      if ($parent = $obj->{':stash'});
    $obj->{':stash'} = $stash;

    undef($base)
      if ($base && $parent && ($base eq $parent));
  }

  $stash->Set(
      ($base->isa('Blueprint::_Stash') ? ':parent' : ':base') => $base)
    if $base;

  $stash->Set(':args' => [@_]);

  # Run method hook
  my $metaclass = $obj->get_metaclass() or
    croak "No metadata for " . Blueprint::Utils::classify($obj);

  my $err;
  my $wantarray = wantarray;
  eval
  {
    if ($wantarray)
    {
      @ret = $metaclass->_RunHook(
          $hook_name, $hook_name, $stash, $metaclass, $obj, @_);
    }
    elsif (defined($wantarray))
    {
      $ret[0] = $metaclass->_RunHook(
          $hook_name, $hook_name, $stash, $metaclass, $obj, @_);
    }
    else
    {
      $metaclass->_RunHook(
          $hook_name, $hook_name, $stash, $metaclass, $obj, @_);
    }
  };
  $err = $@;

  # Stash cleanup
  $obj->{':stash'} = $parent
    if (ref($obj) &&
        defined($obj->{':stash'}) &&
        ($obj->{':stash'} eq $stash));

  die $err if $err;

  return @ret if wantarray;
  return $ret[0];
}

# ==== Build ==================================================================

sub blueprint
{
  my $class = shift;
  $class = ref($class) if ref($class);

  croak "Trying to redefine $class"
    if exists($Blueprint::Classes{$class});
  croak "You should inherit Blueprint and call blueprint on your class.\n"
    if ($class eq $mod_name);

  # Split parameters from attributes
  my @own_attributes;
  my %own_attributes;
  my %config;
  while (@_)
  {
    my $n = shift;

    croak "Undefined name in $class"
      unless defined($n);
    croak "Don't know what to do with a " . ref($n) . " reference in $class"
      if ref($n);
    croak "No definition for $class.$n"
      unless @_;

    if ($n =~ /^:$ReName\z/)
    {
      croak "Duplicate parameter $n in $class"
        if exists($config{$n});
      $config{$n} = shift;
    }
    else
    {
      croak "Duplicate attribute $class.$n"
        if exists($own_attributes{$n});
      $own_attributes{$n} = shift;
      push(@own_attributes, $n);
    }
  }

  # Ancestors
  mro::set_mro($class, 'c3');
  my @class_ancestors = Blueprint::Utils::get_super_metaclasses($class);

  # Create metaclass
  my $metaclass = $Blueprint::Classes{$class} =
      Blueprint::MetaClass->new(
          $class, \@class_ancestors, \%config);

  # Inherited attributes
  my @inherited_attributes;
  my %attribute_ancestors;
  foreach my $base_meta (@class_ancestors)
  {
    foreach my $attr_name ($base_meta->GetAttributeNames())
    {
      if ($attribute_ancestors{$attr_name})
      {
        # push(@{$attribute_ancestors{$attr_name}}, $base_class);
        push(@{$attribute_ancestors{$attr_name}},
            $base_meta->GetAttribute($attr_name));
      }
      else
      {
        # $attribute_ancestors{$attr_name} = [$base_class];
        $attribute_ancestors{$attr_name} =
            [$base_meta->GetAttribute($attr_name)];
        push(@inherited_attributes, $attr_name);
      }
    }
  }

  # Merge inherited + own attributes, create
  {
    my $stash = Blueprint::_Stash->new();

    $metaclass->_RunHook('_Meta_BuildBegin',
        '_Meta_BuildBegin', $stash, $metaclass, $class);

    my %done;
    foreach my $attr_name (@inherited_attributes, @own_attributes)
    {
      next if $done{$attr_name};

      $metaclass->_RunHook('_Meta_AddAttribute',
          '_Meta_AddAttribute', $stash, $metaclass, $class,
          $attr_name,
          $own_attributes{$attr_name},
          $attribute_ancestors{$attr_name});

      $done{$attr_name} = 1;
    }

    $metaclass->_RunHook('_Meta_BuildEnd',
        '_Meta_BuildEnd', $stash, $metaclass, $class);
  }

  return $metaclass;
}

# ==== Class methods ==========================================================

sub get_metaclass
{
  return $Blueprint::Classes{Blueprint::Utils::classify($_[0])};
}

# ==== Constructor ============================================================

sub _new
{
  return shift->__bp_run_hook('_new', @_);
}

# my $obj = Class->new({ 'attr' => $value });
sub new
{
  return shift->__bp_run_hook('new', @_);
}

sub Clone
{
  return shift->__bp_run_hook('Clone', @_);
}

# ==== Class methods ==========================================================

# $class->verify('attr') # Verify attr is valid unset (cleared)
# $class->verify('attr, $value) # Verify $value is valid for 'attr'
# $class->verify(...) # die on error
# my $err = $class->Verify(...) # Return error (undef on success), don't die
# my @err = $class->Verify(...) # May return multiple errors
sub verify
{
  return shift->__bp_run_hook('verify', @_);
}

# ==== Instance methods =======================================================

sub _Initialize
{
  # my ($self, @new_params) = @_;
  return shift->__bp_run_hook('_Initialize', @_);
}

# ----- Dirty -----------------------------------------------------------------

sub GetDirty
{
  # my ($self, @params) = @_;
  return shift->__bp_run_hook('GetDirty', @_);
}

sub GetDirtyMeta
{
  my $self = shift;
  my @dirty;

  if (@dirty = $self->GetDirty(@_))
  {
    my $metaclass = $self->get_metaclass();
    @dirty = map { $metaclass->GetAttribute($_) } @dirty;
  }

  return @dirty;
}

sub SetDirty
{
  # my ($self, @params) = @_;
  return shift->__bp_run_hook('SetDirty', @_);
}

sub ClearDirty
{
  # my ($self, @params) = @_;
  return shift->__bp_run_hook('ClearDirty', @_);
}

# ---- Attributes -------------------------------------------------------------

sub _InitializeAttribute
{
  # my ($self, $n, $v?) = @_;
  return shift->__bp_run_hook('_InitializeAttribute', @_);
}

sub _CloneAttribute
{
  # my ($self, $n, $v?) = @_;
  return shift->__bp_run_hook('_CloneAttribute', @_);
}

sub Get
{
  # my ($self, $n, @builder_params) = @_;
  return shift->__bp_run_hook('Get', @_);
}

sub Set
{
  # my ($self, $n, $v) = @_;
  return shift->__bp_run_hook('Set', @_);
}

sub RawSet
{
  # my ($self, $n, $v) = @_;
  return shift->__bp_run_hook('RawSet', @_);
}

sub _Set
{
  # my ($self, $n, $v) = @_;
  return shift->__bp_run_hook('_Set', @_);
}

sub Pick
{
  # my ($self, @ns) = @_;
  return shift->__bp_run_hook('Pick', @_);
}
sub Picks { return scalar(shift->Pick(@_)) }

# TODO
# IsSet
# Clear

# ==== Edit ===================================================================

sub Edit
{
  # my ($self, $data) = @_;
  return shift->__bp_run_hook('Edit', @_);
}

# ==== Verify =================================================================

sub Verify
{
  return shift->__bp_run_hook('Verify', @_);
}

###############################################################################

1
