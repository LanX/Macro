# -*- cperl-mode -*-

# t/00.load.t - check module loading and create testing directory
use lib '../lib';

use Test::More tests => 1;
BEGIN {
    use_ok( 'Macro' );
}
