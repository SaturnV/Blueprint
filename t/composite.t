#! /usr/bin/perl
###### IMPORTS ################################################################

use Test::More;
use Test::Exception;
use Essence::Strict;
use Essence::Logger;

###### CLASSES ################################################################

{
  package TestClassA;
  use Essence::Strict;
  use parent 'Blueprint';

  __PACKAGE__->blueprint(
      ':defaults' => { 'json' => 1 },
      'a' => { ':type' => 'uint' },
      'p_a' => { ':type' => 'uint', 'json' => 0 },
      'common' => { ':type' => 'opt_uint' });
}

{
  package TestClassB;
  use Essence::Strict;
  use parent 'Blueprint';

  __PACKAGE__->blueprint(
      ':defaults' => { 'json' => 1 },
      'b' => { ':type' => 'uint' },
      'p_b' => { ':type' => 'uint', 'json' => 0 },
      'common' => { ':type' => 'uint' });
}

{
  package TestClassC;
  use Essence::Strict;
  use parent 'Blueprint::Composite';

  __PACKAGE__->composite(
      { ':traits' => { 'json' => {} } },
      'TestClassA',
      'TestClassB');
}

###### CODE ###################################################################

# new
my $obj = TestClassC->new(
    {
      'a' => 1,
      'b' => 2,
      'common' => 3,
      'p_a' => 4,
      'p_b' => 5
    });
isa_ok($obj, 'TestClassC', 'new');
$obj->ClearDirty();

# Get
is_deeply([$obj->Get('a')], [1], 'Get(a)');
is_deeply([$obj->Get('b')], [2], 'Get(b)');
is_deeply([$obj->Get('common')], [3], 'Get(common)');

# Get vs components
my @cs = $obj->GetComponents();
is(scalar(@cs), 2, 'parts length');
isa_ok($cs[0], 'TestClassA', 'Components/A');
isa_ok($cs[1], 'TestClassB', 'Components/B');

is_deeply([$cs[0]->Get('a')], [1], 'A Get(a)');
is_deeply([$cs[0]->Get('common')], [3], 'A Get(common)');
is_deeply([$cs[1]->Get('b')], [2], 'B Get(b)');
is_deeply([$cs[1]->Get('common')], [3], 'B Get(common)');

# Set good
$obj->Set('a' => 1000);
is_deeply([$obj->Get('a')], [1000], 'Set(a) good');
is_deeply([$cs[0]->Get('a')], [1000], 'A Set(a) good');
is_deeply([$obj->Get('b')], [2], 'Set(a) good b');
is_deeply([$obj->Get('common')], [3], 'Set(a) good common');

$obj->Set('b' => 1001);
is_deeply([$obj->Get('b')], [1001], 'Set(b) good');
is_deeply([$cs[1]->Get('b')], [1001], 'B Set(b) good');
is_deeply([$obj->Get('a')], [1000], 'Set(b) good a');
is_deeply([$obj->Get('common')], [3], 'Set(b) good common');

$obj->Set('common' => 1002);
is_deeply([$obj->Get('common')], [1002], 'Set(common) good');
is_deeply([$cs[0]->Get('common')], [1002], 'A Set(common) good');
is_deeply([$cs[1]->Get('common')], [1002], 'B Set(common) good');
is_deeply([$obj->Get('a')], [1000], 'Set(common) good a');
is_deeply([$obj->Get('b')], [1001], 'Set(common) good b');

# Set bad
dies_ok { $obj->Set('a' => 'alma') } 'set bad';
is_deeply([$obj->Get('a')], [1000], 'Set bad composite');
is_deeply([$cs[0]->Get('a')], [1000], 'Set bad component');

# Set half bad
dies_ok { $obj->Set('common' => undef) } 'set halfbad';
is_deeply([$obj->Get('common')], [1002], 'Set halfbad composite');
is_deeply([$cs[0]->Get('common')], [1002], 'Set halfbad A');
is_deeply([$cs[1]->Get('common')], [1002], 'Set halfbad B');

# Dirty
is_deeply([ sort $obj->GetDirty() ], [qw( a b common )], 'dirty');
is_deeply([ sort $cs[0]->GetDirty() ], [qw( a common )], 'dirty A');
is_deeply([ sort $cs[1]->GetDirty() ], [qw( b common )], 'dirty B');

$obj->ClearDirty();
is_deeply([$obj->GetDirty()], [], 'ClearDirty');
is_deeply([$cs[0]->GetDirty()], [], 'ClearDirty A');
is_deeply([$cs[1]->GetDirty()], [], 'ClearDirty B');

# Clone
my $obj_ = $obj->Clone();
my @cs_ = $obj_->GetComponents();
is(scalar(@cs_), 2, 'Clone parts length');
isa_ok($cs_[0], 'TestClassA', 'Clone Components/A isa');
isa_ok($cs_[1], 'TestClassB', 'Clone Components/B isa');
isnt($cs_[0], $cs[0], 'Clone Components/A isnt');
isnt($cs_[1], $cs[1], 'Clone Components/B isnt');
is_deeply([$obj->Get('a')], [1000], 'Clone a');
is_deeply([$obj->Get('b')], [1001], 'Clone b');
is_deeply([$obj->Get('common')], [1002], 'Clone common');

# assemble bad
dies_ok { TestClassC->assemble('a') } 'assemble bad 1';
dies_ok { TestClassC->assemble($cs[0]) } 'assemble bad 2';
dies_ok { TestClassC->assemble($cs[1]) } 'assemble bad 3';
dies_ok { TestClassC->assemble($cs[0], bless({}, 'X')) } 'assemble bad 4';
dies_ok { TestClassC->assemble(bless({}, 'X'), $cs[1]) } 'assemble bad 5';

# assemble good
$obj = TestClassC->assemble(
    TestClassA->new({ 'a' => 10, 'p_a' => 11, 'common' => 30 }),
    TestClassB->new({ 'b' => 20, 'p_b' => 21, 'common' => 30 }));
is_deeply([$obj->Get('a')], [10], 'assemble a');
is_deeply([$obj->Get('b')], [20], 'assemble b');
is_deeply([$obj->Get('p_a')], [11], 'assemble p_a');
is_deeply([$obj->Get('p_b')], [21], 'assemble p_b');
is_deeply([$obj->Get('common')], [30], 'assemble common');

# json
my $json_got = $obj->SerializeToJson();
my $json_good =
    {
      'a' => 10,
      'b' => 20,
      'common' => 30
    };
is_deeply($json_got, $json_good, 'json');

done_testing();
