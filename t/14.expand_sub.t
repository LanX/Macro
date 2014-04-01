#!perl 
use strict;
use warnings;
use Carp;

use Test::More;


use lib '../lib';
use Macro;

$Macro::DB=0;

Macro::def_macro
  macro => sub
  {
    qq[return "Macro @_"]
  };

sub tst {
  macro(1,2,3)
}


Macro::expand_sub('main::tst');

is( tst(), "Macro 1 2 3", "Unqualified sub expanded into main" );

{
  package TST;

  Macro::def_macro
      macro => sub
	{
	  qq[return "Macro @_"]
	};

  sub tst {
    macro(1,2,3)
  }

  sub tst2 {
    macro(1,2,3)
  }

  Macro::expand_sub('tst');
  
  Test::More::is( tst(), "Macro 1 2 3", "Unqualified sub expanded into callers package " );

}

Macro::expand_sub('TST::tst2');
  
Test::More::is( TST::tst2(), "Macro 1 2 3", "Qualified sub expanded" );







done_testing();




