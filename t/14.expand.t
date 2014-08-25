#!perl 
use strict;
use warnings;
use Carp;

use Test::More;


use lib '../lib';
use Macro;

$Macro::DEBUG=0;

Macro::def_macro
  macro => sub
  {
    qq[return "Macro @_"]
  };

sub tst {
  macro(1,2,3)
}


Macro::expand('main::tst');

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

  Macro::expand('tst');
  
  Test::More::is( tst(), "Macro 1 2 3", "Unqualified sub expanded into callers package " );

}

# ------
Macro::expand('TST::tst2');
Test::More::is( TST::tst2(), "Macro 1 2 3", "Fully Qualified sub expanded" );


# ------
my $old_subref = sub { macro(1,2,3) };
my $new_subref = Macro::expand($old_subref);
Test::More::is( $new_subref->(), "Macro 1 2 3", "Subref Expanded" );






done_testing();




