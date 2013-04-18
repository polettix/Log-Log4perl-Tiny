# vim: filetype=perl :
use strict;
use warnings;

use Test::More tests => 3; # last test to print

use Log::Log4perl::Tiny qw< :easy get_logger >;
Log::Log4perl::easy_init($INFO);

my (@warnings, @messages, $outcome);
get_logger()->fh(sub { push @messages, $_[0] });
local $SIG{__WARN__} = sub { push @warnings, $_[0] };
LOGWARN('whatever');
ok(1, 'LOGWARN did not exit');
is(scalar(@warnings), 1, 'one element in warnings');
is(scalar(@messages), 1, 'one element in messages');
