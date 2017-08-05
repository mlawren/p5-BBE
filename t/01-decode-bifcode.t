use strict;
use warnings;
use utf8;
use Test::More 0.88;    # for done_testing
use Test::Differences;
use Bifcode 'decode_bifcode';
require bytes;

my $utf8 =
'ฉันกินกระจกได้ แต่มันไม่ทำให้ฉันเจ็บ';
utf8::encode( my $utf8_bytes = $utf8 );
my $utf8_length  = bytes::length($utf8_bytes);
my $utf8_bifcode = 'U' . $utf8_length . ':' . $utf8_bytes;

my $data         = pack( 's<', 255 );
my $data_length  = bytes::length($data);
my $data_bifcode = 'B' . $data_length . ':' . $data;

sub un {
    my ($frozen) = @_;
    local $, = ', ';
    return 'ARRAY' eq ref $frozen
      ? ( "decode [@$frozen]", decode_bifcode @$frozen )
      : ( "decode '$frozen'", decode_bifcode $frozen );
}

sub decod_ok {
    my ( $frozen,   $thawed ) = @_;
    my ( $testname, $result ) = un $frozen;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    eq_or_diff $result, $thawed, $testname;
}

sub error_ok {
    my ( $frozen, $error_rx, $kind_of_brokenness ) = @_;
    local $@;
    eval { un $frozen };
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    like $@, $error_rx, "reject $kind_of_brokenness";
}

error_ok
  'U0:U0:' => qr/\Atrailing garbage at 3\b/,
  'data past end of first correct encode_bifcode\'d string';
error_ok 'I'  => qr/\Aunexpected end of data at 1\b/, 'aborted integer';
error_ok 'I0' => qr/\Amalformed integer data at 1\b/, 'unterminated integer';
error_ok 'I,' => qr/\Amalformed integer data at 1\b/, 'empty integer';
error_ok
  'I341foo382,' => qr/\Amalformed integer data at 1\b/,
  'malformed integer';
decod_ok '~'           => undef;
decod_ok '1'           => $Bifcode::TRUE;
decod_ok '0'           => $Bifcode::FALSE;
decod_ok 'I4,'         => 4;
decod_ok 'I0,'         => 0;
decod_ok 'I123456789,' => 123456789;
decod_ok 'I-10,'       => -10;
error_ok 'I-0,' => qr/\Amalformed integer data at 1\b/, 'negative zero integer';
error_ok 'I123' => qr/\Amalformed integer data at 1\b/, 'unterminated integer';
error_ok ''     => qr/\Aunexpected end of data at 0/,   'empty data';
error_ok
  'U1:' => qr/\Aunexpected end of string data starting at 3\b/,
  'string longer than data';
error_ok
  'I6,asd' => qr/\Atrailing garbage at 3\b/,
  'integer with trailing garbage';
error_ok
  'U35208734823ljdahflajhdf' => qr/\Agarbage at 0/,
  'garbage looking vaguely like a string, with large count';
error_ok
  'U2:abfdjslhfld' => qr/\Atrailing garbage at 5\b/,
  'string with trailing garbage';
error_ok 'U2:' . $utf8 => qr/\Adecode_bifcode: only accepts bytes\b/,
  'check for utf8 flag';
decod_ok 'U0:'            => '';
decod_ok 'U3:abc'         => 'abc';
decod_ok 'U3:abc'         => 'abc';
decod_ok 'U10:1234567890' => '1234567890';
decod_ok $data_bifcode    => \$data;
decod_ok $utf8_bifcode    => $utf8;
error_ok
  'U02:xy' => qr/\Amalformed string length at 0\b/,
  'string with extra leading zero in count';
error_ok '[' => qr/\Aunexpected end of data at 1\b/, 'unclosed empty list';
decod_ok '[]' => [];
error_ok
  '[]anfdldjfh' => qr/\Atrailing garbage at 2\b/,
  'empty list with trailing garbage';
decod_ok '[~~~]' => [ undef, undef, undef ];
decod_ok '[10]' => [ $Bifcode::TRUE, $Bifcode::FALSE ];
decod_ok '[U0:U0:U0:]' => [ '', '', '' ];
error_ok 'relwjhrlewjh' => qr/\Agarbage at 0/, 'complete garbage';
decod_ok '[I1,I2,I3,]'                        => [ 1,     2,    3 ];
decod_ok '[U3:asdU2:xy' . $utf8_bifcode . ']' => [ 'asd', 'xy', $utf8 ];
decod_ok '[[U5:AliceU3:Bob][I2,I3,~]~]' =>
  [ [ 'Alice', 'Bob' ], [ 2, 3, undef ], undef ];
error_ok '{' => qr/\Aunexpected end of data at 1\b/, 'unclosed empty dict';
error_ok
  '{}foobar' => qr/\Atrailing garbage at 2\b/,
  'empty dict with trailing garbage';
decod_ok '{}' => {};
decod_ok '{' . $data_bifcode . $utf8_bifcode . '}' => { $data => $utf8 };
decod_ok '{' . $utf8_bifcode . $data_bifcode . '}' => { $utf8 => \$data };
decod_ok '{U3:ageI25,U4:eyesU4:blueU5:false0U4:true1U5:undef~}' => {
    'age'   => 25,
    'eyes'  => 'blue',
    'undef' => undef,
    true    => $Bifcode::TRUE,
    false   => $Bifcode::FALSE,
};
decod_ok '{U8:spam.mp3{U6:authorU5:AliceU6:lengthI100000,U5:undef~}}' =>
  { 'spam.mp3' =>
      { 'author' => 'Alice', 'length' => 100000, 'undef' => undef } };
error_ok
  '{~}' => qr/\Adict key is not a string at 1\b/,
  'dict key cannot be undef';
error_ok
  '{U3:foo}' => qr/\Adict key is missing value at 8\b/,
  'dict with odd number of elements';
error_ok
  '{I1,U0:}' => qr/\Adict key is not a string at 1/,
  'dict with integer key';
error_ok
  '{U1:bU0:U1:aU0:}' => qr/\Adict key not in sort order at 12/,
  'missorted keys';
error_ok '{U1:aU0:U1:aU0:}' => qr/\Aduplicate dict key at 12/, 'duplicate keys';
error_ok
  'I03,' => qr/\Amalformed integer data at 1/,
  'integer with leading zero';
error_ok
  '[U01:a]' => qr/\Amalformed string length at 1/,
  'list with string with leading zero in count';
error_ok
  'U9999:x' => qr/\Aunexpected end of string data starting at 6/,
  'string shorter than count';
error_ok
  '[U0:' => qr/\Aunexpected end of data at 4/,
  'unclosed list with content';
error_ok
  '{U0:U0:' => qr/\Aunexpected end of data at 7/,
  'unclosed dict with content';
error_ok
  '{U0:' => qr/\Aunexpected end of data at 4/,
  'unclosed dict with odd number of elements';
error_ok
  'U00:' => qr/\Amalformed string length at 0/,
  'zero-length string with extra leading zero in count';
error_ok
  '[U-3:]' => qr/\Amalformed string length at 1/,
  'list with negative-length string';
error_ok
  'I-03,' => qr/\Amalformed integer data at 1/,
  'negative integer with leading zero';
decod_ok "U2:\x0A\x0D" => "\x0A\x0D";

decod_ok [ '{U1:aU0:}', 1 ] => { a => '' }
  ,    # Accept single dict when max_depth is 1
  error_ok [ '{U1:aU0:}', 0 ] => qr/\Anesting depth exceeded at 1/,
  'single dict when max_depth is 0';
decod_ok [ '{U1:a{U1:aU0:}}', 2 ] => { a => { a => '' } }
  ,    # Accept a nested dict when max_depth is 2
  error_ok [ '{U1:a{U1:aU0:}}', 1 ] => qr/\Anesting depth exceeded at 6/,
  'nested dict when max_depth is 1';
decod_ok [ '[U0:]', 1 ] => [''],    # Accept single list when max_depth is 1
  error_ok [ '[U0:]', 0 ] => qr/\Anesting depth exceeded at 1/,
  'single list when max_depth is 0';
decod_ok [ '[[U0:]]', 2 ] => [ [''] ]
  ,                                 # Accept a nested list when max_depth is 2
  error_ok [ '[[U0:]]', 1 ] => qr/\Anesting depth exceeded at 2/,
  'nested list when max_depth is 1';
decod_ok [ '{U1:a[U0:]}', 2 ] => { a => [''] }
  ,    # Accept dict containing list when max_depth is 2
  error_ok [ '{U1:a[U0:]}', 1 ] => qr/\Anesting depth exceeded at 6/,
  'list in dict when max_depth is 1';
decod_ok [ '[{U1:aU0:}]', 2 ] => [ { 'a' => '' } ]
  ,    # Accept list containing dict when max_depth is 2
  error_ok [ '[{U1:aU0:}]', 1 ] => qr/\Anesting depth exceeded at 2/,
  'dict in list when max_depth is 1';
decod_ok [ '{U1:aU0:U1:b[U0:]}', 2 ] => { a => '', b => [''] }
  ,    # Accept dict containing list when max_depth is 2
  error_ok [ '{U1:aU0:U1:b[U0:]}', 1 ] => qr/\Anesting depth exceeded at 13/,
  'list in dict when max_depth is 1';

done_testing;
