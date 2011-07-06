# vim: filetype=perl :
use strict;
use warnings;

#use Test::More tests => 37;    # last test to print
use Test::More 'no_plan';
use Log::Log4perl::Tiny qw( :levels :default_to_INFO );

my $logger = Log::Log4perl::Tiny::get_logger();
ok($logger, 'got a logger instance');
is($logger->level(), $INFO, 'logger level set to INFO as per import request');
