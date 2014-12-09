#! /usr/bin/perl

use Test::More;
use Test::Exception;
use Essence::Strict;

{
  package TestClass;
  use Essence::Strict;
  use parent 'Blueprint';
  __PACKAGE__->blueprint(
      's'      => { ':type' => 'timestamp' },
      'ms'     => { ':type' => 'timestamp_ms' },
      'us'     => { ':type' => 'timestamp_us' },
      'opt_s'  => { ':type' => 'opt_timestamp' },
      'opt_ms' => { ':type' => 'opt_timestamp_ms' },
      'opt_us' => { ':type' => 'opt_timestamp_us' });
}

my $obj = TestClass->new();
isa_ok($obj, 'TestClass', 'new');

dies_ok { $obj->Set($_ => 1) } "$_ set bad"
  foreach (qw( s ms us opt_s opt_ms opt_us ));
dies_ok { $obj->Set($_ => undef) } "$_ set undef"
  foreach (qw( s ms us ));
lives_ok { $obj->Set($_ => undef) } "$_ set undef"
  foreach (qw( opt_s opt_ms opt_us ));

lives_ok { $obj->Set('s' => '2000-01-01 00:00:00') } 's set good';
lives_ok { $obj->Set('ms' => '2000-01-01 00:00:00.000') } 'ms set good';
lives_ok { $obj->Set('us' => '2000-01-01 00:00:00.000000') } 'us set good';
lives_ok { $obj->Set('opt_s' => '2000-01-01 00:00:00') } 'opt_s set good';
lives_ok { $obj->Set('opt_ms' => '2000-01-01 00:00:00.000') } 'opt_ms set good';
lives_ok { $obj->Set('opt_us' => '2000-01-01 00:00:00.000000') } 'opt_us set good';

done_testing();
