package Macro;

our $VERSION="0.0.6-05";

# ----------------------------------------
#  Modulino Testing
# ----------------------------------------

#  run test suite if module is run directly as script
print `prove -b "../t"` unless caller();
#print `cd ..;make test` unless caller();

use strict;
use warnings;
use B::Deparse;
use PadWalker;
use Attribute::Handlers;
use Carp;



our $DEBUG=0;						    # global Debug Flag

# ----------------------------------------
#  Exports
# ----------------------------------------


sub import {
  _import_attributes( __PACKAGE__ , (caller)[0] );
}

# ----------------------------------------
#  Interface
# ----------------------------------------


{
    package Macro::B_Deparse;

    use base 'B::Deparse';


    sub pp_entersub {
	  my $self = shift;
  
	  #- original text of sub-call
	  my $entersub_text = $self->SUPER::pp_entersub(@_);
	  Macro::dbout( "entersub_text: $entersub_text" );

	  #- decompose call_text 
	  my ( $fullname, $args ) = ( $entersub_text =~ m/ ([:\w]+) \( (.*) \) /x );
	  Macro::dbout( "name: $fullname, args: $args" );

	  #- subname may not be fully quallyfied
	  my $current_package = $self->{'curstash'};
	  Macro::dbout( "$current_package" );

	  my $c_macro = Macro::ref_macro ( $fullname, $current_package );

	  #- ignore normal subs
	  return $entersub_text unless $c_macro; 
      
	  #- split args to strings
	  my @args = split /, /, $args;			 # a bit dirty
	  # TODO: analyze "$self->deparse($_, 6), @exprs)"

	  # return macro expansion text
	  return $c_macro->(@args);
      }
}

=head2 expand2text CODEREF  

=> expanded CODE

Expands macros while deparsing CODEREF


CAUTION: Only one level expansion implemented yet.

Arguments tunneld to deparse2text(@_)

=for TODO
 ** ??? rename?
  -  expand_sub2source
  -  expand_source OBJ
  -  expand_deparse
   OBJ = coderef/subname
         sub_body?
         glob? *func
  - expand2txt sub, exp-level
  - deparse    sub, exp-level


=cut

  

sub expand2text {

    # - return deparsed text
    return deparse2text(@_)
}


=head2 deparse2text

=> deparsed CODE

Return deparsed code for coderef w/o expansion

=cut

sub deparse2text {
  my ($coderef) = @_;
  
  my $deparse_obj    = Macro::B_Deparse->new( "-q","-p","-si4");
  return $deparse_obj->coderef2text( $coderef );
}



=head2 expand SUB

=> new CODEREF

Evals text expansion of SUB = [CODEREF|SUBNAME]

=head3 expand SUBNAME

Side effect: Installs new CODEREF into SUBNAME's package.

(pass coderef =\&SUBNAME= otherwise)

SUBNAME is a string like "Package::func" or "func".

If not fully qualified current package of caller is chosen

=head3 expand CODEREF

No side effect!




=for TODO
* Glob passing?
 - is package known?
* ??? rename?
-  expand sub, exp-level, %opt


=cut

sub expand {
  my ($sub,%opt) = @_;

  #local $DEBUG=1;
  my ($c_old, $subname);
  
  # --- extract old coderef
  my $subtype = ref $sub;
  if ($subtype eq "CODE") {
      $c_old = $sub;
  }
  elsif (! $subtype) {
      $subname = _fullname( $sub, (caller)[0]);
      $c_old = \&{$subname};
  }

  my $h_closed_over = _closed_over($c_old);

  my $newbody = expand2text($c_old);

  # # - wrap pre and post code
  # {
  #     no warnings 'uninitialized';
  #     $newbody = $opt{pre} . "\n$newbody\n". $opt{post};
  # }
  
  dbout( "body: $newbody" );
  
  #- compile new body to sub
  #  my $code = eval "sub $newbody";

  my $c_new = body2coderef ($newbody ,
			    package  => (caller)[0] , 	    # ??? package from qualified subname?
			    closed_over => $h_closed_over,
			   );

  # - reinstall named sub
  if ($subname and !$subtype)  {
    no strict qw/refs/;
    no warnings 'redefine';
    *{$subname} = $c_new;
  }


  #-  Reassign closed over variables 
  _set_closed_over( $c_new, $h_closed_over );

  #- return new coderef
  # ??? extra info like old/new sourcetext?
  #     - blessing code-ref?
  #     - returning list if wantarray?
  return $c_new; 
}


=head2 body2coderef (BODYTEXT, 'closed_over' => href, 'package' => string)

Evals body-code within context of package and closed over
lexicals.

Returns coderef.

* ??? rename?
 - eval_body
 - reeval_sub
=cut

sub body2coderef {
  my ( $t_body, %opt ) = @_;

  $opt{package} //= (caller)[0];  # default caller's package

  my $closure_vars    = join ",", keys %{ $opt{closed_over} };
  my $my_closure = "";
  $my_closure    = "my ( $closure_vars )" if $closure_vars;
  

  
  my $c_sub;
  {
  #  no strict;
  $c_sub = eval <<"__CODE__";
    package $opt{package};
    $my_closure;
    sub $t_body
__CODE__
}

  
  # TODO Errormessage
  if ($@ or !$c_sub) {
    warn <<"__ERR__";
Couldn't eval body to coderef
$@
------
$t_body
------
__ERR__
  }
  
  return $c_sub;
}

# ----------------------------------------
#  Macro Management
# ----------------------------------------

=head1 Macro Management


Macros are just ordenary subroutines and follow the same call-syntax.

But at expansion time they need to be distiguished from non-macros.

The following routines are an abstraction layer to facilitate
experimenting different approaches.

Currently we just bless their coderef into a special package (ATM "Macro").

(This is likely to change in the future, never rely on this)

NB: Exported macros keep being macros.

TODO: enter explanation from Perl6

=cut


=head2 mark_macro CODEREF

=> blessed CODEREF

Marks coderef as macro.

=cut

my $MACROCLASS="Macro";

sub mark_macro {
  my ($coderef) = @_;

  bless $coderef, $MACROCLASS;
}


=head2 is_macro CODEREF

Is true (returns CODEREF) if pointing to a macro.

Otherwise false.

=cut


sub is_macro {
  my ($coderef) = @_;

  return $coderef
    if ref $coderef eq $MACROCLASS;
  return;
}



=head2 ref_macro SUBNAME, CURRENT_PACKAGE

Return reference of named macro.

Return undef if not a macro

$current_package is ignored if $name is fully quallified

=cut


sub ref_macro {
  my ( $name, $current_package ) =@_;

  my $fullname = _fullname( $name, $current_package );
  
  my $coderef = \&{$fullname};

  return is_macro($coderef);

}

=head2 _fullname SUBNAME, PCKG

=> full SUBNAME

Returns "PCKG::NAME" if NAME not already fully qualified

=cut


sub _fullname {
  my ( $name, $package ) =@_;

  #- fully qualified subname
  my $fullname = $name;
  if ( $name !~ /::/ ) {
    $fullname = $package . "::" . $name;
  }
  return $fullname;
}



=head2 def_macro NAME, BLOCK

Installs C<sub NAME {BLOCK}> and marks it as macro.

NAME defaults to local package if unqualified.

=cut


sub def_macro {
  my ( $name, $block) = @_;
  
  my $pkg = (caller)[0];
  no strict 'refs';
  
  my $fullname = _fullname( $name, $pkg);
  
  mark_macro($block);
 
  *{$fullname} = $block;
} 



# ============================================================

=head1 Hygienic Macros

The full expansion (Macros and Template) should under no cases
introduce new symbols conflicting with symbols within the scope of the
old sub to be expanded.

Symbols := lexical Variables, Labels and other identifiers

Various techniques are know in languages like LISP, such as
- Obfuscation,
- GenSym,
- using reserved namespaces,
- Convention: prepending full module-name to symbol

For details sie [wp://Macro Hygiene] http://en.wikipedia.org/wiki/Hygienic_macro#Strategies_used_in_languages_that_lack_hygienic_macros
 in WP.

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

We recommend using upercase letters surounded by one underscore. (???)

=cut

{
    my %transform;
    my $h_oldsymbols;
    
    #  TODO: check args
    sub protect_symbols {
	my ($c_oldsub,%args) = @_;

	my %protect = (
	    PRE  => ['_','_'], # defaults
	    POST => ['_','_'],
	    %args,	       # new
	   );
	#use Data::Dump;
	#dd \%protect;
	
	# --- get old lexicals
	$h_oldsymbols = _peek_sub($c_oldsub);

	# --- placeholder tags
	my ($pre_old,$pre_new)   = @{$protect{PRE}};
	my ($post_old,$post_new) = @{$protect{POST}};
	
	
	while ( my ($sigil,$a_symbol) = each %protect) {
	    next unless $sigil =~ /[@%\$]/;
	    
	    for my $symbol (@$a_symbol) {
		dbout ($sigil,$symbol);

		my $suffix = "a";
		my $old  = $pre_old . $symbol . $post_old;
		my $new  = $pre_new . $symbol . $post_new;
		my $new0 = $new;
		while ( exists $h_oldsymbols->{$sigil.$new} ) {
		    $new = $new0 . $suffix++ . $post_new;
		}
		$transform{$old} = $new
		  if $old ne $new;	
	    }  
	} 


    }
    
    sub unprotect_symbols {
	%transform=();
    }
    
    sub rename_symbols {
	my ($tmpl)=@_;

	# symbols can't be surounded by other identifier characters
	my $re_identifier = qr/[0-9a-zA-Z_]/; 		     
	
	if (%transform) {
	    my $or_regex =
	      join "|", 				    # regex or
		map {quotemeta}				    # escape
		  sort { length($b) <=> length($a) }	    # substring last
		    keys %transform;

	    $tmpl =~ s/   (?<! $re_identifier )  # must not precede
			  (
			      $or_regex
			  )
			  (?!  $re_identifier )  # must not follow 
		      /$transform{$1}/xg;
	}
	return $tmpl; #,\%transform; 
    }
    

}


  

# ----------------------------------------
#  Handling Closure Variables
# ----------------------------------------
=head1 Handling Closure Variables

Reevaluating deparsed subroutines disconnects closed over
variables from the original scope.

PadWalker is used for retrieving and redirecting those variables.

But this dependency to a non-core XS-module is not very fortunate.

The following subs are a direct wrappers to the original
routines. Like that we facilitate:

  1. A potential future migration to a non-XS solution.

  2. More detailed documentation of manipulating Perl's guts.

=head2 _closed_over


=head2 _set_closed_over


=head2 _peek_sub


=cut

sub _closed_over {
  return PadWalker::closed_over(@_);
}


sub _set_closed_over {
  return PadWalker::set_closed_over(@_);
}

sub _peek_sub {
  return PadWalker::peek_sub(@_);
}

# ----------------------------------------
#  Attributes
# ----------------------------------------

=head1 Attribute Handlers

Syntactic sugar to facilitate definition and expansion of macros.

=cut
  


=head2 _import_attributes SRC_PKG, DEST_PKG

We try to avoid global pollution of UNIVERSAL with our handlers.

We use a little hack to install them locally into the importing
package.

For a more detailed discussion, see
  L<http://www.perlmonks.org/index.pl?node_id=1036619>

Future: Might be refactored into separate module.

=cut



sub _import_attributes {
    my ($src_pkg, $dest_pkg) = @_;
    
    my $import = "sub ${dest_pkg}::Macro : ATTR(CODE) { goto \&${src_pkg}::Macro }";
    eval $import;

}


=head2 Macro

Attribute to mark subs as macros.

  sub bla :Macro { ... }

For details see mark_macro().
=cut

sub Macro {
  my ( $package, $symbol, $referent, $attr, $data, $phase, $filename,
      $linenum ) = @_;

  mark_macro($referent);

}


# ----------------------------------------
#  Debugging Helpers
# ----------------------------------------

=head1 Debugging Helpers

Little internal helpers for testing, development and debugging.

(Should maybe be refactored into external module)

=head2 say

say for backwards-compatibility.

=cut

sub say {
  local $,="\t";
  print "@_\n"
}

=head2 dbout

debug output, controled by global $DEBUG

=cut

sub dbout {
  return unless $DEBUG;
  #local $|=1;
  #  say ("DB:",@_);
  my @caller=(caller(0))[0..2];
  Test::More::diag("DB $DEBUG: @_\n") if exists &Test::More::diag;
}






1; 


__END__





