
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME            => 'Macro',
    AUTHOR          => 'Rolf Michael Langsdorf <lanx@cpan.org>',
    VERSION_FROM    => 'lib/Macro.pm',
    ABSTRACT_FROM   => 'lib/Macro.pod.tpl',
    PL_FILES        => {},
    MIN_PERL_VERSION => '5.010000', # for examples/Gather_Take.pl, otherwise 5.6.0
    PREREQ_PM    => {
        'Test::More'    => 0,
        'version'       => 0,
    },
    dist            => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean           => { FILES => 'lib/Macro.pm-*' },
);
