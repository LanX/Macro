#!perl 
use Test::More;

use lib '../lib';
use Macro;


Macro::protect_symbols(
    	PRE  => ['<','_'],
	POST => ['>','_'],
	'$'  => [qw/ SCALAR42 SUPER/],
	'%'  => [qw/ HASH666 /],
	'@'  => [qw/ ARRAY123 /],
	':'  => [qw/ LABLE /],
       );

my $tmpl = '$<SCALAR42>, %<HASH666>, @<ARRAY123>, $<SUPER>';



my $_SUPER_=5;

my $c_old_sub = sub {
    my $_SCALAR42_a_ = $_SUPER_;
    my $_SCALAR42_  ;
    my $SCALAR42  ;
    my %_HASH666_  =();
    my @_ARRAY123_ =();
};

use Data::Dump;
# dd Macro::_peek_sub($c_old_sub);


dd Macro::rename_symbols($tmpl,$c_old_sub);      

is (
    Macro::rename_symbols($tmpl,$c_old_sub),
    "\$_SCALAR42_b_, %_HASH666_a_, \@_ARRAY123_a_, \$_SUPER_a_",
    "Symbol protection!"
   );

done_testing();

__END__

# --------------------

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




  
