#! /usr/bin/perl
###### NAMESPACE ##############################################################

package Blueprint::MetaAttribute;

###### IMPORTS ################################################################

use Essence::Strict;

use parent 'Blueprint::MetaBase';

use List::MoreUtils;

use Blueprint::Utils;

###### METHODS ################################################################

# ==== Constructor + Basic properties =========================================

sub _Initialize
{
  my ($self, $config, $metaclass) = @_;

  $self->{'error_name'} =
      $metaclass->GetName() . '.' . $self->GetName();

  return $self;
}

# ==== Configuration ==========================================================

sub _PreConfigure
{
  my ($self, $config) = @_;

  $self->AddType(delete($config->{':type'}))
   if exists($config->{':type'});

  return shift->next::method(@_);
}

sub _Configure
{
  my ($self, $config, $metaclass) = @_;

  foreach my $m (qw( new Get ))
  {
    $self->_SetConfig(":default.$m" => delete($config->{":default.$m"}))
      if exists($config->{":default.$m"});

    if (exists($config->{":builder.$m"}))
    {
      my $builder = delete($config->{":builder.$m"});
      $self->Confess("Bad :builder.$m")
        unless (!defined($builder) ||
                (ref($builder) eq 'CODE') ||
                ($builder =~ /^[_a-z]\w*\z/i));
      $self->_SetConfig(":builder.$m" => $builder);
    }
  }

  if (exists($config->{':ro'}))
  {
    my $ro = delete($config->{':ro'});
    $self->Confess("Bad :ro")
      unless (!defined($ro) ||
              (List::MoreUtils::all { /^new|Set\z/ } split(/\s*,\s*/, $ro)));
    $self->_SetConfig(':ro' => $ro);
  }

  return shift->next::method(@_);
}

# ==== Type ===================================================================

sub AddType
{
  my ($self, $type) = @_;

  $self->Croak("Already has a type")
    if $self->GetOwnConfig(':type');

  if (defined($type))
  {
    $type = Blueprint::Utils::to_classname(
        $type, 'Blueprint::Types::')
      unless ref($type);

    my $type_ = $self->GetConfig(':type');
    if (!$type_ || ($type_ ne $type))
    {
      $self->_KillType();
      $self->_AddTrait($type);
    }
  }
  else
  {
    $self->_KillType();
  }
  $self->_SetConfig(':type' => $type);

  return $self;
}

# BUG System wide DefaultHandlers vs _KillType
sub _KillType
{
  # my ($self) = @_;
  return $_[0]->_SetConfig('hooks.type', { ':stop' => 1 });
}

# ==== Implementation =========================================================

sub __bp__InitializeAttribute
{
  # my ($hook_name, $stash, $metaclass, $metaattr, $obj, $n, $v) = @_;
  shift; shift;
  my ($metaclass, $metaattr, $obj, $n) = (shift, shift, shift, shift);

  if (@_)
  {
    $obj->Set($n, @_);
  }
  elsif (my $builder = $metaattr->GetConfig(':builder.new'))
  {
    # my $v = $builder->($metaclass, $metaattr, $obj, $n);
    my $v = ref($builder) ?
        $builder->($metaclass, $metaattr, $obj, $n) :
        $obj->$builder($metaclass, $metaattr, $obj, $n);
    $obj->RawSet($n, $v);
  }
  elsif (my @tmp = $metaattr->GetConfig(':default.new'))
  {
    $obj->RawSet($n, $tmp[0]);
  }
  else
  {
    $obj->verify($n);
  }

  return $obj;
}

sub __bp_Clone
{
  #     0           1       2           3          4     5
  # my ($hook_name, $stash, $metaclass, $metaattr, $obj, $n,
  #     $clone, $patch) = @_;
  return ($_[4]->{$_[5]}) if exists($_[4]->{$_[5]});
  return;
}

sub __bp_Get
{
  # my ($hook_name, $stash, $metaclass, $metaattr, $obj, $n, @aux) = @_;
  my (undef, undef, undef, $metaattr, $obj, $n) = (shift, shift, @_);

  # Simple case
  return $obj->{$n} if exists($obj->{$n});

  # Builder -- calls RawSet
  if (my $builder = $metaattr->GetConfig(':builder.Get'))
  {
    # my $v = $builder->($metaclass, $metaattr, $obj, $n, @aux);
    my $v = ref($builder) ? $builder->(@_) : $obj->$builder(@_);
    $obj->RawSet($n, $v);
    return $v;
  }

  # Default
  return $metaattr->GetConfig(':default.Get');
}

sub __bp_Set
{
  # my ($hook_name, $stash, $metaclass, $metaattr, $obj, $n, $v) = @_;
  my ($hook_name, $stash, $metaclass, $metaattr, $obj, $n, $v) =
      (shift, shift, shift, shift, shift, @_);

  my $err;
  if (my $ro = $metaattr->GetConfig(':ro'))
  {
    $err = "Trying to set read-only attribute"
      if ($stash->IsInsideMethod('new') ?
              ($ro =~ /\bnew\b/) :
              ($ro =~ /\bSet\b/));
  }
  $err //= $obj->verify(@_);
  $metaattr->Confess($err) if $err;

  return $obj->RawSet(@_);
}

sub __bp_RawSet
{
  # my ($hook_name, $stash, $metaclass, $metaattr, $obj, $n, $v) = @_;
  my ($hook_name, $stash, $metaclass, $metaattr, $obj, $n, $v) =
      (shift, shift, shift, shift, shift, @_);
  $obj->SetDirty($n);
  return $obj->_Set(@_);
}

sub __bp__Set
{
  # my ($hook_name, $stash, $metaclass, $metaattr, $obj, $n, $v) = @_;
  return $_[4]->{$_[5]} = $_[6];
}

sub __bp_verify
{
  # my ($hook_name, $stash, $metaclass, $metaattr, $class, $n, $v) = @_;
  # my ($hook_name, $stash, $metaclass, $metaattr, $class, $n) = @_;
  return;
}

sub _HookDefaultAction
{
  # ($self, $hook_name, @run_hook_args) = @_;

  if (my $sub = $_[0]->can("__bp_$_[1]"))
  {
    shift; shift;
    return $sub->(@_) if $sub;
  }

  return shift->next::method(@_);
}

###############################################################################

1
