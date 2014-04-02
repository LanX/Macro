package Macro;

use strict;
use warnings;
use Carp;
use Data::Dumper;

use B::Deparse;
use B::Concise qw(set_style add_callback);
use PadWalker;



# ----------------------------------------
#  Debugging Helpers
# ----------------------------------------

our $DB=1;						    # global Debug Flag

sub say {
  local $,="\t";
  print "@_\n"
}

sub dbout {
  return unless $DB;
  local $|=1;
#  say ("DB:",@_);
  Test::More::diag("DB: @_\n") if exists &Test::More::diag;
}



# ----------------------------------------
#  Modulino Testing
# ----------------------------------------

#  run tests if called as script
print `prove -b "../t"` unless caller();


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
      dbout "entersub_text: $entersub_text";

      #- decompose call_text 
      my ( $fullname, $args ) = ( $entersub_text =~ m/ ([:\w]+) \( (.*) \) /x );
      dbout "name: $fullname, args: $args";

      my $current_package = $self->{'curstash'};
      dbout "$current_package";

      my $c_macro = ref_macro ( $fullname, $current_package );

      #- ignore normal subs
      return $entersub_text unless $c_macro; 
      
      #- split args to strings
      my @args = split /, /, $args;	     # a bit dirty
      # TODO: analyze "$self->deparse($_, 6), @exprs)"

      # return macro expansion text
      return $c_macro->(@args);
    };


=head2 expand_coderef

Returns deparse_coderef(@args) with activated macros expansion.

=cut

  
  sub expand_coderef {

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

Return deparsed code for coderef

=cut

sub deparse_coderef {
  my ($coderef) = @_;
  
  my $deparse_obj    = B::Deparse->new( "-p", "-q");
  return $deparse_obj->coderef2text( $coderef );
}



=head2 expand_sub SUBNAME

Replaces body of named sub with expanded code.

Returns new body text.

=cut

sub expand_sub {
  my ($subname) = @_;

  #local $DB=1;
  
  $subname = _fullname( $subname, (caller)[0]);
  

  my $c_old = \&{$subname};

  my $h_closed_over = _closed_over($c_old);

  my $newbody = expand_coderef($c_old);
  dbout "body: $newbody";
  
  #- compile new body
  #  my $code = eval "sub $newbody";

  my $c_new = body2coderef ($newbody ,
			    package  => (caller)[0] ,
			    closed_over => $h_closed_over,
			   );

  my $codetype = ref $c_new;

  # - replace code
  {
    no strict qw/refs/;
    no warnings 'redefine';
    *{$subname} = $c_new;
  }

  # TODO WHAT???
#   unless ($c_new and $codetype eq "CODE") {
#     dbout "\ntype='$codetype' \nnewbody='$newbody' ";
# #    die "Eval expansion failed!" unless $c_new and ref $c_new eq "Code";
#   }

  #-  Reassign closed over variables 
  _set_closed_over( $c_new, $h_closed_over );

  # - ??? gute idee?
  return $newbody; 
}


=head2 body2coderef (BODYTEXT, 'closed_over' => href, 'package' => string)

Evals body-code within context of package and closed over
lexicals.

Returns coderef.

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


# ----------------------------------------
#  Macro helpers
# ----------------------------------------

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

sub Macro {
  my ( $package, $symbol, $referent, $attr, $data, $phase, $filename,
      $linenum ) = @_;
#  dd \@_;

  bless $referent, "Macro";

}



1; 


__END__





