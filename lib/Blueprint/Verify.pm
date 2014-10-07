#! /usr/bin/perl
# TODO Better 'what' override scheme
###### NAMESPACE ##############################################################

package Blueprint::Verify;

###### IMPORTS ################################################################

use Essence::Strict;

use Scalar::Util qw( looks_like_number blessed );
use List::MoreUtils qw( any all );
use List::Util qw( min max );
use Carp;

###### EXPORTS ################################################################

use Exporter qw( import );

our @EXPORT = qw(
    v_anything
    v_any v_all v_optional_ v_opt_ v_optional v_opt
    v_exists v_not_exists v_defined v_def v_not_defined v_not_def v_undef
    v_ref v_isa v_scalar
    v_length v_num_minmax v_str_minmax
    v_string v_str v_str_len v_str_all
    v_number v_num v_num_min_max
    v_integer v_int v_int_min_max
    v_uinteger v_uint v_uint_min_max
    v_array v_ae v_ae_repeat_last v_ae_repeat_all
    v_hash
    v_bool_ v_bool v_guid v_email v_date
    v_time v_time_ms v_time_us v_datetime v_datetime_ms v_datetime_us
    verify verify_not_exists );
our @EXPORT_OK = qw(
    %ErrMsgVars
    $ReBool $ReInteger $ReUInteger $ReGuid
    $ReDate_ $ReTime_ $ReTimeMs_ $ReTimeUs_
    $ReDate $ReTime $ReTimeMs $ReTimeUs
    $ReDateTime $ReDateTimeMs $ReDateTimeUs
    $ReEmailBox_ $ReEmailDomain_ $ReEmail
    $ReLength $RePrintable
    ok err loc err2str _v _k
    err2str_default_msg err2str_var err2str_var_at err2str_var_but
    err2str_var_got err2str_var_loc err2str_var_what err2str_var_a_what
    cx_length cx_num_minmax cx_str_minmax cx_num_enum cx_str_enum
    cx_num_match cx_str_match cx_ae cx_he
    c_anything
    c_exists c_not_exists
    c_defined c_not_defined
    c_ref c_scalar c_number );

###### VARS ###################################################################

my $mod_name = __PACKAGE__;

my $idx_got = 0;
my $idx_exists = 1;
my $idx_what = 2;
my $idx_params = 3;

our %ErrMsgVars =
    (
      'a_what' => \&err2str_var_a_what,
      'at' => \&err2str_var_at,
      'but' => \&err2str_var_but,
      'got' => \&err2str_var_got,
      'loc' => \&err2str_var_loc,
      'what' => \&err2str_var_what
    );

our $ReBool = qr/^[01]?\z/;
our $ReInteger = qr/^-?\d{1,20}\z/;
our $ReUInteger = qr/^\d{1,20}\z/;
our $ReGuid = qr/^[0-9a-f]{32}\z/;

# TODO Reject 0198-99-99 99:99:99
our $ReDate_ = qr/\d{4}-\d{2}-\d{2}/;
our $ReTime_ = qr/\d{2}:\d{2}:\d{2}/;
our $ReTimeMs_ = qr/$ReTime_\.\d{3}/;
our $ReTimeUs_ = qr/$ReTime_\.\d{6}/;

our $ReDate = qr/^$ReDate_\z/;
our $ReTime = qr/^$ReTime_\z/;
our $ReTimeMs = qr/^$ReTimeMs_\z/;
our $ReTimeUs = qr/^$ReTimeUs_\z/;
our $ReDateTime = qr/^$ReDate_ $ReTime_\z/;
our $ReDateTimeMs = qr/^$ReDate_ $ReTimeMs_\z/;
our $ReDateTimeUs = qr/^$ReDate_ $ReTimeUs_\z/;

# Will do for now
our $ReEmailBox_ = qr/[0-9a-z_.-]{1,63}(?:\+[0-9a-z_.-]{1,63})?/i;
our $ReEmailDomain_ = qr/(?:[0-9a-z-]{1,32}\.){1,4}[a-z]{2,5}/i;
our $ReEmail = qr/^$ReEmailBox_\@$ReEmailDomain_\z/i;

our $ReLength = qr/^\d{1,10}\z/;
our $RePrintable = qr"^[ 0-9A-Za-z!@#\$%^&*()_+=\[\]{};:|,./<>?-]{0,60}\z";

###### SUBS ###################################################################

sub ok
{
  return () if wantarray;
  return undef;
}

# ==== Errors =================================================================

sub err
{
  my ($def_msg, $def_what, $got, $exists, $what, $params) = @_;
  my $error = { 'loc' => '' };

  $what //= $def_what;

  $error->{'msg'} = $def_msg if defined($def_msg);
  $error->{'what'} = $what if defined($what);
  $error->{'got'} = $got if $exists;

  return $error;
}

sub loc
{
  my ($braces, $idx) = (shift, shift);

  my $loc;
  given ($braces)
  {
    when ('[]') { $loc = "->[$idx]" }
    when ('{}')
    {
      $loc = ref($idx) ?
          "->{$idx}" :
          (($idx =~ $RePrintable) ? "->{'$idx'}" : '->{...}');
    }
    default { die }
  }

  $_->{'loc'} = $loc . $_->{'loc'}
    foreach (@_);

  return @_ if wantarray;
  return $_[0];
}

# ---- err -> str -------------------------------------------------------------

sub err2str_var_loc { return 'top' . $_[0]->{'loc'} }
sub err2str_var_at { return 'at ' . err2str_var_loc(@_) }
sub err2str_var_what { return $_[0]->{'what'} // 'something' }

sub err2str_var_got
{
  # my $err = $_[0];
  my $got = $_[0]->{'got'};

  if (defined($got))
  {
    if (ref($got))
    {
      return ref($got);
    }
    elsif ($got =~ $RePrintable)
    {
      return "'$got'";
    }
    else
    {
      return 'unprintable string';
    }
  }
  else
  {
    return 'undef';
  }
}

sub err2str_var_a_what
{
  # my $err = $_[0];
  my $what = $_[0]->{'what'};
  return 'something' unless defined($what);
  return "a(n) $what" unless ($what =~ /^[a-z]/i);
  return ($what =~ /^[aeiou]/i) ? "an $what" : "a $what";
}

sub err2str_var_but
{
  my $at = err2str_var_at(@_);
  my $got = err2str_var_got(@_);
  return "but got $got $at";
}

sub err2str_var
{
  my ($var, $err) = @_;
  if ($ErrMsgVars{$var})
  {
    return $ErrMsgVars{$var}->($err);
  }
  else
  {
    warn "$mod_name: Unknown errmsg variable '\$$var'.\n";
    return '';
  }
}

sub err2str_default_msg
{
  # my $err = $_[0];
  return defined($_[0]->{'what'}) ?
      (exists($_[0]->{'got'}) ?
           'expected $what $but.' :
           '$a_what is missing $at.') :
      (exists($_[0]->{'got'}) ?
           'something is wrong $at.' :
           'something is missing $at.');
}

sub err2str
{
  my $err = $_[0];
  my $msg = $err->{'msg'} // err2str_default_msg($err);
  $msg =~ s/\$(\w+)/err2str_var($1, $err)/eg;
  $msg .= "\n" unless (substr($msg, -1, 1) eq "\n");
  return ucfirst($msg);
}

# ==== v_xxx ==================================================================

# sub c_xxx
# {
#   my ($got, $exists, $what, $params) = @_;
#   return (...) ? ok() : err()
# }

# TODO match numbers as numbers
sub _k
{
  my $v = $_[0];
  my $v_ref = ref($v);
  return 'undef' unless defined($v);
  return 'code' if ($v_ref eq 'CODE');
  return 'array' if ($v_ref eq 'ARRAY');
  return 'hash' if ($v_ref eq 'HASH');
  return 'str' if ($v_ref ~~ ['', 'Regexp']);
  return '';
}

sub _v
{
  state $seq = 0;
  my $v = $_[0];
  my $v_ref = ref($v);

  return v_undef() unless defined($v);
  return $v if ($v_ref eq 'CODE');
  return v_ae(@{$v}) if ($v_ref eq 'ARRAY');
  return v_hash(%{$v}) if ($v_ref eq 'HASH');
  return v_str($v) if ($v_ref ~~ ['', 'Regexp']);

  my $id = $seq++ . ":$v_ref";
  carp "$mod_name: Bad spec '$id' (will be better localized once executed)";
  return sub { err("Bad spec ($id) \$at", undef, @_) };
}

sub x_what
{
  my ($what, $sub, @args) = @_;
  # $args[$idx_what] = $what; v_guid reports string
  $args[$idx_what] //= $what;
  return $sub->(@args);
}

# ---- Anything ---------------------------------------------------------------

sub c_anything { return ok() }
sub v_anything { return \&c_anything }

# ---- Any --------------------------------------------------------------------

sub v_any
{
  my $first = _v(shift);

  return $first unless @_;

  my $rest = v_any(@_);
  return sub { return $first->(@_) && $rest->(@_) };
}

# ---- All --------------------------------------------------------------------

sub v_all
{
  my $first = _v(shift);

  return $first unless @_;

  my $rest = v_all(@_);
  return sub { return $first->(@_) || $rest->(@_) };
}

# ---- Exists -----------------------------------------------------------------

sub c_exists { return $_[$idx_exists] ? ok() : err(undef, undef, @_) }
sub v_exists { return \&c_exists }

sub c_not_exists
{
  return $_[$idx_exists] ?
      err('$loc should not exist.', undef, @_) :
      ok();
}
sub v_not_exists { return \&c_not_exists }

# ---- Defined ----------------------------------------------------------------

sub c_defined { return defined($_[$idx_got]) ? ok() : err(undef, undef, @_) }
sub v_defined { return \&c_defined }
sub v_def { return \&c_defined }

sub c_not_defined
{
  return defined($_[$idx_got]) ?
      err('$loc should be undef.', undef, @_) :
      ok();
}
sub v_not_defined { return \&c_not_defined }
sub v_not_def { return \&c_not_defined }
sub v_undef { return \&c_not_defined }

# ---- Optional ---------------------------------------------------------------

# !exists || any(@_)
sub v_optional_
{
  croak "$mod_name: v_optional_: An optional what?" unless @_;
  return v_any(v_not_exists(), @_);
}
sub v_opt_ { return v_optional_(@_) }

# !exists || !defined || any(@_)
sub v_optional
{
  croak "$mod_name: v_optional: An optional what?" unless @_;
  return v_any(v_undef(), @_);
}
sub v_opt { return v_optional(@_) }

# ---- Ref --------------------------------------------------------------------

sub c_ref { return ref($_[$idx_got]) ? ok() : err(undef, 'reference', @_) }
sub _v_ref
{
  my $match = [@_];
  my $expected = $#_ ? 'matched reference' : $_[$idx_got];
  return
      sub
      {
        return (ref($_[$idx_got]) ~~ $match) ?
            ok() :
            err(undef, $expected, @_);
      };
}
sub v_ref { return @_ ? _v_ref(@_) : \&c_ref }

sub v_isa
{
  my @isa = @_;
  my $expected = $#isa ? 'object of listed classes' : $isa[0];
  return
      sub
      {
        return (blessed($_[$idx_got]) ?
                    (any { $_[$idx_got]->isa($_) } @isa) :
                    (any { ref($_[$idx_got]) eq $_ } @isa)) ?
            ok() :
            err(undef, $expected, @_);
      }
}

sub c_scalar
{
  return ref($_[$idx_got]) ?
      err(undef, 'scalar', @_) :
      ok();
}
sub v_scalar { return v_not_ref() }

# ---- Length -----------------------------------------------------------------

sub cx_length
{
  my ($min, $max) = (shift, shift);
  my $ref = ref($_[$idx_got]);

  my ($length, $what);
  if (!$ref)
  {
    $length = length($_[$idx_got]) if defined($_[$idx_got]);
    $what = 'string';
  }
  elsif (($ref eq 'ARRAY') ||
         (blessed($_[$idx_got]) && $_[$idx_got]->isa('ARRAY')))
  {
    $length = scalar(@{$_[$idx_got]});
    $what = 'array';
  }
  elsif (($ref eq 'HASH') ||
         (blessed($_[$idx_got]) && $_[$idx_got]->isa('HASH')))
  {
    $length = scalar(keys(%{$_[$idx_got]}));
    $what = 'hash';
  }
  else
  {
    warn "$mod_name: Can't measure the length of a(n) $ref.\n";
  }

  if (defined($length))
  {
    return err("\$what length < $min \$at.", $what, @_)
      if (defined($min) && ($length < $min));
    return err("\$what length > $max \$at.", $what, @_)
      if (defined($max) && ($length > $max));
  }

  return ok();
}

sub v_length
{
  my ($min, $max) = (shift, shift);

  croak "$mod_name: v_length(min, max)"
    if @_;
  croak "$mod_name: v_length: Bad min spec"
    if (defined($min) && ($min !~ $ReLength));
  croak "$mod_name: v_length: Bad max spec"
    if (defined($max) && ($max !~ $ReLength));
  croak "$mod_name: v_length: min > max"
    if (defined($min) && defined($max) && ($min > $max));
  carp "$mod_name: v_length: Neither min nor max given"
    unless (defined($min) || defined($max));

  return sub { return cx_length($min, $max, @_) };
}

# ---- num_minmax -------------------------------------------------------------

sub cx_num_minmax
{
  my ($min, $max) = (shift, shift);
  return err("Expected \$a_what < $min \$but.", 'number', @_)
    if (defined($min) && ($_[$idx_got] < $min));
  return err("Expected \$a_what > $max \$but.", 'number', @_)
    if (defined($max) && ($_[$idx_got] > $max));
  return ok();
}

sub v_num_minmax
{
  my ($min, $max) = (shift, shift);

  croak "$mod_name: v_num_minmax(min, max)"
    if @_;
  croak "$mod_name: v_num_minmax: Bad min spec"
    if (defined($min) && !looks_like_number($min));
  croak "$mod_name: v_num_minmax: Bad max spec"
    if (defined($max) && !looks_like_number($max));
  croak "$mod_name: v_num_minmax: min > max"
    if (defined($min) && defined($max) && ($min > $max));
  carp "$mod_name: v_num_minmax: Neither min nor max given"
    unless (defined($min) || defined($max));

  return sub { return cx_num_minmax($min, $max, @_) };
}

# ---- str_minmax -------------------------------------------------------------

sub cx_str_minmax
{
  my ($min, $max) = (shift, shift);
  return err("Expected \$a_what lt $min \$but.", 'string', @_)
    if (defined($min) && ($_[$idx_got] lt $min));
  return err("Expected \$a_what gt $max \$but.", 'string', @_)
    if (defined($max) && ($_[$idx_got] gt $max));
  return ok();
}

sub v_str_minmax
{
  my ($min, $max) = (shift, shift);

  croak "$mod_name: v_str_minmax(min, max)"
    if @_;
  croak "$mod_name: v_str_minmax: Bad min spec"
    if (defined($min) && ref($min));
  croak "$mod_name: v_str_minmax: Bad max spec"
    if (defined($max) && ref($max));
  croak "$mod_name: v_str_minmax: min > max"
    if (defined($min) && defined($max) && ($min gt $max));
  carp "$mod_name: v_str_minmax: Neither min nor max given"
    unless (defined($min) || defined($max));

  return sub { return cx_str_minmax($min, $max, @_) };
}

# ---- enum -------------------------------------------------------------------

sub cx_num_enum
{
  my $nums = shift;
  return (any { $_[$idx_got] == $_ } @{$nums}) ?
      ok() :
      err('$what not in good set.', 'number', @_);
}

sub cx_str_enum
{
  my $nums = shift;
  return (any { $_[$idx_got] eq $_ } @{$nums}) ?
      ok() :
      err('$what not in good set.', 'string', @_);
}

# ---- match ------------------------------------------------------------------

sub cx_num_match
{
  my $match = shift;

  foreach (@{$match})
  {
    if (ref($_) eq 'CODE') { return ok() unless ($_->(@_)) }
    elsif (ref($_) eq 'Regexp') { return ok() if ($_[$idx_got] =~ $_) }
    elsif ($_[$idx_got] == $_) { return ok() }
  }

  return err('$what match failed $at.', 'number', @_);
}

sub cx_str_match
{
  my $match = shift;

  my $err;
  foreach (@{$match})
  {
    if (ref($_) eq 'CODE') { return ok() unless ($err = $_->(@_)) }
    elsif (ref($_) eq 'Regexp') { return ok() if ($_[$idx_got] =~ $_) }
    elsif ($_[$idx_got] eq $_) { return ok() }
  }

  return $err if ($err && !$#{$match});

  my $msg;
  $msg = '$what match failed $at.'
    if (($_[$idx_what] // 'string') eq 'string');

  return err($msg, 'string', @_);
}

# ---- String -----------------------------------------------------------------

sub k_str_spec
{
  return (all { defined($_) && (ref($_) ~~ ['', 'CODE', 'Regexp']) } @_);
}

sub v_string
{
  my @all = (\&c_defined, \&c_scalar);

  if (@_)
  {
    croak "$mod_name: v_string: Bad string spec"
      unless k_str_spec(@_);

    my $match = [@_];
    push(@all, sub { return cx_str_match($match, @_) });
  }

  return sub { return x_what('string', v_all(@all), @_) };
}
sub v_str { return v_string(@_) }

sub v_str_len
{
  my ($min, $max) = (shift, shift);

  my @rest;
  if (@_)
  {
    croak "$mod_name: v_string: Bad string spec"
      unless k_str_spec(@_);

    my $match = [@_];
    @rest = ( sub { return cx_str_match($match, @_) } );
  }

  return v_string(v_length($min, $max), @rest);
}

sub v_str_all { return v_string(v_all(@_)) }

# ---- Number -----------------------------------------------------------------

sub k_num_spec
{
  return
      (all { defined($_) && ((ref($_) eq 'CODE') || looks_like_number($_)) }
           @_);
}

sub c_number
{
  return looks_like_number($_[$idx_got]) ? ok() : err(undef, 'number', @_);
}
sub v_number
{
  my @all = (\&c_defined, \&c_scalar, \&c_number);

  if (@_)
  {
    croak "$mod_name: v_number: Bad number spec"
      unless k_num_spec(@_);

    my $match = [@_];
    push(@all, sub { return cx_num_match($match, @_) });
  }

  return sub { return x_what('number', v_all(@all), @_) };
}
sub v_num { return v_number(@_) }

sub v_num_min_max
{
  my ($min, $max) = (shift, shift);
  croak "$mod_name: v_num_min_max(min, max)" if @_;
  return v_number(v_num_minmax($min, $max));
}

# ---- Integer ----------------------------------------------------------------

sub v_integer
{
  my @all = (v_string($ReInteger));

  if (@_)
  {
    croak "$mod_name: v_number: Bad number spec"
      unless k_num_spec(@_);

    my $match = [@_];
    push(@all, sub { return cx_num_match($match, @_) });
  }

  return sub { return x_what('integer', v_all(@all), @_) };
}
sub v_int { return v_integer(@_) }

sub v_int_min_max
{
  my ($min, $max) = (shift, shift);
  croak "$mod_name: v_int_min_max(min, max)" if @_;
  return v_integer(v_num_minmax($min, $max));
}

# ---- UInt -------------------------------------------------------------------

sub v_uinteger
{
  my @all = (v_string($ReUInteger));

  if (@_)
  {
    croak "$mod_name: v_number: Bad number spec"
      unless k_num_spec(@_);

    my $match = [@_];
    push(@all, sub { return cx_num_match($match, @_) });
  }

  return sub { return x_what('uinteger', v_all(@all), @_) };
}
sub v_uint { return v_uinteger(@_) }

sub v_uint_min_max
{
  my ($min, $max) = (shift, shift);
  croak "$mod_name: v_uint_min_max(min, max)" if @_;
  return v_uinteger(v_num_minmax($min, $max));
}

# ---- Date, Time -------------------------------------------------------------

sub v_date
{
  return sub { return x_what('date', v_string($ReDate), @_) };
}
sub v_time
{
  return sub { return x_what('time', v_string($ReTime), @_) };
}
sub v_time_ms
{
  return sub { return x_what('time_ms', v_string($ReTimeMs), @_) };
}
sub v_time_us
{
  return sub { return x_what('time_us', v_string($ReTimeUs), @_) };
}
sub v_datetime
{
  return sub { return x_what('datetime', v_string($ReDateTime), @_) };
}
sub v_datetime_ms
{
  return sub { return x_what('datetime_ms', v_string($ReDateTimeMs), @_) };
}
sub v_datetime_us
{
  return sub { return x_what('datetime', v_string($ReDateTimeUs), @_) };
}

# ---- Str/Num based misc stuff -----------------------------------------------

sub v_bool_
{
  return sub { return x_what('bool', v_uint_min_max(0, 1), @_) };
}
sub v_bool
{
  return sub { return x_what('bool', v_opt(v_str($ReBool)), @_) };
}

sub v_guid { return sub { return x_what('guid', v_string($ReGuid), @_) } }
sub v_email { return sub { return x_what('email', v_string($ReEmail), @_) } }

# ---- Array ------------------------------------------------------------------

sub _wrap_max
{
  # my ($mode, $match, $got) = @_;
  given ($_[0])
  {
    when ('none') { return $#{$_[1]} }
    when ('last') { return max($#{$_[1]}, $#{$_[2]}) }
    when ('wrap')
    {
      my $mod = scalar(@{$_[2]}) % scalar(@{$_[1]});
      $mod = scalar(@{$_[1]}) - $mod if $mod;
      return $#{$_[2]} + $mod;
    }
    default { die "Bad match wrap '$_[0]'" }
  }
}

sub _wrap_match
{
  # my ($mode, $match, $idx) = @_;
  given ($_[0])
  {
    when ('none') { return $_[1]->[$_[2]] }
    when ('last') { return $_[1]->[min($_[2], $#{$_[1]})] }
    when ('wrap') { return $_[1]->[$_[2] % scalar(@{$_[1]})] }
    default { die "Bad match wrap '$_[0]'" }
  }
}

sub cx_ae
{
  my ($wrap, $match, @args) = @_;
  my $got = $args[$idx_got];

  if ($wrap eq 'none')
  {
    my $len = @{$got};
    my $max = @{$match};
    return err("\$what is too long ($len, max: $max)", 'array', @args)
      if ($len > $max);
  }

  my $last_idx = _wrap_max($wrap, $match, $got);
  $args[$idx_what] = 'array element';

  if (wantarray)
  {
    my ($m, @err, @err_);
    foreach my $i (0 .. $last_idx)
    {
      $args[$idx_exists] = $#{$got} >= $i;
      $args[$idx_got] = $got->[$i];

      push(@err, loc('[]', $i, @err_))
        if (@err_ = _wrap_match($wrap, $match, $i)->(@args));
    }
    return @err if @err;
  }
  else
  {
    my ($m, $err);
    foreach my $i (0 .. $last_idx)
    {
      $args[$idx_exists] = $#{$got} >= $i;
      $args[$idx_got] = $got->[$i];

      return loc('[]', $i, $err)
        if ($err = _wrap_match($wrap, $match, $i)->(@args));
    }
  }

  return ok();
}

# Checks arrays, not array elements
sub v_array
{
  return @_ ? v_all(v_isa('ARRAY'), @_) : v_isa('ARRAY');
}

sub v_ae
{
  return v_isa('ARRAY') unless @_;

  my $match = [ map { _v($_) } @_ ];
  return v_all(
      v_isa('ARRAY'),
      sub { return cx_ae('none', $match, @_); });
}

sub v_ae_repeat_last
{
  return v_isa('ARRAY') unless @_;

  my $match = [ map { _v($_) } @_ ];
  return v_all(
      v_isa('ARRAY'),
      sub { return cx_ae('last', $match, @_); });
}

sub v_ae_repeat_all
{
  return v_isa('ARRAY') unless @_;

  my $match = [ map { _v($_) } @_ ];
  return v_all(
      v_isa('ARRAY'),
      sub { return cx_ae('wrap', $match, @_); });
}

# ---- Hash -------------------------------------------------------------------

sub _hash_spec
{
  my @ret;

  while (@_)
  {
    my $k = shift;

    if (!defined($k) || (_k($k) eq 'str'))
    {
      # undef will match any key without checking
      croak "$mod_name: v_hash: Bad number of elements"
        unless @_;
      croak "$mod_name: v_hash: Bad value spec"
        unless _k($_[0]);
      push(@ret, $k, shift);
    }
    elsif (ref($k) eq 'ARRAY')
    {
      push(@ret, _hash_spec(@{$k}));
    }
    elsif (ref($k) eq 'HASH')
    {
      push(@ret, _hash_spec(%{$k}));
    }
    elsif (ref($k) eq 'CODE')
    {
      push(@ret, $k)
    }
    else
    {
      croak "$mod_name: v_hash: Bad (key) spec"
    }
  }

  return @ret;
}

sub cx_he
{
  my ($keys, $values, @args) = @_;
  my $got = $args[$idx_got];

  my @matched = (0) x scalar(@{$keys});
  $args[$idx_what] = 'hash element';

  my ($idx, $matched, $err, @err);
  foreach my $got_key (keys(%{$got}))
  {
    for ( $idx = $matched = 0 ; $idx <= $#{$keys} ; $idx++ )
    {
      $matched = defined($keys->[$idx]) ? ($got_key ~~ $keys->[$idx]) : 1;
      last if $matched;
    }

    if ($matched)
    {
      $args[$idx_got] = $got->{$got_key};
      $matched[$idx]++;
    }

    if (wantarray)
    {
      push(@err,
          loc('{}', $got_key,
              $matched ?
                  $values->[$idx]->(@args) :
                  (err('unmatched key $at', undef, @args))));
    }
    else
    {
      $err = $matched ?
          $values->[$idx]->(@args) :
          err('unmatched key $at', undef, @args);
      return loc('{}', $got_key, $err)
        if $err;
    }
  }

  my @unmatched_idxs = grep { !$matched[$_] } (0 .. $#matched);
  $args[$idx_got] = undef;
  $args[$idx_exists] = 0;

  if (wantarray)
  {
    push(@err, loc('{}', $keys->[$_], $values->[$_]->(@args)))
      foreach (@unmatched_idxs);
  }
  else
  {
    @unmatched_idxs =
        sort {
               my $aa = (!ref($a) && ($a =~ $RePrintable)) ? length($a) : 1e9;
               my $bb = (!ref($b) && ($b =~ $RePrintable)) ? length($b) : 1e9;
               $aa <=> $bb
             } @unmatched_idxs;
    foreach (@unmatched_idxs)
    {
      return loc('{}', $keys->[$_], $err)
        if ($err = $values->[$_]->(@args));
    }
  }

  return @err if wantarray;
  return ok();
}

sub v_hash
{
  my @spec = _hash_spec(@_);
  return v_isa('HASH') unless @spec;

  my (@match_whole, @match_keys, @match_values);
  while (@spec)
  {
    if (ref($spec[0]) eq 'CODE')
    {
      push(@match_whole, shift(@spec));
    }
    else
    {
      push(@match_keys, shift(@spec));
      push(@match_values, _v(shift(@spec)));
    }
  }

  push(@match_whole,
      sub { return cx_he(\@match_keys, \@match_values, @_) })
    if @match_keys;

  return v_all(v_isa('HASH'), @match_whole);
}

# ==== verify =================================================================

sub verify
{
  my $got = shift;
  my $expected = _v(shift);

  return map { err2str($_) } $expected->($got, 1, undef, @_)
    if wantarray;

  my $error = $expected->($got, 1, undef, @_);
  if ($error)
  {
    $error = err2str($error);
    die $error unless defined(wantarray);
  }

  return $error;
}

sub verify_not_exists
{
  my $expected = _v(shift);

  return map { err2str($_) } $expected->(undef, 0, undef, @_)
    if wantarray;

  my $error = $expected->(undef, 0, undef, @_);
  if ($error)
  {
    $error = err2str($error);
    die $error unless defined(wantarray);
  }

  return $error;
}

###############################################################################

1
