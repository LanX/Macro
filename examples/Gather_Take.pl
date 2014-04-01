# !perl
use lib '../lib';

use Macro;

my $counter;

my ($pre_tmpl, $post_tmpl) = 
   (<<'__PRE_TMPL__', <<'__POST_TMPL__');

{
    #-- Control
    my $RESUME;
    my $ONERUN=1;
   
    #-- Closure vars
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
  my $closed_over = Macro::_closed_over($c_block);
  


    
  my $goto_source = qq{
    $pre_tmpl
    $body\n
    $post_tmpl
    };

  # my $c_iter;
  # eval "$goto_source"; 
  # return $c_iter;
}

print gather {
    for (my $i = 0; $i <= 20; ++$i) {
         take($i) if $i % 2;
    }
}
