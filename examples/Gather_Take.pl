# !perl -MCarp=verbose
use strict;
use warnings;


use feature 'state';

use lib '../lib';
use Macro;

my $counter;
my %protect = (
    '$' => [qw/ RESUME ONERUN USED /],
    ':' => [qw/ ENTRY1 /],
   );

#-----  Iterator source templates
my ($pre_body, $post_body) = 
   (<<'__PRE_BODY__', <<'__POST_BODY__');
{
    #-- closure vars
    my $_RESUME_;
    my $_ONERUN_=1;
   
    return sub {
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
__POST_BODY__


sub take :Macro{
  $counter++;
  my $expansion= <<"__EXPANSION__";
    do {                         #start                    
      \$_RESUME_="_ENTRY${counter}_";
      return($_[0]);
     _ENTRY${counter}_:
    }                            #end
__EXPANSION__

  my $safe_expansion = Macro::rename_symbols($expansion);
  return $safe_expansion;
  
}




#print Macro::is_macro(\&take);


sub gather (&) {
  my $c_block=shift;
  $counter=0;						    # reset closure

  # --- protect new symbols
  Macro::protect_symbols($c_block,%protect);

  # --- expand macros in block to code
  my $body = Macro::expand2text($c_block);

  # --- read lexical closure
  my $h_closed_over = Macro::_closed_over($c_block);

  # --- declare closure vars 
  my $closure_vars    = join ",", keys %{ $h_closed_over };
  my $my_closure = $closure_vars ? "my ( $closure_vars );" : "";

  # --- rename conflicting symbols
  my $pre_body  = Macro::rename_symbols($pre_body );
  my $post_body = Macro::rename_symbols($post_body);
  
  # --- reeval template
  print
  my $iter_source = qq{
$my_closure
$pre_body
#----- START BODY
$body
#----- END BODY
$post_body 
};

  my $c_iter = eval "$iter_source";

  # --- reconnect closure
  Macro::_set_closed_over( $c_iter, $h_closed_over );

  # --- reset protection
  Macro::unprotect_symbols();
  
  # --- return gather iterator
  return $c_iter;
}



# --------------------
#  test
# --------------------



my $outer="Closed over log: ";
my $_ONERUN_ = 'over';					    # Hygiene test
my $iter = gather {
    my $_RESUME_= 'inner'.$_ONERUN_;					    # Hygiene test
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


=head1  =state= vs =my if 0=

  DB<105> use feature 'state'; my $level=0; sub tst { state $a++; tst() unless $level++ }
 => 0

  DB<106> peek_sub \&tst
 => { "\$a" => \undef, "\$level" => \0 }

  DB<107> tst()
 => 1

  DB<108> peek_sub \&tst
 => { "\$a" => \2, "\$level" => \2 }

  DB<109> tst()
 => 2

  DB<110> peek_sub \&tst
 => { "\$a" => \3, "\$level" => \3 }

  DB<111> my $level=0; sub t2 { my $a if 0; $a++; t2() unless $level++ } => 0

  DB<112> peek_sub \&t2
 => { "\$a" => \undef, "\$level" => \0 }

  DB<113> t2
 => 1

  DB<114> peek_sub \&t2
 => { "\$a" => \1, "\$level" => \2 }

  DB<115> t2()
 => 2

  DB<116> peek_sub \&t2
 => { "\$a" => \2, "\$level" => \3 }

  DB<117> use feature 'state'; my $level=0; sub tst { state $a; $a++; tst() unless $level++ }
 => 0

  DB<118> tst()
 => 1

  DB<119> peek_sub \&tst 
 => { "\$a" => \2, "\$level" => \2 }

  DB<120> tst()
 => 2

  DB<121> peek_sub \&tst 
 => { "\$a" => \3, "\$level" => \3 }

  DB<122> peek_sub \&t2
 => { "\$a" => \2, "\$level" => \3 }

  DB<123> use feature 'state'; my $level=0; sub t1 { state $a; $a++; t1() unless $level++>1 ; print "$level:$a\n"}
 => 0

  DB<124> t1
3:3
3:3
3:3
 => 1

  DB<125> peek_sub \&t1
 => { "\$a" => \3, "\$level" => \3 }

  DB<126> use feature 'state'; my $level=0; sub t1 { state $a; $a++;  print "$level:$a\n"; t1() unless $level++>1 ;}
 => 0

  DB<127> peek_sub \&t1
 => { "\$a" => \undef, "\$level" => \0 }

  DB<128> t1
0:1
1:2
2:3
 => 1

  DB<129> use feature 'state'; my $level=0; sub t2 { my $a if 0; $a++;  print "$level:$a\n"; t2() unless $level++>1 ;}
 => 0

  DB<130> t1
3:4
 => 1

  DB<131> peek_sub \&t1
 => { "\$a" => \4, "\$level" => \4 }

  DB<132> peek_sub \&t2
 => { "\$a" => \undef, "\$level" => \0 }

  DB<133> t2
0:1
1:1
2:1
 => 1

  DB<134> use feature 'state'; my $level=0; sub t2 { my $a if 0; $a=$level;  print "$level:$a\n"; t2() unless $level++>1 ;}
 => 0

  DB<135> t2
0:0
1:1
2:2
 => 1

  DB<136> peek_sub \&t2
 => { "\$a" => \0, "\$level" => \3 }

  DB<137> use feature 'state'; my $level=0; sub t1 { state $a; $a=$level;  print "$level:$a\n"; t1() unless $level++>1 ;}
 => 0

  DB<138> t1
0:0
1:1
2:2
 => 1

  DB<139> peek_sub \&t1
 => { "\$a" => \2, "\$level" => \3 }

  DB<140> t1
3:3
 => 1

  DB<141> peek_sub \&t1
 => { "\$a" => \3, "\$level" => \4 }

  DB<142> t2
3:3
 => 1

  DB<143> peek_sub \&t2
 => { "\$a" => \3, "\$level" => \4 }

  DB<144> use feature 'state'; my $level=0; sub t2 { my $a if 0; $a=$level;  print "$level:$a\t"; t2() unless $level++>1 ; print "$level:$a\n"}
 => 0

  DB<145> t2
0:0	1:1	2:2	3:2
3:1
3:0
 => 1

  DB<146> use feature 'state'; my $level=0; sub t1 { my $a if 0; $a=$level;  print "$level:$a\t"; t1() unless $level++>1 ; print "$level:$a\n"}
 => 0

  DB<147> t1
0:0	1:1	2:2	3:2
3:1
3:0
 => 1

  DB<148> use feature 'state'; my $level=0; sub t1 { state $a; $a=$level;  print "$level:$a\t"; t1() unless $level++>1 ; print "$level:$a\n"}
 => 0

  DB<149> t1
0:0	1:1	2:2	3:2
3:2
3:2
 => 1

  DB<150> peek_sub \&t2
 => { "\$a" => \0, "\$level" => \3 }

  DB<151> peek_sub \&t1
 => { "\$a" => \2, "\$level" => \3 }

  DB<152> my $tr; $tr =sub { my $x=3; peek_sub $tr }
 => sub { "???" }

  DB<153> $tr->()
Undefined subroutine &main:: called at (eval 123)[multi_perl5db.pl:644] line 2.

  DB<154> my $tr; $tr =sub { my $x=3; print $x }
 => sub { "???" }

  DB<155> $tr->()
Undefined subroutine &main:: called at (eval 127)[multi_perl5db.pl:644] line 2.

  DB<156> my $tr; $tr =sub { my $x=3; peek_sub $tr }; $tr->()
 => { "\$tr" => \sub { "???" }, "\$x" => \3 }

  DB<157> my $tr; $tr =sub { my $x=3; { my $x=42; peek_sub $tr} }; $tr->()
 => { "\$tr" => \sub { "???" }, "\$x" => \42 }

  DB<158> use feature 'state'; my $tr2; $tr2 =sub { state $x=3; { state $x=42; peek_sub $tr} }; $tr->()
Undefined subroutine &main:: called at (eval 133)[multi_perl5db.pl:644] line 2.

  DB<159> use feature 'state'; my $tr2; $tr2 =sub { state $x=3; { state $x=42; peek_sub $tr2} }; $tr->()
Undefined subroutine &main:: called at (eval 135)[multi_perl5db.pl:644] line 2.

  DB<160> use feature 'state'; my $tr2; $tr2 =sub { state $x=3; { state $x=42; peek_sub $tr2} }; $tr2->()
 => { "\$tr2" => \sub { "???" }, "\$x" => \42 }

  DB<161> use feature 'state'; my $tr2; $tr2 =sub { state $x=3; { state $x=42; peek_sub $tr2} ; $x}; $tr2->()
 => 3

    161: use feature 'state'; my $tr2; $tr2 =sub { state $x=3; { state $x=42; peek_sub $tr2} ; $x}; $tr2->()
    160: use feature 'state'; my $tr2; $tr2 =sub { state $x=3; { state $x=42; peek_sub $tr2} }; $tr2->()
    159: use feature 'state'; my $tr2; $tr2 =sub { state $x=3; { state $x=42; peek_sub $tr2} }; $tr->()
    158: use feature 'state'; my $tr2; $tr2 =sub { state $x=3; { state $x=42; peek_sub $tr} }; $tr->()
    157: my $tr; $tr =sub { my $x=3; { my $x=42; peek_sub $tr} }; $tr->()
    156: my $tr; $tr =sub { my $x=3; peek_sub $tr }; $tr->()
    155: $tr->()
    154: my $tr; $tr =sub { my $x=3; print $x }
    153: $tr->()
    152: my $tr; $tr =sub { my $x=3; peek_sub $tr }
    151: peek_sub \&t1
    150: peek_sub \&t2
    149: t1
    148: use feature 'state'; my $level=0; sub t1 { state $a; $a=$level;  print "$level:$a\t"; t1() unless $level++>1 ; print "$level:$a\n"}
    147: t1
    146: use feature 'state'; my $level=0; sub t1 { my $a if 0; $a=$level;  print "$level:$a\t"; t1() unless $level++>1 ; print "$level:$a\n"}
    145: t2
    144: use feature 'state'; my $level=0; sub t2 { my $a if 0; $a=$level;  print "$level:$a\t"; t2() unless $level++>1 ; print "$level:$a\n"}
    143: peek_sub \&t2
    142: t2
    141: peek_sub \&t1
    140: t1
    139: peek_sub \&t1
    138: t1
    137: use feature 'state'; my $level=0; sub t1 { state $a; $a=$level;  print "$level:$a\n"; t1() unless $level++>1 ;}
    136: peek_sub \&t2
    135: t2
    134: use feature 'state'; my $level=0; sub t2 { my $a if 0; $a=$level;  print "$level:$a\n"; t2() unless $level++>1 ;}
    133: t2
    132: peek_sub \&t2
    131: peek_sub \&t1
    130: t1
    129: use feature 'state'; my $level=0; sub t2 { my $a if 0; $a++;  print "$level:$a\n"; t2() unless $level++>1 ;}
    128: t1
    127: peek_sub \&t1
    126: use feature 'state'; my $level=0; sub t1 { state $a; $a++;  print "$level:$a\n"; t1() unless $level++>1 ;}
    125: peek_sub \&t1
    124: t1
    123: use feature 'state'; my $level=0; sub t1 { state $a; $a++; t1() unless $level++>1 ; print "$level:$a\n"}
    122: peek_sub \&t2
    121: peek_sub \&tst 
    120: tst()
    119: peek_sub \&tst 
    118: tst()
    117: use feature 'state'; my $level=0; sub tst { state $a; $a++; tst() unless $level++ }

=cut
