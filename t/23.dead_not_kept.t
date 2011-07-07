# vim: filetype=perl :
use strict;
use warnings;

#use Test::More tests => 37;    # last test to print
use Test::More 'no_plan';
use Log::Log4perl::Tiny qw( :levels :DEAD_if_first );
use Data::Dumper;

my $logger = Log::Log4perl::Tiny::get_logger();
ok($logger, 'got a logger instance');
is($logger->level(), $INFO, 'logger level set to INFO due to other module loading');

package Something::Different;
use Log::Log4perl::Tiny qw( :easy );
