#!/usr/bin/env perl
use strict;
use warnings;
use lib 'lib';
use FindBin qw($RealBin);
use lib "$RealBin/lib";
use Bifcode qw( encode_bifcode decode_bifcode force_bifcode );
use Data::Dumper;
use Path::Tiny;
use Test::Bifcode;
no warnings 'once';

my $str = q{encode_bifcode {
    bools   => [ $Bifcode::FALSE, $Bifcode::TRUE, ],
    bytes   => \pack( 's<',       255 ),
    integer => 25,
    float   => 1.0 / 80000.0,
    undef   => undef,
    utf8    => "\x{df}",
};
};

print 'my $bifcode = ' . $str;
my $bifcode = eval $str;

print $bifcode, "\n\n";
my $bifcode_file = Path::Tiny->tempfile;
$bifcode_file->spew_raw($bifcode);

my $format      = '12/1 " %2x"' . "\n" . '"    " "%_p"' . "\n" . '"\n"' . "\n";
my $format_file = Path::Tiny->tempfile;
$format_file->spew($format);
system( 'hexdump', '-f', $format_file, $bifcode_file );
