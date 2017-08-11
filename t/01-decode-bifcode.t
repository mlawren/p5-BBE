use strict;
use warnings;
use lib 'lib';
use FindBin qw($RealBin);
use lib "$RealBin/lib";
use Test::Bifcode;
use Test::More 0.88;    # for done_testing

subtest UNDEF => sub {
    decod_ok '~' => undef;
};

subtest BOOLEAN => sub {
    decod_ok '1' => $Bifcode::TRUE;
    decod_ok '0' => $Bifcode::FALSE;
};

subtest INTEGER => sub {
    error_ok 'I' => qr/\Aunexpected end of data at 1\b/, 'aborted integer';
    error_ok
      'I0' => qr/\Amalformed integer data at 1\b/,
      'unterminated integer';
    error_ok 'I,' => qr/\Amalformed integer data at 1\b/, 'empty integer';
    error_ok
      'I341foo382,' => qr/\Amalformed integer data at 1\b/,
      'malformed integer';
    decod_ok 'I4,'         => 4;
    decod_ok 'I0,'         => 0;
    decod_ok 'I123456789,' => 123456789;
    decod_ok 'I-10,'       => -10;
    error_ok
      'I-0,' => qr/\Amalformed integer data at 1\b/,
      'negative zero integer';
    error_ok
      'I123' => qr/\Amalformed integer data at 1\b/,
      'unterminated integer';
    error_ok
      'I6,asd' => qr/\Atrailing garbage at 3\b/,
      'integer with trailing garbage';
    error_ok
      'I03,' => qr/\Amalformed integer data at 1/,
      'integer with leading zero';
    error_ok
      'I-03,' => qr/\Amalformed integer data at 1/,
      'negative integer with leading zero';
};

subtest FLOAT => sub {
    decod_ok 'F0.0e0,'  => '0.0e0';
    decod_ok 'F4.1e-2,' => '4.1e-2';
    error_ok
      'F-0.0e0,' => qr/\Amalformed float data at 8\b/,
      'non-zero exponent for 0.0 float';
    error_ok
      'F0.0e-1,' => qr/\Amalformed float data at 8\b/,
      'non-zero exponent for 0.0 float';
};

subtest UTF8 => sub {
    error_ok
      'U0:U0:' => qr/\Atrailing garbage at 3\b/,
      'data past end of first correct encode_bifcode\'d string';
    error_ok
      'U1:' => qr/\Aunexpected end of string data starting at 3\b/,
      'string longer than data';
    error_ok
      'U35208734823ljdahflajhdf' => qr/\Agarbage at 0/,
      'garbage looking vaguely like a string, with large count';
    error_ok
      'U2:abfdjslhfld' => qr/\Atrailing garbage at 5\b/,
      'string with trailing garbage';
    decod_ok $UTF8            => $utf8;
    decod_ok 'U0:'            => '';
    decod_ok 'U3:abc'         => 'abc';
    decod_ok 'U3:abc'         => 'abc';
    decod_ok 'U10:1234567890' => '1234567890';
    error_ok
      'U02:xy' => qr/\Amalformed string length at 0\b/,
      'string with extra leading zero in count';
    error_ok
      'U9999:x' => qr/\Aunexpected end of string data starting at 6/,
      'string shorter than count';
    decod_ok "U2:\x0A\x0D" => "\x0A\x0D";
    error_ok
      'U00:' => qr/\Amalformed string length at 0/,
      'zero-length string with extra leading zero in count';
};

subtest BYTES => sub {
    decod_ok $BYTES => \$bytes;
};

subtest LIST => sub {
    error_ok '[' => qr/\Aunexpected end of data at 1\b/, 'unclosed empty list';
    decod_ok '[]' => [];
    error_ok
      '[]anfdldjfh' => qr/\Atrailing garbage at 2\b/,
      'empty list with trailing garbage';
    decod_ok '[~~~]' => [ undef, undef, undef ];
    decod_ok '[10]' => [ $Bifcode::TRUE, $Bifcode::FALSE ];
    decod_ok '[U0:U0:U0:]'                => [ '',    '',   '' ];
    decod_ok '[I1,I2,I3,]'                => [ 1,     2,    3 ];
    decod_ok '[U3:asdU2:xy' . $UTF8 . ']' => [ 'asd', 'xy', $utf8 ];
    decod_ok '[[U5:AliceU3:Bob][I2,I3,~]~]' =>
      [ [ 'Alice', 'Bob' ], [ 2, 3, undef ], undef ];
    error_ok
      '[U0:' => qr/\Aunexpected end of data at 4/,
      'unclosed list with content';
    error_ok
      '[U01:a]' => qr/\Amalformed string length at 1/,
      'list with string with leading zero in count';
    error_ok
      '[U-3:]' => qr/\Amalformed string length at 1/,
      'list with negative-length string';

};

subtest DICT => sub {
    error_ok '{' => qr/\Aunexpected end of data at 1\b/, 'unclosed empty dict';
    error_ok
      '{}foobar' => qr/\Atrailing garbage at 2\b/,
      'empty dict with trailing garbage';
    decod_ok '{}' => {};
    decod_ok '{' . $BYTES . $UTF8 . '}' => { $bytes => $utf8 };
    decod_ok '{' . $UTF8 . $BYTES . '}' => { $utf8  => \$bytes };
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

    decod_ok $DATA1 => $data1;
    decod_ok $DATA2 => $data2;

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
    error_ok
      '{U1:aU0:U1:aU0:}' => qr/\Aduplicate dict key at 12/,
      'duplicate keys';
    error_ok
      '{U0:' => qr/\Aunexpected end of data at 4/,
      'unclosed dict with odd number of elements';
    error_ok
      '{U0:U0:' => qr/\Aunexpected end of data at 7/,
      'unclosed dict with content';

};

subtest nest_limits => sub {
    decod_ok [ '[U0:]', 1 ] => [''];    # Accept single list when max_depth is 1
    error_ok [ '[U0:]', 0 ] => qr/\Anesting depth exceeded at 1/,
      'single list when max_depth is 0';

    # Accept a nested list when max_depth is 2
    decod_ok [ '[[U0:]]', 2 ] => [ [''] ];
    error_ok [ '[[U0:]]', 1 ] => qr/\Anesting depth exceeded at 2/,
      'nested list when max_depth is 1';

    # Accept list containing dict when max_depth is 2
    decod_ok [ '[{U1:aU0:}]', 2 ] => [ { 'a' => '' } ];

    error_ok [ '[{U1:aU0:}]', 1 ] => qr/\Anesting depth exceeded at 2/,
      'dict in list when max_depth is 1';

    # Accept single dict when max_depth is 1
    decod_ok [ '{U1:aU0:}', 1 ] => { a => '' };
    error_ok [ '{U1:aU0:}', 0 ] => qr/\Anesting depth exceeded at 1/,
      'single dict when max_depth is 0';

    # Accept a nested dict when max_depth is 2
    decod_ok [ '{U1:a{U1:aU0:}}', 2 ] => { a => { a => '' } };
    error_ok [ '{U1:a{U1:aU0:}}', 1 ] => qr/\Anesting depth exceeded at 6/,
      'nested dict when max_depth is 1';

    # Accept dict containing list when max_depth is 2
    decod_ok [ '{U1:a[U0:]}', 2 ] => { a => [''] };
    error_ok [ '{U1:a[U0:]}', 1 ] => qr/\Anesting depth exceeded at 6/,
      'list in dict when max_depth is 1';

    # Accept dict containing list when max_depth is 2
    decod_ok [ '{U1:aU0:U1:b[U0:]}', 2 ] => { a => '', b => [''] };
    error_ok [ '{U1:aU0:U1:b[U0:]}', 1 ] => qr/\Anesting depth exceeded at 13/,
      'list in dict when max_depth is 1';
};

error_ok [ '[U0:]', 0, 'arg3' ] => qr/\Adecode_bifcode: too many arguments/,
  'decode_bifcode only takes up to 2 args';
error_ok '' => qr/\Aunexpected end of data at 0/, 'empty data';
error_ok $utf8 => qr/\Adecode_bifcode: only accepts bytes\b/,
  'check for utf8 flag';
error_ok 'relwjhrlewjh' => qr/\Agarbage at 0/, 'complete garbage';

done_testing;
