
# ------------------------------------------------------------
#  Same fringe
#   see http://rosettacode.org/wiki/Same_Fringe#Python
#   see http://www.perlmonks.org/index.pl/index.pl?node_id=1041479
# ------------------------------------------------------------


my $a = [1, 2, 3, 4, 5, 6, 7, 8];
my $b = [1, [[ 2, 3 ], [4, [5, [[6, 7], 8]]]]];
my $c = [[[[1, 2], 3], 4], 5, 6, 7, 8];

my $x = [1, 2, 3, 4, 5, 6, 7, 8, 9];
my $y = [0, 2, 3, 4, 5, 6, 7, 8];
my $z = [1, 2, [4, 3], 5, 6, 7, 8];

use Data::Dumper qw/Dumper/;
use Data::Dump;

print Dumper $c;

my @res;

sub walk {
    my ($node) = @_;
    my $type   = ref $node;
    #print "$type : $node \n";
    
    if ( $type eq "ARRAY") {
	walk($_) for @$node;
    } elsif ( ! $type ) {
	push @res, $node;
    }
}

@res=();
walk($c);
dd \@res;

@res=();
walk($b);
dd \@res;




