#!perl 
# -*- cperl-mode -*-

use Test::More;

use lib '../lib';

{
  package TST;

  use Macro;


  sub tst :Macro {
    print "bla"
  }

}


diag Macro::is_macro(\&TST::tst);


done_testing();

  
