use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Log::Log4perl::Tiny',
    AUTHOR              => 'Flavio Poletti <flavio [at] polettix [dot] it>',
    VERSION_FROM        => 'lib/Log/Log4perl/Tiny.pm',
    ABSTRACT_FROM       => 'lib/Log/Log4perl/Tiny.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'version'    => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Log-Log4perl-Tiny-*' },
);
