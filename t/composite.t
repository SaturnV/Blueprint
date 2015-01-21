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
      'ab' => { ':type' => 'uint' },
      'ac' => { ':type' => 'uint' },
      'abc' => { ':type' => 'opt_uint' },
      'p_a' => { ':type' => 'uint', 'json' => 0 });
}

{
  package TestClassB;
  use Essence::Strict;
  use parent 'Blueprint';

  __PACKAGE__->blueprint(
      ':defaults' => { 'json' => 1 },
      'b' => { ':type' => 'uint' },
      'ab' => { ':type' => 'uint' },
      'bc' => { ':type' => 'uint' },
      'abc' => { ':type' => 'uint' },
      'p_b' => { ':type' => 'uint', 'json' => 0 });
}

{
  package TestClassC;
  use Essence::Strict;
  use parent 'Blueprint';

  __PACKAGE__->blueprint(
      ':traits' =>
          {
            'json' => {},
            'components' => [qw( TestClassA TestClassB )]
          },
      'c' => { ':type' => 'uint', 'json' => 1 },
      'ac' => { ':type' => 'uint' },
      'bc' => { ':type' => 'uint' },
      'abc' => { ':type' => 'opt_uint' },
      'p_c' => { ':type' => 'uint' });
}

{
  package TestClassD;
  use Essence::Strict;

  our @ISA = qw( TestClassC );

  __PACKAGE__->blueprint(
      'd' => { ':type' => 'uint', 'json' => 1 });
}

###### SUBS ###################################################################

sub do_cmp
{
  my ($obj, $cmp, $desc) = @_;

  foreach my $attr (sort keys(%{$cmp}))
  {
    is_deeply([$obj->Get($attr)], [$cmp->{$attr}], "$desc($attr)");
  }
}

###### CODE ###################################################################

is_deeply(
    [TestClassC->get_components()],
    [qw( TestClassA TestClassB )],
    'Components');

my $mc = TestClassC->get_metaclass();
is_deeply(
    [sort keys(%{$mc->GetConfig('components.own_attributes')})],
    [sort qw( c ac bc abc p_c )],
    'Own attributes');

# new
my $cmp =
    {
      'a' => 1,
      'b' => 2,
      'c' => 3,
      'ab' => 4,
      'ac' => 5,
      'bc' => 6,
      'abc' => 7,
      'p_a' => 8,
      'p_b' => 9,
      'p_c' => 10
    };
my $obj = TestClassC->new({ %{$cmp} });
isa_ok($obj, 'TestClassC', 'new');
$obj->ClearDirty();

# Essence::Logger->LogDebug('DEBUG object', $obj);

# Get
do_cmp($obj, $cmp, 'Get');

# Get vs components
my @cs = $obj->GetComponents();
is(scalar(@cs), 2, 'parts length');
isa_ok($cs[0], 'TestClassA', 'Components A');
isa_ok($cs[1], 'TestClassB', 'Components B');

my $cmp_a = {};
$cmp_a->{$_} = $cmp->{$_} foreach (grep { /a/ } keys(%{$cmp}));
do_cmp($cs[0], $cmp_a, 'A');

my $cmp_b = {};
$cmp_b->{$_} = $cmp->{$_} foreach (grep { /b/ } keys(%{$cmp}));
do_cmp($cs[1], $cmp_b, 'B');

# Set good
my $set =
    {
      'a' => 1001,
      'b' => 1002,
      'c' => 1003,
      'ab' => 1004,
      'ac' => 1005,
      'bc' => 1006,
      'abc' => 1007,
    };
foreach my $attr (sort keys(%{$set}))
{
  $obj->Set($attr => $set->{$attr});
  $cmp->{$attr} = $set->{$attr};
  $cmp_a->{$attr} = $set->{$attr} if ($attr =~ /a/);
  $cmp_b->{$attr} = $set->{$attr} if ($attr =~ /b/);
  do_cmp($obj, $cmp, "Set $attr good ");
  do_cmp($cs[0], $cmp_a, "Set $attr good A ");
  do_cmp($cs[1], $cmp_b, "Set $attr good B ");
}

# Set bad
dies_ok { $obj->Set('a' => 'alma') } 'Set bad';
is_deeply([$obj->Get('a')], [$cmp->{'a'}], 'Set bad composite');
is_deeply([$cs[0]->Get('a')], [$cmp_a->{'a'}], 'Set bad component');

# Set half bad
dies_ok { $obj->Set('abc' => undef) } 'Set halfbad';
is_deeply([$obj->Get('abc')], [$cmp->{'abc'}], 'Set halfbad composite');
is_deeply([$cs[0]->Get('abc')], [$cmp_a->{'abc'}], 'Set halfbad A');
is_deeply([$cs[1]->Get('abc')], [$cmp_b->{'abc'}], 'Set halfbad B');

# Dirty
is_deeply([ sort $obj->GetDirty() ],
          [ sort keys(%{$set}) ],
          'Dirty');
is_deeply([ sort $cs[0]->GetDirty() ],
          [ sort grep { /a/ } keys(%{$set}) ],
          'Dirty A');
is_deeply([ sort $cs[1]->GetDirty() ],
          [ sort grep { /b/ } keys(%{$set}) ],
          'Dirty B');

$obj->ClearDirty();
is_deeply([$obj->GetDirty()], [], 'ClearDirty');
is_deeply([$cs[0]->GetDirty()], [], 'ClearDirty A');
is_deeply([$cs[1]->GetDirty()], [], 'ClearDirty B');

# Clone
my $obj_ = $obj->Clone();
my @cs_ = $obj_->GetComponents();
is(scalar(@cs_), 2, 'Clone parts length');
isa_ok($cs_[0], 'TestClassA', 'Clone Components A isa');
isa_ok($cs_[1], 'TestClassB', 'Clone Components B isa');
isnt($cs_[0], $cs[0], 'Clone Components A isnt');
isnt($cs_[1], $cs[1], 'Clone Components B isnt');
do_cmp($obj_, $cmp, 'Clone ');
do_cmp($cs_[0], $cmp_a, 'Clone A ');
do_cmp($cs_[1], $cmp_b, 'Clone B ');

# assemble bad
my $init = {};
$init->{$_} = $cmp->{$_} foreach (grep { /c/ } keys(%{$cmp}));
dies_ok { TestClassC->assemble($init, 'a') } 'Assemble bad 1';
dies_ok { TestClassC->assemble($init, $cs[0]) } 'Assemble bad 2';
dies_ok { TestClassC->assemble($init, $cs[1]) } 'Assemble bad 3';
dies_ok { TestClassC->assemble($init, $cs[0], bless({}, 'X')) }
    'Assemble bad 4';
dies_ok { TestClassC->assemble($init, bless({}, 'X'), $cs[1]) }
    'Assemble bad 5';
dies_ok { TestClassC->assemble(@cs) } 'Assemble bad 6';

# assemble good
$obj = TestClassC->assemble($init, @cs);
do_cmp($obj, $cmp, 'Assemble ');

# json
my $json_good = {};
$json_good->{$_} = $cmp->{$_} foreach (grep { !/p/ } keys(%{$cmp}));

my $json_got = $obj->SerializeToJson();
is_deeply($json_got, $json_good, 'Json');

# d
is_deeply(
    [TestClassD->get_components()],
    [qw( TestClassA TestClassB )],
    'D Components');

$mc = TestClassD->get_metaclass();
is_deeply(
    [sort keys(%{$mc->GetConfig('components.own_attributes')})],
    [sort qw( c ac bc abc p_c d )],
    'D Own attributes');

$cmp->{'d'} = 77;
$obj = TestClassD->new({ %{$cmp} });
isa_ok($obj, 'TestClassD', 'D new');

@cs = $obj->GetComponents();
is(scalar(@cs), 2, 'D parts length');
isa_ok($cs[0], 'TestClassA', 'D Components A');
isa_ok($cs[1], 'TestClassB', 'D Components B');
do_cmp($cs[0], $cmp_a, 'D A');
do_cmp($cs[1], $cmp_b, 'D B');

$set =
    {
      'a' => 2001,
      'b' => 2002,
      'c' => 2003,
      'ab' => 2004,
      'ac' => 2005,
      'bc' => 2006,
      'abc' => 2007,
      'd' => 2008
    };
foreach my $attr (sort keys(%{$set}))
{
  $obj->Set($attr => $set->{$attr});
  $cmp->{$attr} = $set->{$attr};
  $cmp_a->{$attr} = $set->{$attr} if ($attr =~ /a/);
  $cmp_b->{$attr} = $set->{$attr} if ($attr =~ /b/);
  do_cmp($obj, $cmp, "D Set $attr good ");
  do_cmp($cs[0], $cmp_a, "D Set $attr good A ");
  do_cmp($cs[1], $cmp_b, "D Set $attr good B ");
}

dies_ok { $obj->Set('a' => 'alma') } 'D Set bad';
is_deeply([$obj->Get('a')], [$cmp->{'a'}], 'D Set bad composite');
is_deeply([$cs[0]->Get('a')], [$cmp_a->{'a'}], 'D Set bad component');

dies_ok { $obj->Set('abc' => undef) } 'D Set halfbad';
is_deeply([$obj->Get('abc')], [$cmp->{'abc'}], 'D Set halfbad composite');
is_deeply([$cs[0]->Get('abc')], [$cmp_a->{'abc'}], 'D Set halfbad A');
is_deeply([$cs[1]->Get('abc')], [$cmp_b->{'abc'}], 'D Set halfbad B');

$json_good = {};
$json_good->{$_} = $cmp->{$_} foreach (grep { !/p/ } keys(%{$cmp}));
$json_got = $obj->SerializeToJson();
is_deeply($json_got, $json_good, 'D Json');

done_testing();
