use strict;
use warnings;

my $modulename="Macro";

my $api_pod;
sub grab (_;@)  {
  $api_pod .= "@_";
}

#--------------------------------------------------
#  grab inlined pod from .pm
#--------------------------------------------------

open my $module, "<", "$modulename.pm"
  or die "'$modulename.pm' $!";

while  (<$module>) {
  if ( /^=head2/ .. /^=cut/ ) {
    grab;
  }

  if (/^=cut/ ) {
    grab "\n\n";
  }
}

#print $pod;

close $module;

my %insert;

$insert{VERSION}= '0.0.2';
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

