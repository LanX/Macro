#!perl 
use Test::More;

use lib '../lib';
use Macro;

$Macro::DB=0;

Macro::def_macro macro
  => sub {
    my $paras = join (", ",@_);
    return qq#return ( { '@_' => [$paras] } );#;
  };


# - global scope
our $a="A";
our $b="";
my $c="C";

{ # - block scope
    
  my $b="B";

  sub enclosed {
    macro($a,$b,$c);
  }
  
  sub set_closure {
    $a .= "$_[0]";
    $b .= "$_[0]";
    $c .= "$_[0]";
  }
}

#$Macro::DB=1;

is( macro('$a','$b'),
    q[return ( { '$a $b' => [$a, $b] } );] ,
    "Macro returns");

is( enclosed(),
    q#return ( { 'A B C' => [A, B, C] } );# ,
    "Sub unexpanded");

# expand enclosed()
Macro::expand("enclosed");

is_deeply ( enclosed() ,
	    { '$a $b $c' => ['A', 'B', 'C'] },
	    "Sub expanded, Closure unchanged" );

# change closure
set_closure("*");

is_deeply ( enclosed() ,
	    { '$a $b $c' => ['A*', 'B*', 'C*'] },
	    "Sub expanded, Closure changed" );


done_testing();

  
