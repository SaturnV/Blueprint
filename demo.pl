#! /usr/bin/perl

use Essence::Strict;
use JSON;

# Create a class
{
  package Demo;

  use Essence::Strict;
  use parent 'Blueprint';

  Demo->blueprint(
      ':traits' => { 'json' => {} },
      ':defaults' => { 'json' => 1 },

      'timestamp' => { ':type' => 'timestamp_ms' },
      'count' => { ':type' => 'uint' },
      'no_json' =>
          {
            ':type' => 'string',
            ':default.new' => 'x',
            'json' => 0
          });
}

# Basics
my $object = Demo->new({ 'count' => 2 });
say "timestamp: " . $object->Get('timestamp');
$object->Set('no_json' => 'hello');

# JSON
say "json: " . to_json($object->SerializeToJson());
