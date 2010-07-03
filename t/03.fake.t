# vim: filetype=perl :
use strict;
use warnings;

use Test::More tests => 4; # last test to print
use Log::Log4perl::Tiny qw( :fake );

can_ok('Log::Log4perl', $_) for qw( import easy_init );

my $logger = Log::Log4perl::Tiny::get_logger();
ok($logger, 'got a logger instance');

$logger->level($Log::Log4perl::Tiny::DEBUG);

use Log::Log4perl qw( :easy_init ); # should be a no-op
Log::Log4perl->easy_init($Log::Log4perl::Tiny::ERROR);

is($logger->level(), $Log::Log4perl::Tiny::ERROR, 'easy_init');
