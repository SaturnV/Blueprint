#! /usr/bin/perl
###### NAMESPACE ##############################################################

package Blueprint::Traits::Json;

###### IMPORTS ################################################################

use Essence::Strict;

use Carp;

use Blueprint::Traits::_JsonBase;

###### VARS ###################################################################

my $mod_name = __PACKAGE__;

###### METHODS ################################################################

sub infect
{
  my ($my_class, $metaclass, $params, $class_config) = @_;

  croak "$mod_name: Can only infect classes"
    unless $metaclass->isa('Blueprint::MetaClass');

  $metaclass->_AddHook(
      'SerializeToJson', $mod_name, \&__SerializeToJson_Class);
  Blueprint::MetaAttribute->add_default_handler(
      'SerializeToJson', $mod_name, \&__SerializeToJson_Attr);

  my $class = $metaclass->GetName();
  if (!$class->isa('Blueprint::Traits::_JsonBase'))
  {
    no strict 'refs';
    push(@{"${class}::ISA"}, 'Blueprint::Traits::_JsonBase');
  }

  $metaclass->_SetConfig('json' => $params)
    if $params;

  return $my_class;
}

# Proper hook callback
sub __SerializeToJson_Class
{
  # my ($next, $hook_name, $stash, $metaclass, $obj, @fields) = @_;
  my (undef, $hook_name, $stash, $metaclass, $obj) =
      (shift, shift, shift, shift, shift);
  my $ret = {};

  $metaclass->Croak("$hook_name called on $obj (class)")
    unless ref($obj);

  my ($metaattr, @v);
  foreach my $f ($metaclass->Fields(@_))
  {
    $metaattr = $metaclass->GetAttribute($f);
    next unless $metaattr->GetMeta('json');
    warn "d $f " . Data::Dumper::Dumper($metaattr)
      if ($f eq 'b');

    @v = $metaattr->_RunHook(
        $hook_name, $hook_name, $stash, $metaclass, $metaattr,
        $obj, $f, $obj->Get($f));
    $ret->{$f} = $v[0] if @v;
  }

  return %{$ret} ? ($ret) : () if wantarray;
  return $ret;
}

# DefaultHandler, no next
sub __SerializeToJson_Attr
{
  # my ($hook_name, $stash, $metaclass, $metaattr, $obj, $n, $v) = @_;
  shift; shift; shift; shift; shift; shift;
  return @_;
}

###############################################################################

1
