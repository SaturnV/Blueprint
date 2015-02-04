#! /usr/bin/perl
###### NAMESPACE ##############################################################

package Blueprint::MetaClass;

###### IMPORTS ################################################################

use Essence::Strict;

use parent 'Blueprint::MetaBase';

use Blueprint::Utils qw( $ReAttrMethods );
use Blueprint::MetaAttribute;

###### METHODS ################################################################

# ==== Constructor + Basic properties =========================================

sub _Initialize
{
  my ($self, $config) = @_;

  $self->{'@attributes'} = [];
  $self->{'%attributes'} = {};

  return $self;
}

# ==== Configuration ==========================================================

sub _PreConfigure
{
  my ($self, $config) = @_;

  # Traits
  if (my $traits = delete($config->{':traits'}))
  {
    if (ref($traits) eq 'HASH')
    {
      foreach my $trait (keys(%{$traits}))
      {
        $self->AddTrait($trait, $traits->{$trait}, $config);
      }
    }
    elsif (ref($traits) eq 'ARRAY')
    {
      my @traits = @{$traits};
      $self->AddTrait(shift(@{$traits}), shift(@{$traits}), $config)
        while @traits;
    }
    elsif (defined($traits))
    {
      $self->Croak("Bad :traits");
    }
  }

  return shift->next::method(@_);
}

sub _Configure
{
  my ($self, $config) = @_;

  if (exists($config->{':defaults'}))
  {
    my $defaults = delete($config->{':defaults'});
    $self->Confess(":defaults should be a HASH")
      unless (ref($defaults) eq 'HASH');
    $self->_SetConfig(':defaults', $defaults);
  }

  return shift->next::method(@_);
}

# ==== Attributes =============================================================

sub __bp__Meta_AddAttribute
{
  my ($hook_name, $stash, $metaclass, $class,
      $attr_name, $attr_conf, $inherited_from) = @_;

  if ($attr_conf)
  {
    my $defaults = $metaclass->GetConfig(':defaults');
    $attr_conf = Blueprint::Utils::merge($attr_conf, $defaults)
      if $defaults;
    $attr_conf->{':class'} = $metaclass->GetName();
  }

  my $metaattr = Blueprint::MetaAttribute->new(
      $attr_name, $inherited_from, $attr_conf // {}, $metaclass);
  push(@{$metaclass->{'@attributes'}}, $attr_name);
  $metaclass->{'%attributes'}->{$attr_name} = $metaattr;

  return $metaattr;
}

sub GetAttributeNames { return @{$_[0]->{'@attributes'}} }
sub GetAttribute { return $_[0]->{'%attributes'}->{$_[1]} }

sub GetAttributeNamesWithMeta
{
  my $metaclass = shift;
  my @ret;

  my $metaattr;
  my $attributes = $metaclass->{'%attributes'};
  ATTR: foreach my $attr_name (keys(%{$attributes}))
  {
    $metaattr = $attributes->{$attr_name};

    foreach (@_)
    {
      next ATTR
        unless (/^(!?)(.*)/ && ($1 xor $metaattr->GetMeta($2)));
    }

    push(@ret, $attr_name);
  }

  return @ret;
}

# ---- Fields -----------------------------------------------------------------

sub _Fields
{
  my ($metaclass, $obj, $f) = @_;

  if ($f eq ':all')
  {
    return $metaclass->GetAttributeNames();
  }
  elsif ($f eq ':none')
  {
    return ();
  }
  elsif ($f eq ':dirty')
  {
    return $obj->GetDirty();
  }
  else
  {
    $metaclass->Croak("No attribute named '$f'")
      unless $metaclass->GetAttribute($f);
    return ($f);
  }
}

sub Fields
{
  my ($metaclass, $obj) = (shift, shift);
  my @fields;

  if (@_)
  {
    my %fields;

    if ($_[0] =~ /^-/)
    {
      $fields{$_} = 1
        foreach ($metaclass->GetAttributeNames());
    }

    my ($x, $f);
    foreach my $f_ (@_)
    {
      ($x, $f) = $f_ =~ /^([+-]?)(.*)/;
      $x = ($x // '+') ne '-';
      $fields{$_} = $x foreach ($metaclass->_Fields($obj, $f));
    }

    @fields = keys(%fields);
  }
  else
  {
    @fields = $metaclass->GetAttributeNames();
  }

  return @fields;
}

# ==== Implementation =========================================================

# ---- Object construction ----------------------------------------------------

sub __bp__new
{
  # my ($hook_name, $stash, $metaclass, $class, @rest) = @_;
  my (undef, $stash, undef, $class) = (shift, shift, shift, shift);
  return bless({}, $class);
}

sub __bp_new
{
  # my ($hook_name, $stash, $metaclass, $class, @rest) = @_;
  my (undef, $stash, undef, $class) = (shift, shift, shift, shift);
  return $class->_new($stash)->_Initialize($stash, @_);
}

sub __bp__Initialize
{
  # my ($hook_name, $stash, $metaclass, $obj, @rest) = @_;
  shift; shift;
  my ($metaclass, $obj, $init) = @_;

  $metaclass->Confess("Initializer should be undef or hash")
    if (defined($init) && (ref($init) ne 'HASH'));

  my %done;
  foreach ($metaclass->GetAttributeNames())
  {
    $done{$_} = 1;

    if ($init && exists($init->{$_}))
    {
      $obj->_InitializeAttribute($_, $init->{$_});
    }
    else
    {
      $obj->_InitializeAttribute($_);
    }
  }

  my @missed = grep { !$done{$_} } keys(%{$init});
  $metaclass->Croak(
      "Bad initializers: " . join(', ', @missed))
    if @missed;

  $obj->Verify();

  return $obj;
}

sub __bp_Clone
{
  my ($hook_name, $stash, $metaclass, $obj, $patch) = @_;
  my $clone = $patch ? { %{$patch} } : {};

  my $class = ref($obj);
  $metaclass->Croak("$hook_name called on $obj (not object)")
    unless $class;

  my @v;
  foreach my $attr_name ($metaclass->GetAttributeNames())
  {
    $clone->{$attr_name} = $v[0]
      if (!exists($clone->{$attr_name}) &&
          (@v = $obj->_CloneAttribute($attr_name, $clone, $patch)));
  }

  return $class->new($stash, $clone);
}

# ---- Dirty ------------------------------------------------------------------

sub __bp_GetDirty
{
  # my ($hook_name, $stash, $metaclass, $obj, @rest) = @_;
  shift; shift; shift;
  my $obj = shift;
  my @ret;

  if ($obj->{':dirty'})
  {
    if (@_)
    {
      my $dirty = $obj->{':dirty'};
      @ret = grep { $dirty->{$_} } @_;
    }
    else
    {
      @ret = keys(%{$obj->{':dirty'}});
    }
  }

  return @ret;
}

sub __bp_SetDirty
{
  # my ($hook_name, $stash, $metaclass, $obj, @rest) = @_;
  shift; shift;
  my ($metaclass, $obj) = (shift, shift);

  my $dirty = $obj->{':dirty'} //= {};
  $dirty->{$_} = 1
    foreach ($metaclass->Fields($obj, @_));

  return $obj;
}

sub __bp_ClearDirty
{
  # my ($hook_name, $stash, $metaclass, $obj, @rest) = @_;
  shift; shift;
  my ($metaclass, $obj) = (shift, shift);

  my $dirty = $obj->{':dirty'};
  if (@_)
  {
    foreach my $attr_name (@_)
    {
      $metaclass->Croak(
          "ClearDirty: No attribute named '$attr_name'")
        unless $metaclass->GetAttribute($attr_name);
      delete($dirty->{$attr_name}) if $dirty;
    }
  }
  else
  {
    $obj->{':dirty'} = {} if $dirty;
  }

  return $obj;
}

# ---- Pick -------------------------------------------------------------------

sub __bp_Pick
{
  my ($hook_name, $stash, $metaclass, $obj, @ns) = @_;
  return map { ($_ => scalar($obj->Get($_))) } @ns if wantarray;
  return { map { ($_ => scalar($obj->Get($_))) } @ns };
}

# ---- Edit -------------------------------------------------------------------

sub __bp_Edit
{
  my ($hook_name, $stash, $metaclass, $obj, $data) = @_;

  $metaclass->Confess("$hook_name called on $obj (class)")
    unless ref($obj);

  if ($data)
  {
    $metaclass->Croak("Bad data for $hook_name")
      unless (ref($data) eq 'HASH');

    foreach my $attr_name (keys(%{$data}))
    {
      $metaclass->Croak("$hook_name: Unknown attribute '$attr_name'")
        unless $metaclass->GetAttribute($attr_name);
    }

    foreach my $attr_name ($metaclass->GetAttributeNames())
    {
      $obj->Set($attr_name => $data->{$attr_name})
        if exists($data->{$attr_name});
    }

    $obj->Verify();
  }

  return $obj;
}

# ---- Verify -----------------------------------------------------------------

sub __bp_Verify { return }

# -----------------------------------------------------------------------------

sub __forward_to_attr
{
  # my ($hook_name, $stash, $metaclass, $obj, $n, @rest) = @_;
  my ($hook_name, $stash, $metaclass, $obj, $n) = (shift, shift, shift, @_);

  # $metaclass->Confess("$hook_name called on $obj (class)")
  #   unless ref($obj);

  my $metaattr = $metaclass->GetAttribute($n) or
    $metaclass->Confess("$hook_name called for unknown property '$n'");

  return $metaattr->_RunHook(
      $hook_name, $hook_name, $stash, $metaclass, $metaattr, @_);
}

sub _HookDefaultAction
{
  # ($self, $hook_name, @run_hook_args) = @_;
  my $sub;

  if ($sub = $_[0]->can("__bp_$_[1]"))
  {
    shift; shift;
    return $sub->(@_);
  }
  elsif ($_[1] =~ $ReAttrMethods)
  {
    shift; shift;
    return __forward_to_attr(@_);
  }

  return shift->next::method(@_);
}

###############################################################################

1
