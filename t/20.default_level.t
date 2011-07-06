# vim: filetype=perl :
use strict;
use warnings;

#use Test::More tests => 37;    # last test to print
use Test::More 'no_plan';
use Log::Log4perl::Tiny qw( :levels );

my $logger = Log::Log4perl::Tiny::get_logger();
ok($logger, 'got a logger instance');
is($logger->level(), $DEAD, 'logger level set to DEAD as default');

$logger->level($INFO);
is($logger->level(), $INFO, 'logger level set to INFO as modified');

use_ok 'Log::Log4perl::Tiny';
is($logger->level(), $INFO, 'logger level still set to INFO after new "use"');

my $new_logger = Log::Log4perl::Tiny->new();
is($new_logger->level(), $DEAD, 'new logger level set to DEAD as default');
