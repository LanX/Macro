#!/usr/bin/perl
use strict;
use warnings;

my $modulename="Macro";
chdir '/home/lanx/perl/talks/ExtendingSyntax/modules/Macro/lib/';


my $api_pod;
my $version;

sub grab (_;@)  {
    my $line = "@_";
    return if ($line =~/^=for TODO/ .. $line =~ /^\s*$/); # ignore TODO blocks
    $api_pod .= $line;
}

#--------------------------------------------------
#  grab inlined pod from .pm
#--------------------------------------------------

open my $module, "<", "$modulename.pm"
  or die "'$modulename.pm' $!";

while  (<$module>) {
    if ( / our \s* \$VERSION \s* = \s* (['"]?)([-0-9.]+)\1 \s*; /x ) {
	warn "too many versionstrings" if $version;
	$version =$2;
    }
    
      

  if ( /^=head[123]/ .. /^=cut/ ) {
    grab;
  }

  if (/^=cut/ ) {
    grab "\n\n";
  }
}

#print $pod;

close $module;

my %insert;
$insert{VERSION}= $version;
$insert{API_POD}= $api_pod;


#--------------------------------------------------
#  include API-doc to .pod
#--------------------------------------------------

my $modulepod;
my $readme;
my $readme_flag;


open my $fh_pod_tmpl, "<", "$modulename.pod.tpl"
  or die "'$modulename.pod' $!";

my $author_to_fill_in;

while ( my $line = <$fh_pod_tmpl> ) {
    $line =~ s/§<([\w\s]+)>§/$insert{$1}/g;
    if ($line =~/^=for\s+author_to_fill_in/ .. $line =~ /^\s*$/) {
	$author_to_fill_in.= "$modulename.pod.tpl:$.: $line";
	next;				   # ignore  author_to_fill_in
    }

    if ($line =~/^=for\s+readme_(start|stop)/ .. $line =~ /^\s*$/) {
	if ($1) {
	    $readme_flag = $1;
	} else {
	    $readme.=$line;
	}
	next;
    }
    
    if ( ($readme_flag eq "start") .. ($readme_flag eq "stop") ){
	$readme.=$line;
    }
    
    $modulepod .= $line;
}

open my $fh_modulepod, ">", "$modulename.pod"
  or die "'$modulename.pod' $!";
print $fh_modulepod $modulepod;
close $fh_modulepod;

open my $fh, ">", "../README.pod"
  or die "'$modulename.pod' $!";
print $fh $readme;
close $fh;



warn $author_to_fill_in if $author_to_fill_in;
