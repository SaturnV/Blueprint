#! /usr/bin/perl
###### NAMESPACE ##############################################################

package Blueprint::Traits::Db;

###### IMPORTS ################################################################

use Essence::Strict;

use Carp;

use Blueprint::Traits::_DbBase;

###### VARS ###################################################################

my $mod_name = __PACKAGE__;

###### METHODS ################################################################

sub infect
{
  my ($my_class, $metaclass, $params, $class_config) = @_;

  croak "$mod_name: Can only infect classes"
    unless $metaclass->isa('Blueprint::MetaClass');

  $metaclass->_AddHook(
      'SerializeToDb', $mod_name, \&__SerializeToDb_Class);
  Blueprint::MetaAttribute->add_default_handler(
      'SerializeToDb', $mod_name, \&__SerializeToDb_Attr);

  $metaclass->_AddHook(
      'deserialize_from_db', $mod_name, \&__deserialize_from_db_class);
  Blueprint::MetaAttribute->add_default_handler(
      'deserialize_from_db', $mod_name, \&__deserialize_from_db_attr);

  my $class = $metaclass->GetName();
  if (!$class->isa('Blueprint::Traits::_DbBase'))
  {
    no strict 'refs';
    push(@{"${class}::ISA"}, 'Blueprint::Traits::_DbBase');
  }

  $metaclass->_SetConfig('db' => $params)
    if $params;

  return $my_class;
}

# ==== Serialize ==============================================================

# Proper hook callback
sub __SerializeToDb_Class
{
  # my ($next, $hook_name, $stash, $metaclass, $obj, @fields) = @_;
  my (undef, $hook_name, $stash, $metaclass, $obj) =
      (shift, shift, shift, shift, @_);
  my $ret = {};

  $metaclass->Croak(
      "SerializeToJson called on $obj (class)")
    unless ref($obj);

  my ($metaattr, @v);
  foreach my $f ($metaclass->Fields(@_))
  {
    $metaattr = $metaclass->GetAttribute($f);
    next unless $metaattr->GetMeta('db');

    @v = $metaattr->_RunHook(
        $hook_name, $hook_name, $stash, $metaclass, $metaattr,
        $obj, $f, $obj->Get($f));
    $ret->{$f} = $v[0] if @v;
  }

  return %{$ret} ? ($ret) : () if wantarray;
  return $ret;
}

# DefaultHandler, no next
sub __SerializeToDb_Attr
{
  # my ($hook_name, $stash, $metaclass, $metaattr, $obj, $n, $v) = @_;
  $_[3]->Croak("No support for $_[0]")
    if ((scalar(@_) > 6) && ref($_[6]));
  shift; shift; shift; shift; shift; shift;
  return @_;
}

# ==== Deserialize ============================================================

# Proper hook callback
sub __deserialize_from_db_class
{
  # my ($next, $hook_name, $stash, $metaclass, $class, $db_hash) = @_;
  my (undef, $hook_name, $stash, $metaclass, $class, $db_hash) = @_;
  my $obj = bless({}, $class);

  my ($metaattr, @v);
  foreach my $f (keys(%{$db_hash}))
  {
    next unless (($metaattr = $metaclass->GetAttribute($f)) &&
                 $metaattr->GetMeta('db'));

    @v = $metaattr->_RunHook(
        $hook_name, $hook_name, $stash, $metaclass, $metaattr,
        $obj, $f, $db_hash->{$f}, $db_hash);
    $obj->{$f} = $v[0] if @v;
  }

  $obj->{':db.where'} = $obj->_DbWhere($stash, $hook_name);

  return $obj;
}

# DefaultHandler, no next
sub __deserialize_from_db_attr
{
  # my ($hook_name, $stash, $metaclass, $metaattr, $obj, $n, $v, $db_hash) = @_;
  return $_[6];
}

###############################################################################

1
