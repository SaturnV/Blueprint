#! /usr/bin/perl

use Test::More;
use Test::Exception;
use Essence::Strict;
use Essence::Logger;

{
  package TestClass;
  use Essence::Strict;
  use parent 'Blueprint';
  __PACKAGE__->blueprint(
      ':traits' => { 'db' => {}, 'json' => {} },
      ':defaults' => { 'db' => 1, 'json' => 1 },
      'json' => { ':type' => 'json' });
}

my $obj = TestClass->new({ 'json' => {} });
isa_ok($obj, 'TestClass', 'new');

dies_ok { $obj->Set('json' => 1) } 'set bad';
lives_ok { $obj->Set('json' => { 'a' => 1 }) } 'set good';

my $db = $obj->SerializeToDb();
is($db->{'json'}, '{"a":1}', 'db');

my $json = $obj->SerializeToJson();
is_deeply($json->{'json'}, { 'a' => 1 }, 'json');

done_testing();
