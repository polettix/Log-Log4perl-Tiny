# vim: filetype=perl :
use strict;
use warnings;

#use Test::More tests => 37;    # last test to print
use Test::More 'no_plan';
use Log::Log4perl::Tiny qw( :levels );

my $logger = Log::Log4perl::Tiny::get_logger();
ok($logger, 'got a logger instance');
is($logger->level(), $INFO, 'logger level set to INFO as default');

use_ok('Log::Log4perl::Tiny', ':default_to_INFO');
is($logger->level(), $INFO, 'logger level set to INFO after new import');
