#!perl 
use Test::More;

use lib '../lib';
use Macro;

Macro::def_macro invert 
  => sub {
    my @paras= reverse @_;
    qq[return 'Reversed: @paras']
  };

my $parent = sub
  {
    invert(1,2,3)
  };


my $got = Macro::expand2text($parent);
$expected =q[{
    return 'Reversed: 3 2 1';
}];

is( $got, $expected, "expand all macros in code" );

done_testing();


__END__

# diag ref \&macro;

# diag tst();

#diag "is_macro: ", !! Macro::is_macro(\&main::tst);




#diag Macro::deparse_coderef(\&tst);
$Macro::DB=0;

#diag "output macro: ",macro2(1,2,3);

#diag "deparse: ",  Macro::deparse_coderef(\&macro2);
