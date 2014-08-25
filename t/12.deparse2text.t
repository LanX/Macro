#!perl 
use strict;
use warnings;

use Test::More;

use lib '../lib';
use Macro;


my $body =q#{
    use warnings;
    use strict 'refs';
    print('This is a sub!');
}#;

my $c_sub;
{

  $c_sub = Macro::body2coderef($body, package => 'main');
}

  



is( Macro::deparse2text($c_sub),  $body, "Deparse works");

done_testing();






