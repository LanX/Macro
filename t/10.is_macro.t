#!perl 
use Test::More tests => 2;

use lib '../lib';

use Macro;


my  $c_macro = sub { print "I'm a macro" };
bless $c_macro, "Macro";
is( Macro::is_macro($c_macro),  $c_macro, "Identifying macro");

my  $c_normal = sub { print "I'm not a macro" };
ok( ! Macro::is_macro($c_normal),         "Rejecting non-macro");




