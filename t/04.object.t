# vim: filetype=perl :
use strict;
use warnings;

use Test::More tests => 37;    # last test to print

#use Test::More 'no_plan';
use Log::Log4perl::Tiny qw( :levels );

use lib 't';
use TestLLT qw( set_logger log_is log_like );

my $logger = Log::Log4perl::Tiny::get_logger();
ok($logger, 'got a logger instance');
set_logger($logger);

my @names = qw( trace debug info warn error fatal );
my @levels = ($TRACE, $DEBUG, $INFO, $WARN, $ERROR, $FATAL);
for my $i (0 .. $#names) {
   $logger->level($levels[$i]);

   my $current = $names[$i];

   my $blocked = 1;
   for my $name (@names) {
      $blocked = 0 if $name eq $current;
      if ($blocked) {
         log_is { $logger->$name("whatever $name") } '',
           "minimum level $current, nothing at $name level";
      }
      else {
         log_like { $logger->$name("whatever $name") }
         qr/whatever\ $name/mxs,
           "minimum level $current, something at $name level";
      }
   } ## end for my $name (@names)
} ## end for my $i (0 .. $#names)
