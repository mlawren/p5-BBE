use strict;
use warnings;
use lib 'lib';
use FindBin qw($RealBin);
use lib "$RealBin/lib";
use Test::Bifcode::V2;
use Test::More 0.88;    # for done_testing
use Test::Needs 'Text::Diff';
use Bifcode::V2 'encode_bifcode', 'diff_bifcode';

eval { diff_bifcode() };
isa_ok $@, 'Bifcode::V2::Error::DiffUsage', 'diff_bifcode not enough arguments';

eval { diff_bifcode( 1, 2, 3, 4 ) };
isa_ok $@, 'Bifcode::V2::Error::DiffUsage', 'diff_bifcode too many arguments';

eval { encode_bifcode( 1, 2, 3 ) };
isa_ok $@, 'Bifcode::V2::Error::EncodeUsage', 'too many arguments';

my $a = '[u1.a,u1.b,u1.c,]';
my $b = '[u1.a,u1.B,~,]';

is diff_bifcode( $a, $a ), '', 'same bifcode no diff';

like diff_bifcode( $a, $b ), qr/^ \[$/sm,   'bifcode expanded';
like diff_bifcode( $a, $b ), qr/^(-|\+)/sm, 'diff text structure';

$a = '[u1.a,x1:b,u1.c,]';
$b = '[u1.a,u1.b,~,]';

like diff_bifcode( $a, $b ), qr/^ \[$/sm,   'bifcode expanded on invalid';
like diff_bifcode( $a, $b ), qr/^(-|\+)/sm, 'diff text structure on invalid';

done_testing;
