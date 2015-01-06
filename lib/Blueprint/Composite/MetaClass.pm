#! /usr/bin/perl
###### NAMESPACE ##############################################################

package Blueprint::Composite::MetaClass;

###### IMPORTS ################################################################

use Essence::Strict;

use parent 'Blueprint::MetaClass';

use Essence::Merge;
use Scalar::Util;

###### METHODS ################################################################

sub _FigureOutAttributes
{
  my ($self, $components) = @_;

  # attributes
  my $c_meta;
  my @attributes;
  my %attributes;
  # my %attribute_sources;
  foreach my $c (@{$components})
  {
    $c_meta = eval { $c->get_metaclass() };
    $self->Croak("Can't get metaclass for $c ($@)") if $@;
    $self->Croak("Can't get metaclass for $c") unless $c_meta;

    foreach my $attr_name ($c_meta->GetAttributeNames())
    {
      if ($attributes{$attr_name})
      {
        # push(@{$attribute_sources{$attr_name}}, $c);
      }
      else
      {
        $attributes{$attr_name} = $c_meta->GetAttribute($attr_name);
        # $attribute_sources{$attr_name} = [$c];
        push(@attributes, $attr_name);
      }
    }
  }

  # $self->{'%attribute_sources'} = \%attribute_sources;
  $self->{'%attributes'} = \%attributes;
  $self->{'@attributes'} = \@attributes;

  return;
}

sub _Initialize { return $_[0] }

sub _Configure
{
  my ($self, $config) = @_;
  my $ret = shift->next::method(@_);

  $self->Croak("No components")
    unless exists($config->{':components'});

  my $components = delete($config->{':components'});

  $self->Confess(":components should be an ARRAY")
    unless (ref($components) eq 'ARRAY');
  $self->Croak("No components")
    unless @{$components};

  $self->_FigureOutAttributes($components);

  $self->_SetConfig(':components', $components);

  return $ret;
}

# ==== Attributes =============================================================

# TODO/BUG GetAttribute returns the first matching attribute.
#     This may or may not be what was expected. It may not be the
#     attribute that made GetAttributeNamesWithMeta return a name.

sub AddAttribute
{
  # my ($self, $attr_name, $attr_conf, $inherited_from) = @_;
  $_[0]->Croak("Can't add attribute to a composite class");
}

sub GetAttributeNamesWithMeta
{
  my ($self, @rest) = @_;
  return @{Essence::Merge::merge_array(
      map { [$_->GetAttributeNamesWithMeta(@rest)] }
          @{$self->GetConfig(':components')})};
}

# ==== Implementation =========================================================

# ---- Own --------------------------------------------------------------------

sub __bp_assemble
{
  # my ($hook_name, $stash, $metaclass, $class, @rest) = @_;
  my (undef, $stash, $metaclass, $class, @components) = @_;
  my $obj = $class->_new($stash);
  $obj->{':components'} = [@components];
  $obj->Verify($stash);
  return $obj;
}

sub __bp_GetComponents
{
  # my ($hook_name, $stash, $metaclass, $obj, @rest) = @_;
  return @{$_[3]->{':components'}};
}

# ---- Class ------------------------------------------------------------------

# unchanged: _new
# unchanged: new

sub __bp__Initialize
{
  # my ($hook_name, $stash, $metaclass, $obj, @rest) = @_;
  my (undef, $stash, $metaclass, $obj, $init_in) = @_;

  $metaclass->Croak("Initializer should be undef or hash")
    if (defined($init_in) && (ref($init_in) ne 'HASH'));

  my ($c_meta, $c_obj, @c_objs, %done, @t);
  my $init = { %{$init_in} };
  my $components = $metaclass->GetConfig(':components');
  foreach my $c (@{$components})
  {
    $c_meta = eval { $c->get_metaclass() };
    $metaclass->Croak("Can't get metaclass for $c ($@)") if $@;
    $metaclass->Croak("Can't get metaclass for $c") unless $c_meta;
    next unless $c_meta;

    my $c_init = {};
    my @attr_names = $c_meta->GetAttributeNames();
    foreach my $attr_name (@attr_names)
    {
      if (exists($init->{$attr_name}))
      {
        $c_init->{$attr_name} = $init->{$attr_name};
        $done{$attr_name} = 1;
      }
    }

    $c_obj = $c->new($stash, $c_init);

    foreach my $attr_name (@attr_names)
    {
      @t = $c_obj->Get($stash, $attr_name);
      $init->{$attr_name} = $t[0] if @t;
    }

    push(@c_objs, $c_obj);
  }

  my @missed = grep { !$done{$_} } keys(%{$init_in});
  $metaclass->Croak(
      "Bad initializers: " . join(', ', @missed))
    if @missed;

  $obj->{':components'} = \@c_objs;
  $obj->Verify($stash);

  return $obj;
}

sub __bp_Clone
{
  # my ($hook_name, $stash, $metaclass, $obj, $patch) = @_;
  my (undef, $stash, undef, $obj, @rest) = @_;
  return ref($obj)->assemble($stash,
      map { $_->Clone($stash, @rest) }
          $obj->GetComponents($stash));
}

sub __filter_dirty_args
{
  my $obj = shift;
  my $metaclass = $obj->get_metaclass();
  my @ret = grep {
                   /^:/ || !/^[+-]?(.*)/ || $metaclass->GetAttribute($1)
                 } $metaclass->GetAttributeNames();
  @ret = qw( :none ) if (@_ && !@ret);
  return @ret;
}

sub __forward_dirty
{
  my ($hook_name, $stash, $metaclass, $obj, @rest) = @_;

  foreach my $c ($obj->GetComponents($stash))
  {
    $c->$hook_name($stash, __filter_dirty_args($c, @rest));
  }

  return $obj;
}

sub __bp_GetDirty
{
  # my ($hook_name, $stash, $metaclass, $obj, @rest) = @_;
  my (undef, $stash, undef, $obj, @rest) = @_;
  return @{Essence::Merge::merge_arrays(
      map { [$_->GetDirty($stash, @rest)] }
          $obj->GetComponents($stash))};
}

sub __bp_SetDirty { return __forward_dirty(@_) }
sub __bp_ClearDirty { return __forward_dirty(@_) }

# unchanged: Edit

sub __bp_Verify
{
  # my ($hook_name, $stash, $metaclass, $obj, @rest) = @_;
  my (undef, $stash, $metaclass, $obj) = @_;

  # Check objects/classes
  my @c_objs = @{$obj->{':components'}};
  my @c_classes = @{$metaclass->GetConfig(':components')};
  $metaclass->Confess("Bad number of components")
    unless (scalar(@c_objs) == scalar(@c_classes));
  foreach my $i (0 .. $#c_objs)
  {
    $metaclass->Confess("Components should be objects")
      unless Scalar::Util::blessed($c_objs[$i]);
    $metaclass->Confess("'" . ref($c_objs[$i]) . "' isn't a '$c_classes[$i]'")
      unless $c_objs[$i]->isa($c_classes[$i]);
  }

  # TODO Check consistency of multi-sourced attributes

  return;
}

# ---- Attributes -------------------------------------------------------------

# moot: InitializeAttribute
# moot: Clone

sub __bp_Get
{
  # my ($hook_name, $stash, $metaclass, $obj, $attr_name) = @_;
  my (undef, $stash, $metaclass, $obj, @rest) = @_;
  my ($attr_name) = @rest;
  my @ret;

  foreach my $c ($obj->GetComponents($stash))
  {
    @ret = $c->Get($stash, @rest)
      if ref($c)->get_metaclass()->GetAttribute($attr_name);
    last if @ret;
  }

  return @ret if wantarray;
  return $ret[0];
}

sub __bp_Set
{
  # my ($hook_name, $stash, $metaclass, $obj, $attr_name, $v) = @_;
  my (undef, $stash, $metaclass, $obj, @rest) = @_;
  my ($attr_name) = @rest;

  my ($ma, $err);
  foreach my $c ($obj->GetComponents($stash))
  {
    $ma->Confess($err)
      if (($ma = ref($c)->get_metaclass()->GetAttribute($attr_name)) &&
          ($err = $ma->CheckReadOnly($stash) // $c->verify($stash, @rest)));
  }

  return $obj->RawSet($stash, @rest);
}

sub __attr_all
{
  # my ($hook_name, $stash, $metaclass, $obj, $attr_name, ...) = @_;
  my ($hook_name, $stash, $metaclass, $obj, @rest) = @_;
  my ($attr_name) = @rest;

  if (wantarray)
  {
    my @ret;
    foreach my $c ($obj->GetComponents($stash))
    {
      push(@ret, $c->$hook_name($stash, @rest))
        if ref($c)->get_metaclass()->GetAttribute($attr_name);
    }
    return @ret;
  }
  else
  {
    my ($ret, $t);
    foreach my $c ($obj->GetComponents($stash))
    {
      $ret //= $t
        if (ref($c)->get_metaclass()->GetAttribute($attr_name) &&
            defined($t = $c->$hook_name($stash, @rest)));
    }
    return $ret;
  }
}

sub __bp_RawSet { return __attr_all(@_) }
sub __bp__Set { return __attr_all(@_) }

sub __bp_verify
{
  # my ($hook_name, $stash, $metaclass, $class, $attr_name, ...) = @_;
  my ($hook_name, $stash, $metaclass, $class, @rest) = @_;
  my ($attr_name) = @rest;

  if (wantarray)
  {
    my @ret;
    foreach my $c (@{$metaclass->GetConfig(':components')})
    {
      return @ret
        if ($c->get_metaclass()->GetAttribute($attr_name) &&
            (@ret = $c->$hook_name($stash, @rest)));
    }
  }
  else
  {
    my $ret;
    foreach my $c (@{$metaclass->GetConfig(':components')})
    {
      return $ret
        if ($c->get_metaclass()->GetAttribute($attr_name) &&
            defined($ret = $c->$hook_name($stash, @rest)));
    }
  }

  return;
}


###############################################################################

1
