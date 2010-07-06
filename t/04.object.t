# vim: filetype=perl :
use strict;
use warnings;

use Test::More tests => 37;    # last test to print
#use Test::More 'no_plan';
use Log::Log4perl::Tiny qw( :levels );
use Test::Warn;

my $logger = Log::Log4perl::Tiny::get_logger();
ok($logger, 'got a logger instance');


sub _execute {
   my ($sub) = @_;

   # Save previous STDERR
   open my $olderr, '>&', \*STDERR or die "Can't dup STDERR: $!";

   # Deviate STDERR to a local string, execute and free STDERR
   close STDERR;
   open STDERR, '>', \my $stderr;
   eval { $sub->() } or do {print {*STDERR} $@ };
   close STDERR;

   # Restore previous STDERR
   open STDERR, '>&', $olderr or die "Can't dup \$olderr: $!";

   return $stderr;
}

sub stderr_is (&$$) {
   my ($sub, $expected, $message) = @_;
   my $stderr = _execute($sub);
   is($stderr, $expected, $message);
}

sub stderr_like (&$$) {
   my ($sub, $expected, $message) = @_;
   my $stderr = _execute($sub);
   like($stderr, $expected, $message);
}

my @names = qw( trace debug info warn error fatal );
my @levels = ($TRACE, $DEBUG, $INFO, $WARN, $ERROR, $FATAL);
for my $i (0 .. $#names) {
   $logger->level($levels[$i]);

   my $current = $names[$i];

   my $blocked = 1;
   for my $name (@names) {
      $blocked = 0 if $name eq $current;
      if ($blocked) {
         stderr_is { $logger->$name("whatever $name") } undef,
            "minimum level $current, nothing at $name level";
      }
      else {
         stderr_like { $logger->$name("whatever $name") }
            qr/whatever\ $name/mxs,
            "minimum level $current, something at $name level";
      }
   }
}
