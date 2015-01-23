#! /usr/bin/perl
###### NAMESPACE ##############################################################

package Blueprint::MetaBase;

###### IMPORTS ################################################################

use Essence::Strict;

use parent qw( Essence::Logger::Mixin Blueprint::InheritableData );

use Essence::Module;
use List::Util;

use Blueprint::Utils;

###### METHODS ################################################################

sub log_prefix
{
  return (ref($_[0]) && $_[0]->{'error_name'}) || shift->next::method(@_);
}

# ==== Constructor ============================================================

sub new
{
  my ($my_class, $name, $ancestors) = (shift, shift, shift);
  my $self = bless(
      { 'name' => $name, 'ancestors' => $ancestors // [] },
      $my_class);
  $self->_Initialize(@_);
  return $self->__Configure(@_);
}

sub _Initialize { return $_[0] }

# ==== Basic Properties =======================================================

sub GetName { return $_[0]->{'name'} }
sub GetAncestors { return @{$_[0]->{'ancestors'}} }

# ==== Configuration ==========================================================

sub __Configure
{
  my ($self, $config_in, @rest) = (shift, shift, @_);

  $self->Confess("Already configured")
    if $self->{'config'};

  $self->{'config.orig'} = $config_in;
  $self->{'config'} = {};

  my $config_tmp = {};
  # x.y should be set after x
  foreach (sort keys(%{$config_in}))
  {
    if (/^:/)
    {
      $config_tmp->{$_} = $config_in->{$_};
    }
    else
    {
      $self->SetMeta($_ => $config_in->{$_});
    }
  }

  $self->_PreConfigure($config_tmp, @rest);
  $self->_Configure($config_tmp, @rest);

  $self->Confess(
      "Unknown config(s): " . join(', ', keys(%{$config_tmp})))
    if %{$config_tmp};

  return $self;
}

sub _PreConfigure
{
}

# Override me
sub _Configure { return $_[0] }

# ==== Traits =================================================================

sub _AddTrait
{
  my ($self, $trait) = (shift, shift);

  Essence::Module::load_module($trait)
    unless ref($trait);

  if (ref($trait) eq 'CODE')
  {
    $trait->($self, @_);
  }
  else
  {
    $trait->infect($self, @_);
  }

  return $self;
}

sub AddTrait
{
  my ($self, $trait) = (shift, shift);

  $self->Croak("Undefined trait")
    unless defined($trait);

  $trait = Blueprint::Utils::to_classname(
      $trait, 'Blueprint::Traits::')
    unless ref($trait);

  $self->_AddTrait($trait, @_);

  return $self;
}

# ==== Hooks ==================================================================

sub _AddHook
{
  my ($self, $hook_name, $id, $sub) = @_;

  my $order = $self->GetOwnConfig("hook_order.$hook_name");
  $self->_SetConfig("hook_order.$hook_name", $order = [])
    unless $order;
  unshift(@{$order}, $id)
    unless (List::MoreUtils::any(sub { $id eq $_ }, @{$order}));
    # For some reason beyond me this doesn't work:
    # unless (List::MoreUtils::any { $id eq $_ } @{$order});

  $self->_SetConfig("hooks.$id.$hook_name", $sub);

  return $self;
}

sub _RemoveHook
{
  my ($self, $hook_name, $id) = @_;

  if (my $order = $self->GetOwnConfig("hook_order.$hook_name"))
  {
    if (my @order = grep { $id ne $_ } @{$order})
    {
      $self->_SetConfig("hook_order.$hook_name", \@order);
    }
    else
    {
      $self->_ClearConfig("hook_order.$hook_name");
    }
  }

  $self->_ClearConfig("hooks.$id.$hook_name");
}

sub _RunHook
{
  my ($self, $hook_name) = (shift, shift);

  # Shortcut 1
  my $order = $self->GetConfig("hook_order.$hook_name");
  return $self->_HookTerminator($hook_name, @_)
    unless $order;

  my ($sub, @callbacks);
  foreach my $id (@{$order})
  {
    push(@callbacks, $sub)
      if ($sub = $self->GetConfig("hooks.$id.$hook_name"));
  }

  # Shortcut 2
  return $self->_HookTerminator($hook_name, @_)
    unless @callbacks;

  # Handlers are called with $next as first parameter
  # A handler should look like this:
  # sub __some_hook_handler
  # {
  #   my ($next, @rest) = @_;
  #   return $next->(@rest);
  # }
  # So $next is called without $next.

  # This is the last $next => no need to shift $next
  my $hook = sub { return $self->_HookTerminator($hook_name, @_) };

  while (@callbacks)
  {
    my $next = $hook;
    my $cb = pop(@callbacks);
    $hook = sub { return $cb->($next, @_) };
  }

  return $hook->(@_);
}

# Forward to ancestors then call default
sub _HookTerminator
{
  # ($self, $hook_name, @run_hook_args) = @_;
  my $self = shift;

  my $stash = List::Util::first { ref($_) eq 'Blueprint::_Stash' } @_;
  my $next_ancestor = $stash->{'Blueprint::MetaBase::NextAncestor'} //= [];
  unshift(@{$next_ancestor}, $self->GetAncestors());

  return @{$next_ancestor} ?
      shift(@{$next_ancestor})->_RunHook(@_) :
      $self->_HookDefaultAction(@_);
}

sub _HookDefaultAction
{
  my ($self, $hook_name) = (shift, shift);
  my $class = ref($self) || $self;

  my $dh;
  {
    no strict 'refs';
    $dh = ${"${class}::DefaultHandlers"}->{$hook_name};
  }

  return $dh->(@_) if ($dh && ($dh = $dh->{'cb'}));
  return;
}

sub add_default_handler
{
  my ($class, $hook_name, $id, $cb) = @_;

  $class->Croak(
      "add_default_handler called on object (not class)")
    if ref($class);

  my $dh;
  {
    no strict 'refs';
    $dh = "${class}::DefaultHandlers"->{$hook_name};
  }

  $class->Croak(
      "Conflicting DefaultHandlers for '$hook_name'")
    if ($dh && defined($dh->{'id'}) && ($dh->{'id'} ne $id));

  $dh = { 'id' => $id, 'cb' => $cb };
  {
    no strict 'refs';
    my $dhs = ${"${class}::DefaultHandlers"} //= {};
    $dhs->{$hook_name} = $dh;
  }

  return $class;
}

# ==== InheritableData ========================================================

sub _GetAncestors { return @{$_[0]->{'ancestors'}} }

# ---- Config -----------------------------------------------------------------

sub GetConfig
{
  # my ($self, $n) = (shift, shift);
  # return $self->_Get("config.$n", @_);
  return shift->_Get('config.' . shift, @_);
}

sub GetOwnConfig
{
  # my ($self, $n) = (shift, shift);
  # return scalar($self->_GetOwn("config.$n", @_));
  return scalar(shift->_GetOwn('config.' . shift, @_));
}

sub _SetConfig
{
  # my ($self, $n) = (shift, shift);
  # return $self->_Set("config.$n", @_);
  return shift->_Set('config.' . shift, @_);
}

sub _ClearConfig
{
  # my ($self, $n) = (shift, shift);
  # return $self->_Clear("config.$n", @_);
  return shift->_Clear('config.' . shift, @_);
}

# ---- Meta -----------------------------------------------------------------

sub GetMeta
{
  # my ($self, $n) = (shift, shift);
  # return $self->_Get("meta.$n", @_);
  return shift->_Get('meta.' . shift, @_);
}

sub GetOwnMeta
{
  # my ($self, $n) = (shift, shift);
  # return scalar($self->_GetOwn("meta.$n", @_));
  return scalar(shift->_GetOwn('meta.' . shift, @_));
}

sub SetMeta
{
  # my ($self, $n) = (shift, shift);
  # return $self->_Set("meta.$n", @_);
  return shift->_Set('meta.' . shift, @_);
}

sub ClearMeta
{
  # my ($self, $n) = (shift, shift);
  # return $self->_Clear("meta.$n", @_);
  return shift->_Clear('meta.' . shift, @_);
}

###############################################################################

1
