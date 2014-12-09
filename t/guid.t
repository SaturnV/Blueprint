#! /usr/bin/perl

use Test::More;
use Test::Exception;
use Essence::Strict;
use Essence::UUID;

{
  package Guid;
  use Essence::Strict;
  use parent 'Blueprint';
  __PACKAGE__->blueprint(
      'id' => { ':type' => 'guid' },
      'opt' => { ':type' => 'opt_guid' });
}

my $obj = Guid->new();
isa_ok($obj, 'Guid', 'new');
ok(defined($obj->Get('id')), 'new id');
ok(!defined($obj->Get('opt')), 'new opt');

lives_ok { $obj->Set('id', uuid_hex()) } 'id set good';
dies_ok { $obj->Set('id', 'a') } 'id set bad';
dies_ok { $obj->Set('id', undef) } 'id set none';
# dies_ok { $obj->Clear('id') } 'id clear';

lives_ok { $obj->Set('opt', uuid_hex()) } 'opt set good';
dies_ok { $obj->Set('opt', 'a') } 'opt set bad';
lives_ok { $obj->Set('opt', undef) } 'opt set none';
# lives_ok { $obj->Clear('opt') } 'opt clear';

done_testing();
