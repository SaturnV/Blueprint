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
      'flags' => { ':type' => 'uint', ':default.new' => 1 },
      'a' => { ':type' => 'flag', ':default.new' => 1, ':mask' => 16 });
}

my $obj = TestClass->new();
isa_ok($obj, 'TestClass', 'new');
is(scalar($obj->Get('flags')), 17, 'new flags');
is(scalar($obj->Get('a')), 1, 'new a');

$obj->Set('a' => 0);
is(scalar($obj->Get('flags')), 1, 'clear flags');
is(scalar($obj->Get('a')), 0, 'clear a');

$obj->Set('a' => 1);
is(scalar($obj->Get('flags')), 17, 'set flags');
is(scalar($obj->Get('a')), 1, 'set a');

# dies_ok { $obj->Set('a' => undef) } 'set undef';
dies_ok { $obj->Set('a' => 'a') } 'set bad 1';
dies_ok { $obj->Set('a' => 2) } 'set bad 2';

done_testing();
