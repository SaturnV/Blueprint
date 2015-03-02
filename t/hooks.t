#! /usr/bin/perl

use Test::More;
use Essence::Strict;

###### VARS ###################################################################

our @hooks;

###### CLASSES ################################################################

# ==== A ======================================================================

{
  package TestClass::A;
  use Essence::Strict;
  use parent 'Blueprint';

  my $mc = __PACKAGE__->blueprint('a' => {}, 'x' => {});
  my $ma = $mc->GetAttribute('a');
  my $mx = $mc->GetAttribute('x');

  $mc->_AddHook('Get',
      'A1' =>
          sub
          {
            my $next = shift;
            push(@main::hooks, 'A.A1');
            return $next->(@_);
          });
  $mc->_AddHook('Get',
      'A2' =>
          sub
          {
            my $next = shift;
            push(@main::hooks, 'A.A2');
            return $next->(@_);
          });

  $ma->_AddHook('Get',
      'a1' =>
          sub
          {
            my $next = shift;
            push(@main::hooks, 'A.a.a1');
            return $next->(@_);
          });
  $ma->_AddHook('Get',
      'a2' =>
          sub
          {
            my $next = shift;
            push(@main::hooks, 'A.a.a2');
            return $next->(@_);
          });

  $mx->_AddHook('Get',
      'ax1' =>
          sub
          {
            my $next = shift;
            push(@main::hooks, 'A.x.ax1');
            return $next->(@_);
          });
  $mx->_AddHook('Get',
      'ax2' =>
          sub
          {
            my $next = shift;
            push(@main::hooks, 'A.x.ax2');
            return $next->(@_);
          });
}

# ==== B ======================================================================

{
  package TestClass::B;
  use Essence::Strict;
  use parent 'Blueprint';

  my $mc = __PACKAGE__->blueprint('b' => {}, 'x' => {});
  my $mb = $mc->GetAttribute('b');
  my $mx = $mc->GetAttribute('x');

  $mc->_AddHook('Get',
      'B1' =>
          sub
          {
            my $next = shift;
            push(@main::hooks, 'B.B1');
            return $next->(@_);
          });
  $mc->_AddHook('Get',
      'B2' =>
          sub
          {
            my $next = shift;
            push(@main::hooks, 'B.B2');
            return $next->(@_);
          });

  $mb->_AddHook('Get',
      'b1' =>
          sub
          {
            my $next = shift;
            push(@main::hooks, 'B.b.b1');
            return $next->(@_);
          });
  $mb->_AddHook('Get',
      'b2' =>
          sub
          {
            my $next = shift;
            push(@main::hooks, 'B.b.b2');
            return $next->(@_);
          });

  $mx->_AddHook('Get',
      'bx1' =>
          sub
          {
            my $next = shift;
            push(@main::hooks, 'B.x.bx1');
            return $next->(@_);
          });
  $mx->_AddHook('Get',
      'bx2' =>
          sub
          {
            my $next = shift;
            push(@main::hooks, 'B.x.bx2');
            return $next->(@_);
          });
}

# ==== D ======================================================================

{
  package TestClass::D;
  use Essence::Strict;

  our @ISA = qw( TestClass::A TestClass::B );

  my $mc = __PACKAGE__->blueprint('d' => {}, 'x' => {});
  my $ma = $mc->GetAttribute('a');
  my $mb = $mc->GetAttribute('b');
  my $md = $mc->GetAttribute('d');
  my $mx = $mc->GetAttribute('x');

  $mc->_AddHook('Get',
      'D1' =>
          sub
          {
            my $next = shift;
            push(@main::hooks, 'D.D1');
            return $next->(@_);
          });
  $mc->_AddHook('Get',
      'D2' =>
          sub
          {
            my $next = shift;
            push(@main::hooks, 'D.D2');
            return $next->(@_);
          });
  $mc->_AddHook('Get',
      'A1' =>
          sub
          {
            my $next = shift;
            push(@main::hooks, 'D.A1');
            return $next->(@_);
          });
  $mc->_AddHook('Get',
      'B2' =>
          sub
          {
            my $next = shift;
            push(@main::hooks, 'D.B2');
            return $next->(@_);
          });

  $ma->_AddHook('Get',
      'da1' =>
          sub
          {
            my $next = shift;
            push(@main::hooks, 'D.a.da1');
            return $next->(@_);
          });
  $ma->_AddHook('Get',
      'da2' =>
          sub
          {
            my $next = shift;
            push(@main::hooks, 'D.a.da2');
            return $next->(@_);
          });
  $ma->_AddHook('Get',
      'a1' =>
          sub
          {
            my $next = shift;
            push(@main::hooks, 'D.a.a1');
            return $next->(@_);
          });

  $mb->_AddHook('Get',
      'db1' =>
          sub
          {
            my $next = shift;
            push(@main::hooks, 'D.b.db1');
            return $next->(@_);
          });
  $mb->_AddHook('Get',
      'db2' =>
          sub
          {
            my $next = shift;
            push(@main::hooks, 'D.b.db2');
            return $next->(@_);
          });
  $mb->_AddHook('Get',
      'b2' =>
          sub
          {
            my $next = shift;
            push(@main::hooks, 'D.b.b2');
            return $next->(@_);
          });

  $mx->_AddHook('Get',
      'dx1' =>
          sub
          {
            my $next = shift;
            push(@main::hooks, 'D.x.dx1');
            return $next->(@_);
          });
  $mx->_AddHook('Get',
      'dx2' =>
          sub
          {
            my $next = shift;
            push(@main::hooks, 'D.x.dx2');
            return $next->(@_);
          });
  $mx->_AddHook('Get',
      'ax1' =>
          sub
          {
            my $next = shift;
            push(@main::hooks, 'D.x.ax1');
            return $next->(@_);
          });
  $mx->_AddHook('Get',
      'bx2' =>
          sub
          {
            my $next = shift;
            push(@main::hooks, 'D.x.bx2');
            return $next->(@_);
          });
}

###### CODE ###################################################################

my $obj = TestClass::A->new({ 'a' => 1, 'x' => 2 });

@hooks = ();
$obj->Get('a');
is_deeply([@hooks], [qw( A.A2 A.A1 A.a.a2 A.a.a1 )], 'A.Get(a)');

@hooks = ();
$obj->Get('x');
is_deeply([@hooks], [qw( A.A2 A.A1 A.x.ax2 A.x.ax1 )], 'A.Get(x)');

$obj = TestClass::D->new({ 'a' => 1, 'b' => 2, 'x' => 3 });

@hooks = ();
$obj->Get('a');
is_deeply(
    [@hooks],
    [qw( D.D2 D.D1
         A.A2 D.A1
         D.B2 B.B1
         D.a.da2 D.a.da1
         A.a.a2 D.a.a1 )],
    'D.Get(a)');

@hooks = ();
$obj->Get('b');
is_deeply(
    [@hooks],
    [qw( D.D2 D.D1
         A.A2 D.A1
         D.B2 B.B1
         D.b.db2 D.b.db1
         D.b.b2 B.b.b1 )],
    'D.Get(b)');

@hooks = ();
$obj->Get('x');
is_deeply(
    [@hooks],
    [qw( D.D2 D.D1
         A.A2 D.A1
         D.B2 B.B1
         D.x.dx2 D.x.dx1
         A.x.ax2 D.x.ax1
         D.x.bx2 B.x.bx1 )],
    'D.Get(x)');

done_testing();
