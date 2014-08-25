#!/usr/bin/perl
							    
use strict;
use warnings;

my $modulename="Macro";
chdir '/home/lanx/perl/talks/ExtendingSyntax/modules/Macro/lib/';


my $api_pod;
my $version;

sub grab (_;@)  {
  $api_pod .= "@_";
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

open my $modulepod, ">", "$modulename.pod"
  or die "'$modulename.pod' $!";

open my $pod_tmpl, "<", "$modulename.pod.tpl"
  or die "'$modulename.pod' $!";

while ( <$pod_tmpl> ) {
  s/§<([\w\s]+)>§/$insert{$1}/g;

  print $modulepod $_;
}

