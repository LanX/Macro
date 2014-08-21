# !perl
use strict;
use warnings;


use feature 'state';

use lib '../lib';
use Macro;

my $counter;

#-----  Iterator source templates
my ($pre_tmpl, $post_tmpl) = 
   (<<'__PRE_TMPL__', <<'__POST_TMPL__');

{
    #-- closure vars
    my $RESUME;
    my $ONERUN=1;
   
    $c_iter = sub {
        #-- Dispatcher
        goto $RESUME
            if defined $RESUME;
__PRE_TMPL__
 
        #-- Exit
        $RESUME = $ONERUN ? "FINISHED": ();
       FINISHED:
        return;
    };
}
__POST_TMPL__


sub take :Macro{
  $counter++;
  return <<"__EXPANSION__";
    do {                         #start                    
      \$RESUME="ENTER_$counter";
      return($_[0]);
     ENTER_$counter:
    }                            #end
__EXPANSION__
}




#print Macro::is_macro(\&take);


sub gather (&) {
  my $c_block=shift;
  $counter=0;
  my $body = Macro::expand_coderef($c_block);
  my $h_closed_over = Macro::_closed_over($c_block);

  my $closure_vars    = join ",", keys %{ $h_closed_over };
  my $my_closure = "";
  $my_closure    = "my ( $closure_vars );" if $closure_vars;

  #  print
  my $iter_source = qq{
    $my_closure
    $pre_tmpl
    $body\n
    $post_tmpl
    };

  my $c_iter;
  eval "$iter_source";
  Macro::_set_closed_over( $c_iter, $h_closed_over );
  return $c_iter;
}

my $closed_over="Closed over log: ";
my $iter = gather {
    for (state $i = 0; $i <= 20; ++$i) {
	take($i) if $i % 2;
	$closed_over .= "$i ";
    }
};


print $iter->(),"\n" for 1..5;
print $closed_over;
