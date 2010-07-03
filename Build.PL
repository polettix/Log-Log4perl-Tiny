use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Log::Log4perl::Tiny',
    license             => 'perl',
    dist_author         => 'Flavio Poletti <flavio [at] polettix [dot] it>',
    dist_version_from   => 'lib/Log/Log4perl/Tiny.pm',
    requires => {
        'Test::More' => 0,
        'version'    => 0,
    },
    add_to_cleanup      => [ 'Log-Log4perl-Tiny-*' ],
);

$builder->create_build_script();
