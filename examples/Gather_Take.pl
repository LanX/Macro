# !perl
use strict;
use warnings;


use feature 'state';

use lib '../lib';
use Macro;

my $counter;

#-----  Iterator source templates
my ($pre_body, $post_tmpl) = 
   (<<'__PRE_BODY__', <<'__POST_TMPL__');
{
    #-- closure vars
    my $_RESUME_;
    my $_ONERUN_=1;
   
    return $c_iter = sub {
        #-- Dispatcher
        goto $_RESUME_
            if defined $_RESUME_;
__PRE_BODY__
 
        #-- Exit
        $_RESUME_ = $_ONERUN_ ? "FINISHED": ();
       FINISHED:
        return;
    };
}
__POST_TMPL__


sub take :Macro{
  $counter++;
  return <<"__EXPANSION__";
    do {                         #start                    
      \$_RESUME_="_ENTRY${counter}_";
      return($_[0]);
     _ENTRY${counter}_:
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

#    print
  my $iter_source = qq{
$my_closure
$pre_body
#----- START BODY
$body
#----- END BODY
$post_tmpl
};

  my $c_iter;
  $c_iter = eval "$iter_source";
  Macro::_set_closed_over( $c_iter, $h_closed_over );
  return $c_iter;
}



# --------------------
#  test
# --------------------



my $outer="Closed over log: ";
my $iter = gather {
    for (state $i = 0; $i <= 20; ++$i) {
	take($i) if $i % 2;
	$outer .= "$i ";
    }
};


print $iter->(),"\n" for 1..5;
print $outer;


=head1 Concepts

=head2 Hygiene

The full expansion (Macros and Template) should under no cases
introduce new symbols conflicting with symbols within the scope of the
old sub to be expanded.

Symbols := lexical Variables, Labels and other identifiers

Various techniques are know in languages like LISP, such as
- Obfuscation,
- GenSym,
- using reserved namespaces,
- Convention: prepending full module-name to symbol

For details sie [wp://Macro Hygiene] in WP.


 =cut

{
    my OLD_closed_over;
    {
	my NEW_closed_over;

	sub NEW_SUB {
	    PreTEMPLATE;
	    OLD_BODY {
		# ... ;
		MACRO();
		# ... ;
	    };
	    PostTEMPLATE;
	}
    }
}

 =pod



Since the code of OLD_SUB is unknown to the macro-author, symbol-names
need to be indentified at expansion time to resolve the conflict.

This is done by altering the new symbol names with extra characters.

This is done by replacing a placeholder for each symbol indentifier in
the Source-Templates of Super-Macro and Macros _before_ introducing new code.

This is done by a simple global substitution =s///g= of source_templates pre eval, hence
PLACEHOLDERS MUST be chosen to be unique.

I.e. no substring in other parts of the template (like parts of a
subname) should be placeholder, this module doesn't attempt to parse Perl syntax.

Placeholders should be valid identifiers and well chosen to facilitate
later debugging.

We recommend using upercase letters surounded by one underscore. 


 =cut
{
    %PROTECT = {
	PRE  => ['<','_']
	POST => ['<','_']
	'$'  => qw/ SCALARNAME42 /,
	'%'  => qw/ HASH_NAME666/,
	':'  => qw/ LABLE /,
    }
}



 =pod

PRE and POST default to ['_','_']

=cut


