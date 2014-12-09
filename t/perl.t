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
      'perl' => { ':type' => 'perl' });
}

my $obj = TestClass->new({ 'perl' => {} });
isa_ok($obj, 'TestClass', 'new');

dies_ok { $obj->Set('perl' => 1) } 'set bad';
lives_ok { $obj->Set('perl' => { 'a' => 1 }) } 'set good';

my $db = $obj->SerializeToDb();
like($db->{'perl'},
    qr/^ \s* \{ \s* 'a' \s* => \s* 1 \} \s* \z/x,
    'db');

my $json = $obj->SerializeToJson();
is_deeply($json->{'perl'}, { 'a' => 1 }, 'json');

done_testing();
