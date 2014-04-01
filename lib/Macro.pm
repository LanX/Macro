package Macro;

use strict;
use warnings;
use Carp;
use Data::Dumper;
use Data::Dump;

use B::Deparse;
use B::Concise qw(set_style add_callback);
use PadWalker;



# ----------------------------------------
#  Helpers
# ----------------------------------------

our $DB=1;

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
#  Testing
# ----------------------------------------

#  run tests if called as script
#do "/home/lanx/bin/prove_pm" unless caller();
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


sub deparse_coderef {
  my ($coderef) = @_;
  
  my $deparse_obj    = B::Deparse->new( "-p", "-q");
  return $deparse_obj->coderef2text( $coderef );
}

=head2 expand_sub

expands all macros in sub
replaces body with evaluation
returns new body 

=cut

sub expand_sub {
  my ($subname) = @_;

  #local $DB=1;
  
  # TODO _fullname?
  $subname = _fullname( $subname, (caller)[0]);
  

  my $c_old = \&{$subname};

  my $h_closed_over = _closed_over($c_old);

  my $newbody = expand_coderef($c_old);
  dbout "body: $newbody";
  
  #- compile new body
  #  my $code = eval "sub $newbody";
  my $c_new = body2coderef( $newbody ,
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
  
#   unless ($c_new and $codetype eq "CODE") {
#     dbout "\ntype='$codetype' \nnewbody='$newbody' ";
# #    die "Eval expansion failed!" unless $c_new and ref $c_new eq "Code";
#   }

  #-  Reassign closed over variables 
  _set_closed_over( $c_new, $h_closed_over );

  # - ??? gute idee?
  return $newbody; 
}



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

=head2 def_macro

define macro

=cut


sub def_macro {
  my ( $name, $block) = @_;
  
  my $pkg = (caller)[0];
  no strict 'refs';
  
  my $fullname = _fullname( $name, $pkg);
  
  bless $block, "Macro";
 
  *{$fullname} = $block;
} 



sub is_macro {
  my ($coderef) = @_;

  return $coderef
    if ref $coderef eq "Macro";
  return;
}




# ----------------------------------------
#  Handling Closure Variables
# ----------------------------------------

# Wrappers for PadWalker inspection

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


=head1 NAME

Macro - Expanding code with LISP like macros


=head1 VERSION

This document describes Macro version 0.0.1


=head1 SYNOPSIS

    use Macro;

=for author_to_fill_in
    Brief code example(s) here showing commonest usage(s).
    This section will be as far as many users bother reading
    so make it as educational and exeplary as possible.

=head1 DESCRIPTION

=for author_to_fill_in
    Write a full description of the module and its features here.
    Use subsections (=head2, =head3) as appropriate.


=head1 INTERFACE


=for author_to_fill_in
    Write a separate section listing the public components of the modules
    interface. These normally consist of either subroutines that may be
    exported, or methods that may be called on objects belonging to the
    classes provided by the module.

=head2 expand_coderef

deparse coderef with expanded macros

=head2 ref_macro($name, $current_package )

return reference of macroname
undef if not a macro

$current_package is ignored if $name is fully quallified

=head2 deparse_coderef

return deparsed text for body of coderef


=head2 is_macro($coderef)

returns coderef if it's a macro
returns undef otherwise

Currently only checking if blessed

=head2 dbout
  internal

=head2 say

=head1 DIAGNOSTICS

=for author_to_fill_in
    List every single error and warning message that the module can
    generate (even the ones that will ''never happen''), with a full
    explanation of each problem, one or more likely causes, and any
    suggested remedies.

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for author_to_fill_in
    A full explanation of any configuration system(s) used by the
    module, including the names and locations of any configuration
    files, and the meaning of any environment variables or properties
    that can be set. These descriptions must also include details of any
    configuration language used.

Macro requires no configuration files or environment variables.


=head1 DEPENDENCIES

=for author_to_fill_in
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

None.


=head1 INCOMPATIBILITIES

=for author_to_fill_in
    A list of any modules that this module cannot be used in conjunction
    with. This may be due to name conflicts in the interface, or
    competition for system or program resources, or due to internal
    limitations of Perl (for example, many modules that use source code
    filters are mutually incompatible).

None reported.


=head1 BUGS AND LIMITATIONS

=for author_to_fill_in
    A list of known problems with the module, together with some
    indication Whether they are likely to be fixed in an upcoming
    release. Also a list of restrictions on the features the module
    does provide: data types that cannot be handled, performance issues
    and the circumstances in which they may arise, practical
    limitations on the size of data sets, special cases that are not
    (yet) handled, etc.

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-Macro@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.


=head1 AUTHOR

Rolf Michael Langsdorf  C<< lanx@cpan.org >>


=head1 LICENSE AND COPYRIGHT

Copyright (c) 2014, Rolf Michael Langsdorf C<< lanx@cpan.org >>.
All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See C<perldoc perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE ''AS IS'' WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.




