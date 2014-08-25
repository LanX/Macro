package Macro;

our $VERSION="0.0.5-03";

# ----------------------------------------
#  Modulino Testing
# ----------------------------------------

#  run tests if called as script
print `prove -b "../t"` unless caller();
#print `cd ..;make test` unless caller();

use strict;
use warnings;
use Carp;
use Data::Dumper;

use B::Deparse;
use B::Concise qw(set_style add_callback);
use PadWalker;

our $DEBUG=0;						    # global Debug Flag


# ----------------------------------------
#  Interface
# ----------------------------------------


{
  my $c_pp_entersub_orig;


  my $c_pp_entersub_wrapper = sub
    {
      my ($self, $op, $cx ) = @_;
  
      #- original text of sub-call
      my $entersub_text = $c_pp_entersub_orig->(@_);
      dbout( "entersub_text: $entersub_text" );

      #- decompose call_text 
      my ( $fullname, $args ) = ( $entersub_text =~ m/ ([:\w]+) \( (.*) \) /x );
      dbout( "name: $fullname, args: $args" );

      my $current_package = $self->{'curstash'};
      dbout( "$current_package" );

      my $c_macro = ref_macro ( $fullname, $current_package );

      #- ignore normal subs
      return $entersub_text unless $c_macro; 
      
      #- split args to strings
      my @args = split /, /, $args;	     # a bit dirty
      # TODO: analyze "$self->deparse($_, 6), @exprs)"

      # return macro expansion text
      return $c_macro->(@args);
    };


=head2 expand2text CODEREF  

=> expanded CODE

Expands macros in deparsed CODEREF


CAUTION: Only one level expansion implemented yet.

Arguments tunneld to deparse_coderef(@_)

=for TODOX
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
        
    #- save original
    $c_pp_entersub_orig	       = \&B::Deparse::pp_entersub;

    # - install wrapper
    no warnings "redefine";
    local *B::Deparse::pp_entersub = $c_pp_entersub_wrapper;

    # - return deparsed text
    return deparse_coderef(@_)
  }

}



=head2 deparse_coderef

=> deparsed CODE

Return deparsed code for coderef w/o expansion

=cut

sub deparse_coderef {
  my ($coderef) = @_;
  
  my $deparse_obj    = B::Deparse->new( "-q","-p","-si4");
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

Handling of Macros

=cut

=head2 ref_macro NAME, CURRENT_PACKAGE

Return reference of named macro.

Return undef if not a macro

$current_package is ignored if $name is fully quallified

=cut


sub ref_macro {
  my ( $name, $current_package ) =@_;

  # #- fully qualified subname
  # my $fullname = $name;
  # if ( $name !~ /::/ ) {
  #   $fullname = $current_package . "::" . $name;
  # }

  my $fullname = _fullname( $name, $current_package );
  
  my $coderef = \&{$fullname};

  return is_macro($coderef);

}


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
  
  bless $block, "Macro";
 
  *{$fullname} = $block;
} 



=head2 is_macro CODEREF

Is true (returns CODEREF) if pointing to a macro.

Otherwise false.

=cut


sub is_macro {
  my ($coderef) = @_;

  return $coderef
    if ref $coderef eq "Macro";
  return;
}




# ----------------------------------------
#  Handling Closure Variables
# ----------------------------------------


# Wrappers for PadWalker subs for inspection

sub _closed_over {
  return PadWalker::closed_over(@_);
}


sub _set_closed_over {
  return PadWalker::set_closed_over(@_);
}



# ----------------------------------------
#  Attributes
#  http://www.perlmonks.org/index.pl?node_id=1036619
# ----------------------------------------

use Attribute::Handlers;

sub import {
  my $src_pkg=__PACKAGE__;
  my $dest_pkg = (caller)[0];
  
  my $import = "sub ${dest_pkg}::Macro : ATTR(CODE) { goto \&${src_pkg}::Macro }";
  eval $import;
}

=head2 Macro

Attribute to mark subs as macros.

=cut

sub Macro {
  my ( $package, $symbol, $referent, $attr, $data, $phase, $filename,
      $linenum ) = @_;
#  dd \@_;

  bless $referent, "Macro";

}


# ----------------------------------------
#  Debugging Helpers
# ----------------------------------------

=head1 Debugging Helpers


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





