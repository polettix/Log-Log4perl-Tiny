# vim: filetype=perl :
use strict;
use warnings;

#use Test::More tests => 37;    # last test to print
use Test::More 'no_plan';
use Log::Log4perl::Tiny qw( :levels );

use lib 't';
use TestLLT qw( set_logger log_is log_like );

my $logger = Log::Log4perl::Tiny::get_logger();
ok($logger, 'got a logger instance');

$logger->level($INFO);
set_logger($logger);

my $hostname = eval {
   require Sys::Hostname;
   Sys::Hostname::hostname();
} || '';

my @tests = (
   ['%c', [ 'whatever' ], 'main' ],
   ['%C', [ 'whatever' ], 'main' ],
   ['%d', [ 'whatever' ], qr{\A\d{4}/\d\d/\d\d \d\d:\d\d:\d\d\z} ],
   ['%F', [ 'whatever' ], 't/TestLLT.pm' ],
   ['%H', [ 'whatever' ], $hostname ],
   ['%l', [ 'whatever' ], qr{\ATestLLT::log_like t/TestLLT\.pm \(\d+\)\z} ],
   ['%L', [ 'whatever' ], qr{\A\d+\z} ],
   ['%m', [qw( frozz buzz )], 'frozzbuzz'],
   ['%M', [ 'whatever' ], 'TestLLT::log_is'],
   ['%n', [ 'whatever' ], "\n" ],
   ['%p', [ 'whatever' ], 'INFO' ],
   ['%P', [ 'whatever' ], $$ ],
   ['%r', [ 'whatever' ], qr{\A\d+\z} ],
   ['%R', [ 'whatever' ], qr{\A\d+\z} ],
   ['%T', [ 'whatever' ], qr{\ATestLLT::log_like\(\) called at t/\d+\..*?\.t line \d+} ],
   ['%m%n', [qw( foo bar )],    "foobar$/"],
   ['[%d] [%-5p] %m%n', [ 'whatever', 'you', 'like' ], 
      qr{\A\[\d{4}/\d\d/\d\d \d\d:\d\d:\d\d\] \[INFO \] whateveryoulike\n\z}],
);

for my $test (@tests) {
   my ($format, $input, $output) = @$test;
   $logger->format($format);
   $output = $output->() if ref($output) eq 'CODE';
   if (ref $output) {
      log_like { $logger->info(@$input) } $output, "format: '$format'";
   }
   else {
      log_is { $logger->info(@$input) } $output, "format: '$format'";
   }
} ## end for my $test (@tests)
