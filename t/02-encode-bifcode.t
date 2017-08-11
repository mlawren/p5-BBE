use strict;
use warnings;
use lib 'lib';
use FindBin qw($RealBin);
use lib "$RealBin/lib";
use Test::Bifcode;
use Test::More 0.88;    # for done_testing
use Bifcode 'encode_bifcode', 'force_bifcode';

subtest 'UNDEF' => sub {
    enc_ok undef, '~';
};

subtest 'BOOLEAN' => sub {
    enc_ok $Bifcode::TRUE  => '1';
    enc_ok $Bifcode::FALSE => '0';
};

subtest 'INTEGER' => sub {
    enc_ok 4 => 'I4,';
    enc_ok force_bifcode( 5, 'integer' ) => 'I5,';
    enc_ok 0                      => 'I0,';
    enc_ok - 10                   => 'I-10,';
    enc_ok '12345678901234567890' => 'I12345678901234567890,';
    enc_error_ok force_bifcode( '00', 'integer' ) => qr/invalid integer: 00/,
      'invalid 00 integer';
    enc_error_ok force_bifcode( '00abc', 'integer' ) =>
      qr/invalid integer: 00abc/,
      'forcing a non-integer as integer';
};

subtest 'FLOAT' => sub {
    enc_ok '0.0' => 'F0.0e0,';

    enc_ok '1.0e0'  => 'F1.0e0,';
    enc_ok '1.0e1'  => 'F1.0e1,';
    enc_ok '1.0e-1' => 'F1.0e-1,';

    enc_ok '-1.0e0'  => 'F-1.0e0,';
    enc_ok '-1.0e1'  => 'F-1.0e1,';
    enc_ok '-1.0e-1' => 'F-1.0e-1,';

    #    enc_ok '0100.2e0'   => 'F100.2e0,'; # leading 0 removed

    enc_ok '100.2'   => 'F100.2e0,';     # add missing e
    enc_ok '100.20'  => 'F100.2e0,';     # trailing 0 removed
    enc_ok '100.08'  => 'F100.08e0,';    # leading .0 kept
    enc_ok '100.080' => 'F100.08e0,';    # trailing 0 removed leading .0 kept

    enc_ok '100.1e1'   => 'F100.1e1,';   # unchanged
    enc_ok '100.10e1'  => 'F100.1e1,';   # trailing 0 removed
    enc_ok '100.01e1'  => 'F100.01e1,';  # leading .0 kept
    enc_ok '100.010e1' => 'F100.01e1,';  # trailing 0 removed leading .0 kept

    enc_ok '100e0'    => 'F100.0e0,';    # ensure decimal
    enc_ok '100e01'   => 'F100.0e1,';
    enc_ok '100e1'    => 'F100.0e1,';
    enc_ok '100e9'    => 'F100.0e9,';
    enc_ok '100e11'   => 'F100.0e11,';
    enc_ok '100e-1'   => 'F100.0e-1,';
    enc_ok '100e-9'   => 'F100.0e-9,';
    enc_ok '100e-09'  => 'F100.0e-9,';
    enc_ok '100e-011' => 'F100.0e-11,';

    enc_ok 1.0 / 3e7 => 'F3.33333333333333e-8,';

    # Plain integer
    enc_ok force_bifcode( 0, 'float' ) => 'F0.0e0,';

    # Plain float
    enc_ok force_bifcode( '100.2', 'float' ) => 'F100.2e0,';

    # Plain float trailing .x0
    enc_ok force_bifcode( '100.20', 'float' ) => 'F100.2e0,';

    # Plain float leading .0x
    enc_ok force_bifcode( '100.08', 'float' ) => 'F100.08e0,';

    # exponent no decimal
    enc_ok force_bifcode( '100e0', 'float' ) => 'F100.0e0,';

    # decimal and exponent
    enc_ok force_bifcode( '100.2e0', 'float' ) => 'F100.2e0,';

    # decimal and exponent leading .0x
    enc_ok force_bifcode( '100.008e0', 'float' ) => 'F100.008e0,';

    enc_error_ok force_bifcode( '00abc', 'float' ) => qr/invalid float/,
      'forcing a non-float as float';
};

subtest 'UTF8' => sub {
    enc_ok ''    => 'U0:';
    enc_ok $utf8 => $UTF8;
    ok utf8::is_utf8($utf8), 'still have utf8 flag on source string';
    enc_ok 'abc' => 'U3:abc';
    enc_ok force_bifcode( '1234567890', 'utf8' ) => 'U10:1234567890';
    enc_ok force_bifcode( '0',          'utf8' ) => 'U1:0';
    enc_ok '00' => 'U2:00';
};

subtest 'BYTES' => sub {
    enc_ok force_bifcode( $bytes, 'bytes' ) => $BYTES;
    enc_ok \$bytes => $BYTES;
};

subtest 'LIST' => sub {
    enc_ok [] => '[]';
    enc_ok [ 1, 2, undef, $utf8 ] => '[I1,I2,~' . $UTF8 . ']';
    enc_ok [ [ 'Alice', 'Bob' ], [ 2, 3 ] ] => '[[U5:AliceU3:Bob][I2,I3,]]';
};

subtest 'DICT' => sub {
    enc_ok {} => '{}';
    enc_ok { 1 => 'one' } => '{U1:1U3:one}';
    enc_ok { bytes => force_bifcode( $bytes, 'bytes' ) } => '{U5:bytes'
      . $BYTES . '}';

    enc_ok {
        'age'   => 25,
        'eyes'  => 'blue',
        'false' => $Bifcode::FALSE,
        'true'  => $Bifcode::TRUE,
        'undef' => undef,
        $utf8   => $utf8,
      } => '{U3:ageI25,U4:eyesU4:blueU5:false0U4:true1U5:undef~'
      . $UTF8
      . $UTF8 . '}';

    enc_ok {
        'spam.mp3' => {
            'author' => 'Alice',
            'bytes'  => force_bifcode( $bytes, 'bytes' ),
            'length' => 100000,
            'undef'  => undef,
        }
      } => '{U8:spam.mp3{U6:authorU5:Alice'
      . 'U5:bytes'
      . $BYTES
      . 'U6:lengthI100000,U5:undef~' . '}}';

    enc_ok $data1 => $DATA1;
    enc_ok $data2 => $DATA2;
};

eval { encode_bifcode() };
like $@, qr/usage: encode_bifcode\(\$arg\)/, 'not enough arguments';
eval { encode_bifcode( 1, 2 ) };
like $@, qr/usage: encode_bifcode\(\$arg\)/, 'too many arguments';

done_testing;
