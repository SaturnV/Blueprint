#! /usr/bin/perl
# TODO croak $mod_name -> croak $class or something
###### NAMESPACE ##############################################################

package Blueprint::Traits::_DbBase;

###### IMPORTS ################################################################

use Essence::Strict;

use Carp;

###### VARS ###################################################################

my $mod_name = __PACKAGE__;

###### METHODS ################################################################

# ==== (De)Serialize ==========================================================

sub SerializeToDb
{
  # my ($self, @fields) = @_;
  return shift->__bp_run_hook('SerializeToDb', @_);
}

sub deserialize_from_db
{
  # my ($self, $db_hash) = @_;
  return shift->__bp_run_hook('deserialize_from_db', @_);
}

sub _db_serialize_where
{
  # my ($class, $where) = @_;
  # TODO
  return $_[1];
}

# ==== Utils ==================================================================

sub _DbWhere
{
  my ($obj, $stash, $fn) = @_;
  my $where;

  my $metaclass = $obj->get_metaclass();
  my $key = $metaclass->GetConfig('db.key');
  if (!defined($key))
  {
    my $id_attr = $metaclass->GetAttribute('id');
    $key = 'id' if ($id_attr && $id_attr->GetMeta('db'));
  }
  if (ref($key))
  {
    $where->{$_} = $obj->Get($_)
      foreach (@{$key});
  }
  elsif (($key // '') ne '')
  {
    $where->{$key} = $obj->Get($key);
  }
  else
  {
    $metaclass->Croak("$fn: No key given");
  }

  return $obj->_db_serialize_where($where);
}

# ==== SELECT =================================================================

sub _db_select
{
  my ($class, $stash, @select) = @_;

  my $db = $stash->Get('db') or
    croak "$mod_name: db_select: No db";

  my $metaclass = $class->get_metaclass() or
    croak "$mod_name: db_select: Can't find metaclass for '$class'";

  my @loaded = $db->do_select_hash(@select);
  if (!wantarray && $#loaded)
  {
    $metaclass->Croak("Object not found")
      unless @loaded;
    $metaclass->Carp("Discarding loaded objects");
    pop(@loaded);
  }

  @loaded = map { $class->deserialize_from_db($stash, $_) } @loaded;

  return @loaded if wantarray;
  return $loaded[0];
}

sub db_load
{
  my ($self, $stash, $where, $opts) = @_;
  $opts //= {};

  my $class = ref($self) || $self;
  croak "$class: db_load called on object (not class)"
    if ref($self);

  $where = $class->_db_serialize_where($where)
    if $where;

  $opts->{':limit'} = 2
    unless (wantarray || exists($opts->{':limit'}));

  my $metaclass = $class->get_metaclass() or
    croak "$mod_name: db_select: Can't find metaclass for '$class'";
  my $table = $metaclass->GetConfig('db.table') or
    $metaclass->Croak("db_load: No table given");

  return $class->_db_select($stash, $table, undef, $where, $opts);
}

# ==== INSERT =================================================================

sub DbInsert
{
  my ($obj, $stash) = @_;

  croak "$mod_name: DbInsert called on $obj (class)"
    unless ref($obj);

  my $db_obj = $obj->SerializeToDb($stash);

  my $db = $stash->Get('db') or
    croak "$mod_name: DbInsert: No db";

  my $metaclass = $obj->get_metaclass() or
    croak "$mod_name: DbInsert: Can't find metaclass for '" . ref($obj) . "'";
  my $table = $metaclass->GetConfig('db.table') or
    $metaclass->Croak("DbInsert: No table given");

  return $db->do_insert($table, $db_obj);
}

# ==== UPDATE =================================================================

sub DbUpdate
{
  my ($obj, $stash, $opts) = @_;

  croak "$mod_name: DbUpdate called on $obj (class)"
    unless ref($obj);

  my ($db_obj) = $obj->SerializeToDb($stash, ':dirty');
  return 0 unless $db_obj;

  my $db = $stash->Get('db') or
    croak "$mod_name: DbUpdate: No db";

  my $metaclass = $obj->get_metaclass() or
    croak "$mod_name: DbUpdate: Can't find metaclass for '" . ref($obj) . "'";
  my $table = $metaclass->GetConfig('db.table') or
    $metaclass->Croak("DbUpdate: No table given");

  my $where = $obj->{':db.where'} // $obj->_DbWhere($stash, 'DbUpdate');

  return $db->do_update($table, $db_obj, $where, $opts);
}

# ==== DELETE =================================================================

sub db_delete
{
  my ($self, $stash, $where, $opts) = @_;
  $opts //= {};

  my $class = ref($self) || $self;
  croak "$class: db_delete called on object (not class)"
    if ref($self);

  $where = $class->_db_serialize_where($where)
    if $where;

  my $db = $stash->Get('db') or
    croak "$mod_name: db_delete: No db";

  my $metaclass = $class->get_metaclass() or
    croak "$mod_name: db_delete: Can't find metaclass for '$class'";
  my $table = $metaclass->GetConfig('db.table') or
    $metaclass->Croak("db_delete: No table given");

  return $db->do_delete($table, $where, $opts);
}

sub DbDelete
{
  my ($obj, $stash, $opts) = @_;

  croak "$mod_name: DbDelete called on $obj (class)"
    unless ref($obj);

  my $db = $stash->Get('db') or
    croak "$mod_name: DbDelete: No db";

  my $metaclass = $obj->get_metaclass() or
    croak "$mod_name: DbDelete: Can't find metaclass for '" . ref($obj) . "'";
  my $table = $metaclass->GetConfig('db.table') or
    $metaclass->Croak("DbDelete: No table given");

  my $where = $obj->{':db.where'} // $obj->_DbWhere($stash, 'DbDelete');

  return $db->do_delete($table, $where, $opts);
}

# ==== Utility ================================================================

sub db_create
{
  my ($class, $stash) = (shift, shift);
  my $obj = $class->new($stash, @_);
  $obj->DbInsert($stash);
  return $obj;
}

###############################################################################

1
