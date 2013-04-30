#!/usr/bin/perl

use FindBin;
use Test::More;
use strict;
use warnings;
use Log::Log4perl::Tiny qw(:easy);

Log::Log4perl->easy_init({
        file   => ">$FindBin::Bin/$FindBin::Script.log",
        layout => '$m%n',
        level  => $DEBUG,
         });

my $tests=0;
my $buffer;
get_logger()->fh(sub { $buffer=shift; });

DEBUG '$\ is defined.';
$tests++; like($buffer,qr/\n/,'$\ is defined and a \n goes to the logger.');
local $/;
DEBUG '$\ is NOT defined!';
$tests++; like($buffer,qr/\n/,'$\ is NOT defined and a \n goes to the logger.');

END {
    done_testing($tests);
     };
__END__
Fix is simple --- save $/ to something local say $ors then use that in place of $/?
