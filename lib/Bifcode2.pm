package Bifcode2;
use 5.010;
use strict;
use warnings;
use boolean ();
use Exporter::Tidy all => [
    qw( encode_bifcode2
      decode_bifcode2
      force_bifcode2
      diff_bifcode2)
];

# ABSTRACT: Serialisation similar to Bencode + undef/UTF8

our $VERSION = '2.000_4';
our $max_depth;
our @CARP_NOT = (__PACKAGE__);

sub _croak {
    require Carp;
    my $type     = shift // Carp::croak('usage: _croak($TYPE, [$msg])');
    my %messages = (
        Decode             => 'garbage at',
        DecodeBifcodeTerm  => 'missing BIFCODE terminator at',
        DecodeBytes        => 'malformed BYTES length at',
        DecodeBytesTrunc   => 'unexpected BYTES end of data at',
        DecodeBytesTerm    => 'missing BYTES termination at',
        DecodeDepth        => 'nesting depth exceeded at',
        DecodeTrunc        => 'unexpected end of data at',
        DecodeReal         => 'malformed REAL data at',
        DecodeRealTrunc    => 'unexpected REAL end of data at',
        DecodeInteger      => 'malformed INTEGER data at',
        DecodeIntegerTrunc => 'unexpected INTEGER end of data at',
        DecodeTrailing     => 'trailing garbage at',
        DecodeUTF8         => 'malformed UTF8 string length at',
        DecodeUTF8Trunc    => 'unexpected UTF8 end of data at',
        DecodeUTF8Term     => 'missing UTF8 termination at',
        DecodeUsage        => undef,
        DiffUsage          => 'usage: diff_bifcode2($b1, $b2, [$diff_args])',
        EncodeBytesUndef   => 'Bifcode2::BYTES ref is undefined',
        EncodeReal         => undef,
        EncodeRealUndef    => 'Bifcode2::REAL ref is undefined',
        EncodeInteger      => undef,
        EncodeIntegerUndef => 'Bifcode2::INTEGER ref is undefined',
        DecodeKeyType      => 'dict key is not BYTES or UTF8 at',
        DecodeKeyDuplicate => 'duplicate dict key at',
        DecodeKeyOrder     => 'dict key not in sort order at',
        DecodeKeyValue     => 'dict key is missing value at',
        EncodeUTF8Undef    => 'Bifcode2::UTF8 ref is undefined',
        EncodeUnhandled    => undef,
        EncodeUsage        => 'usage: encode_bifcode2($arg)',
        ForceUsage         => 'ref and type must be defined',
    );

    my $err = 'Bifcode2::Error::' . $type;
    my $msg = shift // $messages{$type}
      // Carp::croak("Bifcode2::_croak($type) has no message ");
    my $short = Carp::shortmess('');

    $msg =~ s! at$!' at input byte '. ( pos() // 0 )!e;

    eval qq[
        package $err {
            use overload
              bool => sub { 1 },
              '""' => sub { \${ \$_[0] } . ' (' . ( ref \$_[0] ) . ')$short' },
              fallback => 1;
            1;
        }];

    die bless \$msg, $err;
}

my $chunk = qr/ \G (?|
      (~,)
    | (f,)
    | (t,)
    | (B|b|u) (?:     ( 0 |    [1-9]   [0-9]* ) \. )?
    | (i)     (?:     ( 0 | -? [1-9]   [0-9]* ) ,  )?
    | (r)     (?:     ( 0 | -? [1-9]   [0-9]* )
                \.    ( 0 |    [0-9]*  [1-9]  )
                e ( (?: 0 | -? [1-9] ) [0-9]* ) , 
                                                   )?
    | (\[)
    | (\{)
) /x;

sub _decode_bifcode2_key {

    unless (m/ \G (b|u) (?: ( 0 | [1-9] [0-9]* ) \. )? /gcx) {
        _croak m/ \G \z /xgc ? 'DecodeTrunc' : 'DecodeKeyType';
    }

    if ( $1 eq 'b' ) {
        my $len = $2 // _croak 'DecodeBytes';
        _croak 'DecodeBytesTrunc' if $len > length() - pos();

        my $data = substr $_, pos(), $len;
        pos() = pos() + $len;

        _croak 'DecodeBytesTerm' unless m/ \G : /xgc;
        return $data;
    }
    elsif ( $1 eq 'u' ) {
        my $len = $2 // _croak 'DecodeUTF8';
        _croak 'DecodeUTF8Trunc' if $len > length() - pos();

        utf8::decode( my $str = substr $_, pos(), $len );
        pos() = pos() + $len;

        _croak 'DecodeUTF8Term' unless m/ \G : /xgc;
        return $str;
    }
}

sub _decode_bifcode2_chunk {
    local $max_depth = $max_depth - 1 if defined $max_depth;

    unless (m/$chunk/gc) {
        _croak m/ \G \z /xgc ? 'DecodeTrunc' : 'Decode';
    }

    if ( $1 eq '~,' ) {
        return undef;
    }
    elsif ( $1 eq 'f,' ) {
        return boolean::false;
    }
    elsif ( $1 eq 't,' ) {
        return boolean::true;
    }
    elsif ( $1 eq 'b' ) {
        my $len = $2 // _croak 'DecodeBytes';
        _croak 'DecodeBytesTrunc' if $len > length() - pos();

        my $data = substr $_, pos(), $len;
        pos() = pos() + $len;

        _croak 'DecodeBytesTerm' unless m/ \G , /xgc;
        return $data;
    }
    elsif ( $1 eq 'u' ) {
        my $len = $2 // _croak 'DecodeUTF8';
        _croak 'DecodeUTF8Trunc' if $len > length() - pos();

        utf8::decode( my $str = substr $_, pos(), $len );
        pos() = pos() + $len;

        _croak 'DecodeUTF8Term' unless m/ \G , /xgc;
        return $str;
    }
    elsif ( $1 eq 'i' ) {
        return 0 + $2 if defined $2;
        _croak 'DecodeIntegerTrunc' if m/ \G \z /xgc;
        _croak 'DecodeInteger';
    }
    elsif ( $1 eq 'r' ) {
        if ( !defined $2 ) {
            _croak 'DecodeRealTrunc' if m/ \G \z /xgc;
            _croak 'DecodeReal';
        }
        _croak 'DecodeReal'
          if $2 eq '0'      # mantissa 0.
          and $3 eq '0'     # mantissa 0.0
          and $4 ne '0';    # sign or exponent 0.0e0

        return 0.0 + ( $2 . '.' . $3 . 'e' . $4 );
    }
    elsif ( $1 eq '[' ) {
        _croak 'DecodeDepth' if defined $max_depth and $max_depth < 0;

        my @list;
        until (m/ \G \] /xgc) {
            push @list, _decode_bifcode2_chunk();
        }
        return \@list;
    }
    elsif ( $1 eq '{' ) {
        _croak 'DecodeDepth' if defined $max_depth and $max_depth < 0;

        my $last_key;
        my %hash;
        until (m/ \G \} /xgc) {
            _croak 'DecodeTrunc' if m/ \G \z /xgc;

            my $key = _decode_bifcode2_key();

            _croak 'DecodeKeyDuplicate' if exists $hash{$key};
            _croak 'DecodeKeyOrder'
              if defined $last_key and $key lt $last_key;
            _croak 'DecodeKeyValue' if m/ \G \} /xgc;

            $last_key = $key;
            $hash{$key} = _decode_bifcode2_chunk();
        }
        return \%hash;
    }
    elsif ( $1 eq 'B' ) {
        my $len = $2 // _croak 'DecodeBifcode';
        _croak 'DecodeBifcodeTrunc' if $len > length() - pos();

        my $res = _decode_bifcode2_chunk();
        _croak 'DecodeBifcodeTerm' unless m/ \G , /xgc;

        return $res;
    }
}

sub decode_bifcode2 {
    local $_         = shift;
    local $max_depth = shift;

    _croak 'DecodeUsage', 'decode_bifcode2: too many arguments' if @_;
    _croak 'DecodeUsage', 'decode_bifcode2: input undefined'
      unless defined $_;
    _croak 'DecodeUsage', 'decode_bifcode2: only accepts bytes'
      if utf8::is_utf8($_);

    my $deserialised_data = _decode_bifcode2_chunk();
    _croak 'DecodeTrailing', " For: $_" if $_ !~ m/ \G \z /xgc;
    return $deserialised_data;
}

my $number_qr = qr/\A ( 0 | -? [1-9] [0-9]* )
                    ( \. ( [0-9]+? ) 0* )?
                    ( e ( -? [0-9]+ ) )? \z/xi;

sub _encode_bifcode2 {
    map {
        if ( !defined $_ ) {
            '~' . ',';
        }
        elsif ( ( my $ref = ref $_ ) eq '' ) {
            if ( utf8::is_utf8($_) ) {
                utf8::encode( my $str = $_ );
                'u' . length($str) . '.' . $str . ',';
            }
            elsif ( $_ =~ $number_qr ) {
                if ( defined $3 or defined $5 ) {

                    # normalize to BIFCODE2_REAL standards
                    my $x = 'r' . ( 0 + $1 )    # remove leading zeros
                      . '.' . ( $3 // 0 ) . 'e' . ( 0 + ( $5 // 0 ) ) . ',';
                    $x =~ s/ ([1-9]) (0+ e)/.${1}e/x;    # remove trailing zeros
                    $x;
                }
                else {
                    'i' . $_ . ',';
                }
            }
            elsif ( $_ =~ m/[^\x{20}-\x{7E}]/ ) {
                'b' . length($_) . '.' . $_ . ',';
            }
            else {
                'u' . length($_) . '.' . $_ . ',';
            }
        }
        elsif ( $ref eq 'ARRAY' ) {
            '[' . join( '', map _encode_bifcode2($_), @$_ ) . ']';
        }
        elsif ( $ref eq 'HASH' ) {
            '{' . join(
                '',
                do {
                    my $k;
                    my @k = sort keys %$_;

                    map {
                        $k = shift @k;

                        if ( utf8::is_utf8($k) ) {
                            utf8::encode($k);
                            ( 'u' . length($k) . '.' . $k . ':', $_ );
                        }
                        elsif ( $k =~ m/[^\x{20}-\x{7E}]/ ) {
                            ( 'b' . length($k) . '.' . $k . ':', $_ );
                        }
                        else {
                            ( 'u' . length($k) . '.' . $k . ':', $_ );
                        }
                    } _encode_bifcode2( @$_{@k} );
                  }
            ) . '}';
        }
        elsif ( $ref eq 'SCALAR' or $ref eq 'Bifcode2::BYTES' ) {
            $$_ // _croak 'EncodeBytesUndef';
            'b' . length($$_) . '.' . $$_ . ',';
        }
        elsif ( boolean::isBoolean($_) ) {
            ( $_ ? 't' : 'f' ) . ',';
        }
        elsif ( $ref eq 'Bifcode2::INTEGER' ) {
            $$_ // _croak 'EncodeIntegerUndef';
            _croak 'EncodeInteger', 'invalid integer: ' . $$_
              unless $$_ =~ m/\A (?: 0 | -? [1-9] [0-9]* ) \z/x;
            sprintf 'i%s,', $$_;
        }
        elsif ( $ref eq 'Bifcode2::REAL' ) {
            $$_ // _croak 'EncodeRealUndef';
            _croak 'EncodeReal', 'invalid real: ' . $$_
              unless $$_ =~ $number_qr;

            my $x = 'r' . ( 0 + $1 )    # remove leading zeros
              . '.' . ( $3 // 0 ) . 'e' . ( 0 + ( $5 // 0 ) ) . ',';
            $x =~ s/ ([1-9]) (0+ e)/.${1}e/x;    # remove trailing zeros
            $x;
        }
        elsif ( $ref eq 'Bifcode2::UTF8' ) {
            my $str = $$_ // _croak 'EncodeUTF8Undef';
            utf8::encode($str);
            'u' . length($str) . '.' . $str . ',';
        }
        elsif ( $ref eq 'Bifcode2::BIFCODE2' ) {
            my $str = $$_ // _croak 'EncodeBifcodeUndef';
            'B' . length($str) . '.' . $str . ',';
        }
        else {
            _croak 'EncodeUnhandled', 'unhandled data type: ' . $ref;
        }
    } @_;
}

sub encode_bifcode2 {
    _croak 'EncodeUsage' if @_ != 1;
    bless \(&_encode_bifcode2)[0], __PACKAGE__ . '::BIFCODE2';
}

sub force_bifcode2 {
    my $ref  = shift;
    my $type = shift;

    _croak 'ForceUsage' unless defined $ref and defined $type;
    bless \$ref, 'Bifcode2::' . uc($type);
}

sub _expand_bifcode {
    my $bifcode = shift;
    $bifcode =~ s/ (
            [\[\]\{\}]
            | ~,
            | (B|u|b) [0-9]+ \.
            | r -? [0-9]+ \. [0-9]+ e -? [0-9]+ ,
            | i [0-9]+ ,
        ) /\n$1/gmx;
    $bifcode =~ s/ \A \n //mx;
    $bifcode . "\n";
}

sub diff_bifcode2 {
    _croak 'DiffUsage' unless @_ >= 2 and @_ <= 3;
    my $b1        = shift;
    my $b2        = shift;
    my $diff_args = shift || { STYLE => 'Unified' };

    require Text::Diff;

    $b1 = _expand_bifcode($b1);
    $b2 = _expand_bifcode($b2);
    return Text::Diff::diff( \$b1, \$b2, $diff_args );
}

sub anyevent_read_type {
    my ( $handle, $cb, $maxdepth ) = @_;

    sub {
        return unless defined $_[0]{rbuf};
        unless ( $handle->{rbuf} =~ m/^(B(0|[1-9][0-9]*)\.)/ ) {
            $handle->_error( Errno::EBADMSG() );
            return;
        }

        $handle->unshift_read(
            chunk => length($1) + $2 + 1,
            sub {
                $cb->( $_[0], decode_bifcode2( $_[1], $maxdepth ) );
            }
        );

        1;
    };
}

sub anyevent_write_type {
    my ( $handle, $ref ) = @_;
    encode_bifcode2( encode_bifcode2($ref) );
}

1;

package Bifcode2::BIFCODE2;
use overload
  bool     => sub { 1 },
  '""'     => sub { ${ $_[0] } },
  fallback => 1;

1;

__END__

=pod

=encoding utf8

=head1 NAME

Bifcode2 - encode and decode BIFCODE2 serialization format

=head1 VERSION

2.000_4 (yyyy-mm-dd)

=head1 SYNOPSIS

    use utf8;
    use boolean;
    use Bifcode2 qw( encode_bifcode2 decode_bifcode2 );

    my $bifcode = encode_bifcode2 {
        bools   => [ boolean::false, boolean::true, ],
        bytes   => \pack( 's<',       255 ),
        integer => 25,
        real    => 1.25e-5,
        null    => undef,
        utf8    => "Ελύτη",
    };

    # 7b 75 35 2e 62 6f 6f 6c 73 3a 5b 66 2c 74 2c    {u5.bools:[f,t,
    # 5d 75 35 2e 62 79 74 65 73 3a 62 32 2e ff  0    ]u5.bytes:b2...
    # 2c 75 37 2e 69 6e 74 65 67 65 72 3a 69 32 35    ,u7.integer:i25
    # 2c 75 34 2e 6e 75 6c 6c 3a 7e 2c 75 34 2e 72    ,u4.null:~,u4.r
    # 65 61 6c 3a 72 31 2e 32 35 65 2d 35 2c 75 34    eal:r1.25e-5,u4
    # 2e 75 74 66 38 3a 75 31 30 2e ce 95 ce bb cf    .utf8:u10......
    # 8d cf 84 ce b7 2c 7d                            .....,}

    my $decoded = decode_bifcode2 $bifcode;

=head1 DESCRIPTION

B<Bifcode2> implements the I<BIFCODE2> serialisation format, a mixed
binary/text encoding with support for the following data types:

=over

=item * Primitive:

=over

=item * Undefined(null)

=item * Booleans(true/false)

=item * Integer numbers

=item * Real numbers

=item * UTF8 strings

=item * Binary strings

=back

=item * Structured:

=over

=item * Arrays(lists)

=item * Hashes(dictionaries)

=back

=back

The encoding is simple to construct and relatively easy to parse. There
is no need to escape special characters in strings. It is not
considered human readable, but as it is mostly text it can usually be
visually debugged.

I<BIFCODE2> can only be constructed canonically; i.e. there is only one
possible encoding per data structure. This property makes it suitable
for comparing structures (using cryptographic hashes) across networks.

In terms of size the encoding is similar to minified JSON. In terms of
speed this module compares well with other pure Perl encoding modules
with the same features.

=head1 MOTIVATION

I<BIFCODE2> was created for a project because none of currently
available serialization formats (Bencode, JSON, MsgPack, Netstrings,
Sereal, YAML, etc) met the requirements of:

=over

=item * Support for undef

=item * Support for binary data

=item * Support for UTF8 strings

=item * Universally-recognized canonical form for hashing

=item * Trivial to construct on the fly from SQLite triggers

=back

I have no lofty goals or intentions to promote this outside of my
specific case, but would appreciate hearing about other uses or
implementations.

=head1 SPECIFICATION

The encoding is defined as follows:

=head2 BIFCODE2_UNDEF

A null or undefined value correspond to "~,".

=head2 BIFCODE2_TRUE and BIFCODE2_FALSE

Boolean values are represented by "t," and "f,".

=head2 BIFCODE2_UTF8

A UTF8 string is "u" followed by the octet length of the encoded string
as a base ten number followed by a "." and the encoded string followed
by ",". For example the Perl string "\x{df}" (ß) corresponds to
"u2.\x{c3}\x{9f},".

=head2 BIFCODE2_BYTES

Opaque data is 'b' followed by the octet length of the data as a base
ten number followed by a "." and then the data itself followed by ",".
For example a three-byte blob 'xyz' corresponds to 'b3.xyz,'.

=head2 BIFCODE2_INTEGER

Integers are represented by an 'i' followed by the number in base 10
followed by a ','. For example 'i3,' corresponds to 3 and 'i-3,'
corresponds to -3. Integers have no size limitation. 'i-0,' is invalid.
All encodings with a leading zero, such as 'i03,', are invalid, other
than 'i0,', which of course corresponds to 0.

=head2 BIFCODE2_REAL

Real numbers are represented by an 'r' followed by a decimal number in
base 10 followed by a 'e' followed by an exponent followed by a ','.
For example 'r3.0e-1,' corresponds to 0.3 and 'r-0.1e0,' corresponds to
-0.1. Reals have no size limitation.  'r-0.0e0,' is invalid.  All
encodings with an extraneous leading zero, such as 'r03.0e0,', or an
extraneous trailing zero, such as 'r3.10e0,', are invalid.

=head2 BIFCODE2_LIST

Lists are encoded as a '[' followed by their elements (also I<BIFCODE2>
encoded) followed by a ']'. For example '[u4.spam,u4.eggs,]'
corresponds to ['spam', 'eggs'].

=head2 BIFCODE2_DICT

Dictionaries are encoded as a '{' followed by a list of alternating
keys and their corresponding values followed by a '}'. Keys must be of
type BIFCODE2_UTF8 or BIFCODE2_BYTES and are encoded with a ":" as the
last character instead of ",".

For example, '{u3.cow:u3.moo,u4.spam:u4.eggs,}' corresponds to {'cow':
'moo', 'spam': 'eggs'} and '{u4.spam:[u1.a,u1.b,]}' corresponds to
{'spam'.  ['a', 'b']}. Keys must appear in sorted order (sorted as raw
strings, not alphanumerics).

=head2 BIFCODE2_BIFCODE2

A Bifcode string is "B" followed by the octet length of the encoded
string as a base ten number followed by a "." and the encoded string
followed by ",". This is typically used to frame Bifcode structures
over a network.

=head1 INTERFACE

=head2 C<encode_bifcode2( $datastructure )>

Takes a single argument which may be a scalar, or may be a reference to
either a scalar, an array, a hash or a Bifcode2::BIFCODE2 object.
Arrays and hashes may in turn contain values of these same types.
Returns a byte string blessed as C<Bifcode2::BIFCODE2>.

The mapping from Perl to I<BIFCODE2> is as follows:

=over

=item * 'undef' maps directly to BIFCODE2_UNDEF.

=item * The C<true> and C<false> values from the L<boolean>
distribution encode to BIFCODE2_TRUE and BIFCODE2_FALSE.

=item * A plain scalar is treated as follows:

=over

=item

BIFCODE2_UTF8 if C<utf8::is_utf8> returns true; or

=item

BIFCODE2_INTEGER if it looks like a canonically represented integer; or

=item

BIFCODE2_REAL if it looks like a real number; or

=item

BIFCODE2_UTF8 if it only contains ASCII characters; or

=item

BIFCODE2_BYTES when none of the above applies.

=back

You can force scalars to be encoded a particular way by passing a
reference to them blessed as Bifcode2::BYTES, Bifcode2::INTEGER,
Bifcode2::REAL or Bifcode2::UTF8. The C<force_bifcode2> function below
can help with creating such references.

=item * SCALAR references become BIFCODE2_BYTES.

=item * ARRAY references become BIFCODE2_LIST.

=item * HASH references become BIFCODE2_DICT.

=item * Bifcode2::BIFCODE2 references become BIFCODE2_BIFCODE2.

=back

This subroutine croaks on unhandled data types.

=head2 C<decode_bifcode2( $string [, $max_depth ] )>

Takes a byte string and returns the corresponding deserialised data
structure.

If you pass an integer for the second option, it will croak when
attempting to parse dictionaries nested deeper than this level, to
prevent DoS attacks using maliciously crafted input.

I<BIFCODE2> types are mapped back to Perl in the reverse way to the
C<encode_bifcode2> function, except for:

=over

=item * Any scalars which were "forced"
to a particular type (using blessed references) will decode as plain
scalars.

=item * BIFCODE2_BIFCODE2 types are fully inflated into 
Perl structures, and not the intermediate I<BIFCODE2> string.

=back

Croaks on malformed data.

=head2 C<force_bifcode2( $scalar, $type )>

Returns a reference to $scalar blessed as Bifcode2::$TYPE. The value of
$type is not checked, but the C<encode_bifcode2> function will only
accept the resulting reference where $type is one of 'bytes', 'real',
'integer' or 'utf8'.

=head2 C<diff_bifcode2( $bc1, $bc2, [$diff_args] )>

Returns a string representing the difference between two bifcodes. The
inputs do not need to be valid Bifcode2; they are only expanded with a
very simple regex before the diff is done. The third argument
(C<$diff_args>) is passed directly to L<Text::Diff>.

Croaks if L<Text::Diff> is not installed.

=head2 AnyEvent::Handle Support

B<Bifcode2> implements the L<AnyEvent::Handle> C<anyevent_read_type>
and C<anyevent_write_type> functions which allow you to do this:

    $handle->push_write( 'Bifcode2' => { your => 'structure here' } );

    $handle->push_read(
        'Bifcode2' => sub {
            my ( $hdl, $ref ) = @_;
            # do stuff with $ref
        },
        $maxdepth   # passed straight to decode_bifcode2()
    );

=head1 DIAGNOSTICS

The following exceptions may be raised by B<Bifcode2>:

=over

=item Bifcode2::Error::Decode

Your data is malformed in a non-identifiable way.

=item Bifcode2::Error::DecodeBytes

Your data contains a byte string with an invalid length.

=item Bifcode2::Error::DecodeBytesTrunc

Your data includes a byte string declared to be longer than the
available data.

=item Bifcode2::Error::DecodeBytesTerm

Your data includes a byte string that is missing a "," terminator.

=item Bifcode2::Error::DecodeDepth

Your data contains dicts or lists that are nested deeper than the
$max_depth passed to C<decode_bifcode2()>.

=item Bifcode2::Error::DecodeTrunc

Your data is truncated.

=item Bifcode2::Error::DecodeReal

Your data contained something that was supposed to be a real but didn't
make sense.

=item Bifcode2::Error::DecodeRealTrunc

Your data contains a real that is truncated.

=item Bifcode2::Error::DecodeInteger

Your data contained something that was supposed to be an integer but
didn't make sense.

=item Bifcode2::Error::DecodeIntegerTrunc

Your data contains an integer that is truncated.

=item Bifcode2::Error::DecodeKeyType

Your data violates the I<bifcode> format constaint that all dict keys
be BIFCODE2_BYTES or BIFCODE2_UTF8.

=item Bifcode2::Error::DecodeKeyDuplicate

Your data violates the I<bifcode> format constaint that all dict keys
must be unique.

=item Bifcode2::Error::DecodeKeyOrder

Your data violates the I<bifcode> format constaint that dict keys must
appear in lexical sort order.

=item Bifcode2::Error::DecodeKeyValue

Your data contains a dictionary with an odd number of elements.

=item Bifcode2::Error::DecodeTrailing

Your data does not end after the first I<bifcode>-serialised item.

=item Bifcode2::Error::DecodeUTF8

Your data contained a UTF8 string with an invalid length.

=item Bifcode2::Error::DecodeUTF8Trunc

Your data includes a string declared to be longer than the available
data.

=item Bifcode2::Error::DecodeUTF8Term

Your data includes a UTF8 string that is missing a "," terminator.

=item Bifcode2::Error::DecodeUsage

You called C<decode_bifcode2()> with invalid arguments.

=item Bifcode2::Error::DiffUsage

You called C<diff_bifcode2()> with invalid arguments.

=item Bifcode2::Error::EncodeBytesUndef

You attempted to encode C<undef> as a byte string.

=item Bifcode2::Error::EncodeReal

You attempted to encode something as a real that isn't recognised as
one.

=item Bifcode2::Error::EncodeRealUndef

You attempted to encode C<undef> as a real.

=item Bifcode2::Error::EncodeInteger

You attempted to encode something as an integer that isn't recognised
as one.

=item Bifcode2::Error::EncodeIntegerUndef

You attempted to encode C<undef> as an integer.

=item Bifcode2::Error::EncodeUTF8Undef

You attempted to encode C<undef> as a UTF8 string.

=item Bifcode2::Error::EncodeUnhandled

You are trying to serialise a data structure that contains a data type
not supported by the I<bifcode> format.

=item Bifcode2::Error::EncodeUsage

You called C<encode_bifcode2()> with invalid arguments.

=item Bifcode2::Error::ForceUsage

You called C<force_bifcode2()> with invalid arguments.

=back

=head1 BUGS AND LIMITATIONS

Strings and numbers are practically indistinguishable in Perl, so
C<encode_bifcode2()> has to resort to a heuristic to decide how to
serialise a scalar. This cannot be fixed.

=head1 SEE ALSO

This distribution includes the L<diff-bifcode> command-line utility for
comparing I<BIFCODE2> in files.

=head1 AUTHOR

Mark Lawrence <nomad@null.net>, heavily based on Bencode by Aristotle
Pagaltzis <pagaltzis@gmx.de>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c):

=over

=item * 2015 by Aristotle Pagaltzis

=item * 2017-2019 by Mark Lawrence.

=back

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

