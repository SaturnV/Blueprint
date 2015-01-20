#! /usr/bin/perl
###### NAMESPACE ##############################################################

package Blueprint::Traits::Components;

###### IMPORTS ################################################################

use Essence::Strict;

use Essence::Merge;
use Scalar::Util;
use Carp;

use Blueprint::Traits::_CompositeBase;

###### VARS ###################################################################

my $mod_name = __PACKAGE__;

###### METHODS ################################################################

sub infect
{
  my ($my_class, $metaclass, $params, $class_config) = @_;

  croak "$mod_name: Can only infect classes"
    unless $metaclass->isa('Blueprint::MetaClass');

  croak "$mod_name: Components should be classes"
    unless (ref($params) eq 'ARRAY');

  my $c_meta;
  my @forwarded;
  my %c_metaattrs;
  foreach my $c (@{$params})
  {
    $c_meta = eval { $c->get_metaclass() };
    croak "Can't get metaclass for $c ($@)" if $@;
    croak "Can't get metaclass for $c" unless $c_meta;

    foreach my $attr_name ($c_meta->GetAttributeNames())
    {
      if ($c_metaattrs{$attr_name})
      {
        push(@{$c_metaattrs{$attr_name}}, $c_meta->GetAttribute($attr_name));
      }
      else
      {
        $c_metaattrs{$attr_name} = [$c_meta->GetAttribute($attr_name)];
        push(@forwarded, $attr_name);
      }
    }
  }
  $metaclass->_SetConfig('components.metaattrs' => \%c_metaattrs);
  $metaclass->_SetConfig('components.forwarded' => \@forwarded);
  $metaclass->_SetConfig('components.classes' => $params);

  # Infect
  foreach my $hook (qw( _Meta_AddAttribute _Meta_BuildEnd
                        verify
                        _Initialize _InitializeAttribute
                        _CloneAttribute
                        Get Set _Set
                        GetDirty SetDirty ClearDirty ))
  {
    $metaclass->_AddHook($hook, $mod_name, $mod_name->can("__$hook"));
  }

  # New hooks
  foreach my $hook (qw( assemble GetComponents ))
  {
    Blueprint::MetaClass->add_default_handler(
        $hook, $mod_name, $mod_name->can("__$hook"));
  }

  my $class = $metaclass->GetName();
  if (!$class->isa('Blueprint::Traits::_CompositeBase'))
  {
    no strict 'refs';
    push(@{"${class}::ISA"}, 'Blueprint::Traits::_CompositeBase');
  }

  return $my_class;
}

# ==== Own ====================================================================
# These are default handlers, no $next

sub __assemble
{
  # my ($hook_name, $stash, $metaclass, $class, @rest) = @_;
  my (undef, $stash, $metaclass, $class, @components) = @_;

  my @init;
  push(@init, shift(@components))
    if (ref($components[0]) eq 'HASH');

  my @classes = @{$metaclass->GetConfig('components.classes')};
  croak "$mod_name: Wrong number of components"
    unless (scalar(@classes) == scalar(@components));
  foreach my $i (0 .. $#classes)
  {
    croak "$mod_name: Components[$i] should be a $classes[$i]"
      unless (Scalar::Util::blessed($components[$i]) &&
              $components[$i]->isa($classes[$i]));
  }

  my $obj = $class->_new();
  $obj->{':components'} = [@components];
  $obj->_Initialize(@init);
  $obj->Verify($stash);

  return $obj;
}

sub __GetComponents
{
  # my ($hook_name, $stash, $metaclass, $obj, @rest) = @_;
  return @{$_[3]->{':components'}};
}

# ==== Modified ===============================================================
# These are plain handlers with $next

sub __context_call
{
  my ($wantarray, $array, $scalar, $next, @args) = @_;

  if ($wantarray)
  {
    @{$array} = $next->(@args);
  }
  elsif (defined($wantarray))
  {
    ${$scalar} = $next->(@args);
  }
  else
  {
    $next->(@args);
  }

  return $wantarray;
}

# ---- verify -----------------------------------------------------------------

sub __verify
{
  my ($next, @rest) = @_;
  my ($hook_name, $stash, $metaclass, $obj, $n, @v) = @rest;
  my (@ret, $ret);

  my $own_attributes = $metaclass->GetConfig('components.own_attributes');
  __context_call(wantarray, \@ret, \$ret, $next, @rest)
    if $own_attributes->{$n};

  if (!(wantarray ? @ret : $ret))
  {
    my $found;
    foreach my $c ($obj->GetComponents())
    {
      if ($c->get_metaclass()->GetAttribute($n))
      {
        $found = 1;
        __context_call(wantarray, \@ret, \$ret,
            sub { $c->verify($stash, $n, @v) });
        last if (wantarray ? @ret : $ret);
      }
    }

    __context_call(wantarray, \@ret, \$ret, $next, @rest)
      unless ($found || $own_attributes->{$n});
  }

  return @ret if wantarray;
  return $ret;
}

# ---- Meta -------------------------------------------------------------------

sub ___Meta_AddAttribute
{
  my ($next, @rest) = @_;
  my ($hook_name, $stash, $metaclass, $class,
      $attr_name, $attr_conf, $inherited_from) = @rest;

  my $c_metaattrs = $metaclass->GetConfig('components.metaattrs');
  $rest[6] = [ @{$inherited_from // []},
               @{$c_metaattrs->{$attr_name}} ]
    if $c_metaattrs->{$attr_name};

  return $next->(@rest);
}

sub ___Meta_BuildEnd
{
  my ($next, @rest) = @_;
  my ($hook_name, $stash, $metaclass, $class) = @rest;

  my $attributes = $metaclass->{'%attributes'};
  my $own_attributes = { %{$attributes} };
  $metaclass->_SetConfig(
      'components.own_attributes' => $own_attributes);

  my $forwarded = $metaclass->GetConfig('components.forwarded');
  foreach my $attr_name (@{$forwarded})
  {
    $metaclass->_RunHook('_Meta_AddAttribute',
          '_Meta_AddAttribute', $stash, $metaclass, $class,
          $attr_name,
          undef, # own config
          []) # ancestors -- components will be patched in above
      unless $own_attributes->{$attr_name};
  }

  return $next->(@rest);
}

# ---- Initialize -------------------------------------------------------------

sub __filter_init
{
  my ($class, $init_in) = @_;
  my $init_out = {};

  my $metaclass = $class->get_metaclass();
  foreach my $attr_name ($metaclass->GetAttributeNames())
  {
    $init_out->{$attr_name} = $init_in->{$attr_name}
      if exists($init_in->{$attr_name});
  }

  return $init_out;
}

sub ___Initialize
{
  my ($next, @rest) = @_;
  my ($hook_name, $stash, $metaclass, $obj,
      $init_in) = @rest;

  my $init_out = {};
  my $own_attributes = $metaclass->GetConfig('components.own_attributes');
  foreach my $attr_name (keys(%{$own_attributes}))
  {
    $init_out->{$attr_name} = $init_in->{$attr_name}
      if exists($init_in->{$attr_name});
  }
  $rest[4] = $init_out;

  $obj->{':components'} =
      [ map { $_->new($stash, __filter_init($_, $init_in)) }
            @{$metaclass->GetConfig('components.classes')} ]
    unless $obj->{':components'};

  return $next->(@rest);
}

sub ___InitializeAttribute
{
  my ($next, @rest) = @_;
  my ($hook_name, $stash, $metaclass, $obj, $n, @v) = @rest;
  my $own_attributes = $metaclass->GetConfig('components.own_attributes');
  return ($own_attributes->{$n} || @v) ? $next->(@rest) : $obj;
}

# ---- Clone ------------------------------------------------------------------

sub ___CloneAttribute
{
  my ($next, @rest) = @_;
  my ($hook_name, $stash, $metaclass, $obj, $n, @x) = @rest;

  my $own_attributes = $metaclass->GetConfig('components.own_attributes');
  return $next->(@rest) if $own_attributes->{$n};

  foreach my $c ($obj->GetComponents())
  {
    return $c->_CloneAttribute($stash, $n, @x)
      if $c->get_metaclass()->GetAttribute($n);
  }

  return $next->(@rest);
}

# ---- Get --------------------------------------------------------------------

sub __Get
{
  my ($next, @rest) = @_;
  my ($hook_name, $stash, $metaclass, $obj, $n) = @rest;
  my @ret;

  my $own_attributes = $metaclass->GetConfig('components.own_attributes');
  @ret = $next->(@rest) if $own_attributes->{$n};

  if (!@ret)
  {
    my $found;
    foreach my $c ($obj->GetComponents())
    {
      last if ($c->get_metaclass()->GetAttribute($n) &&
               ($found = 1) &&
               (@ret = $c->Get($stash, $n)));
    }

    @ret = $next->(@rest)
      unless ($found || $own_attributes->{$n});
  }

  return @ret if wantarray;
  return $ret[0];
}

# ---- Set --------------------------------------------------------------------

sub __Set
{
  my ($next, @rest) = @_;
  my ($hook_name, $stash, $metaclass, $obj, $n, @v) = @rest;
  $obj->verify($n, @v);
  return $obj->RawSet($n, @v);
}

sub ___Set
{
  my ($next, @rest) = @_;
  my ($hook_name, $stash, $metaclass, $obj, $n, @v) = @rest;
  my @ret;

  my $own_attributes = $metaclass->GetConfig('components.own_attributes');
  push(@ret, $next->(@rest)) if $own_attributes->{$n};

  foreach my $c ($obj->GetComponents())
  {
    push(@ret, $c->_Set($stash, $n, @v))
      if $c->get_metaclass()->GetAttribute($n);
  }

  shift(@ret) while (@ret && !defined($ret[0]));

  return $ret[0];
}

# ---- Dirty ------------------------------------------------------------------

sub __filter_dirty_args
{
  my $obj = shift;
  my $metaclass = $obj->get_metaclass();
  my @ret = grep { /^:/ || !/^[+-]?(.*)/ || $metaclass->GetAttribute($1) } @_;
  @ret = qw( :none ) if (@_ && !@ret);
  return @ret;
}

sub __forward_dirty
{
  my ($next, $hook_name, $stash, $metaclass, $obj, @rest) = @_;

  my $own_attributes = $metaclass->GetConfig('components.own_attributes');
  my @rest_ = grep { /^:/ || !/^[+-]?(.*)/ || $own_attributes->{$1} } @rest;
  @rest_ = qw( :none ) if (@rest && !@rest_);
  $next->($hook_name, $stash, $metaclass, $obj, @rest_);

  foreach my $c ($obj->GetComponents($stash))
  {
    $c->$hook_name($stash, __filter_dirty_args($c, @rest));
  }

  return $obj;
}

sub __GetDirty
{
  my ($next, @rest) = @_;
  my ($hook_name, $stash, $metaclass, $obj, @x) = @rest;
  return @{Essence::Merge::merge_arrays(
      [$next->(@rest)],
      map { [$_->GetDirty($stash, @x)] } $obj->GetComponents())};
}

sub __SetDirty { return __forward_dirty(@_) }
sub __ClearDirty { return __forward_dirty(@_) }

###############################################################################

1
