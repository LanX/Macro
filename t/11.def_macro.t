#!perl 
use Test::More;

use lib '../lib';
use Macro;

{
  package TST;

  Macro::def_macro macro => sub { q[print "Macro"] };
  Macro::def_macro TST2::macro => sub { q[print "Macro"] };
  
}


ok( exists &TST::macro , "sub installed into callers package");
ok( exists &TST2::macro, "full qualified sub installed");

ok( Macro::is_macro(\&TST::macro), "marked as macro" );
ok( Macro::is_macro(\&TST2::macro), "marked as macro" );


done_testing();




