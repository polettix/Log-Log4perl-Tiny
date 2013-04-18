package Log::Log4perl::Tiny;

# ABSTRACT: mimic Log::Log4perl in one single module

use warnings;
use strict;
use Carp;

our ($TRACE, $DEBUG, $INFO, $WARN, $ERROR, $FATAL, $OFF, $DEAD);
my ($_instance, %name_of, %format_for, %id_for);

sub import {
   my ($exporter, @list) = @_;
   my ($caller, $file, $line) = caller();
   no strict 'refs';

   if (grep { $_ eq ':full_or_fake' } @list) {
      @list = grep { $_ ne ':full_or_fake' } @list;
      my $sue = 'use Log::Log4perl (@list)';
      eval "
         package $caller;
         $sue;
         1;
      " and return;
      unshift @list, ':fake';
   } ## end if (grep { $_ eq ':full_or_fake'...

   my (%done, $level_set);
 ITEM:
   for my $item (@list) {
      next ITEM if $done{$item};
      $done{$item} = 1;
      if ($item =~ /^[a-zA-Z]/mxs) {
         *{$caller . '::' . $item} = \&{$exporter . '::' . $item};
      }
      elsif ($item eq ':levels') {
         for my $level (qw( TRACE DEBUG INFO WARN ERROR FATAL OFF DEAD )) {
            *{$caller . '::' . $level} = \${$exporter . '::' . $level};
         }
      }
      elsif ($item eq ':subs') {
         push @list, qw(
           ALWAYS TRACE DEBUG INFO WARN ERROR FATAL
           LOGWARN LOGDIE LOGEXIT LOGCARP LOGCLUCK LOGCROAK LOGCONFESS
           get_logger
         );
      } ## end elsif ($item eq ':subs')
      elsif ($item =~ /\A : (mimic | mask | fake) \z/mxs) {

         # module name as a string below to trick Module::ScanDeps
         if (!'Log::Log4perl'->can('easy_init')) {
            $INC{'Log/Log4perl.pm'} = __FILE__;
            *Log::Log4perl::import = sub { };
            *Log::Log4perl::easy_init = sub {
               my ($pack, $conf) = @_;
               if (ref $conf) {
                  $_instance = __PACKAGE__->new($conf);
                  $_instance->level($conf->{level})
                    if exists $conf->{level};
                  $_instance->format($conf->{format})
                    if exists $conf->{format};
                  $_instance->format($conf->{layout})
                    if exists $conf->{layout};
               } ## end if (ref $conf)
               elsif (defined $conf) {
                  $_instance->level($conf);
               }
            };
         } ## end if (!'Log::Log4perl'->can...
      } ## end elsif ($item =~ /\A : (mimic | mask | fake) \z/mxs)
      elsif ($item eq ':easy') {
         push @list, qw( :levels :subs :fake );
      }
      elsif (lc($item) eq ':dead_if_first') {
         get_logger()->_set_level_if_first($DEAD);
         $level_set = 1;
      }
   } ## end for my $item (@list)

   if (!$level_set) {
      my $logger = get_logger();
      $logger->_set_level_if_first($INFO);
      $logger->level($logger->level());
   }

   return;
} ## end sub import

sub new {
   my $package = shift;
   my %args = ref($_[0]) ? %{$_[0]} : @_;

   $args{format} = $args{layout} if exists $args{layout};

   if (exists $args{file}) {
      open my $fh, $args{file}
        or die "open('$args{file}'): $!";

      # Autoflush opened file
      my $previous = select($fh);
      $|++;
      select($previous);

      $args{fh} = $fh;
   } ## end if (exists $args{file})

   my $self = bless {
      fh    => \*STDERR,
      level => $INFO,
   }, $package;

   for my $accessor (qw( level fh format )) {
      next unless defined $args{$accessor};
      $self->$accessor($args{$accessor});
   }

   $self->format('[%d] [%5p] %m%n') unless exists $self->{format};

   return $self;
} ## end sub new

sub get_logger { return $_instance ||= __PACKAGE__->new(); }
sub LOGLEVEL { return get_logger()->level(@_); }

sub format {
   my $self = shift;

   if (@_) {
      $self->{format} = shift;
      $self->{args}   = [];

      $self->{args} = \my @args;
      my $replace = sub {
         my ($num, $op) = @_;
         return '%%' if $op eq '%';
         return "%%$op" unless defined $format_for{$op};
         push @args, $op;
         return "%$num$format_for{$op}[0]";
      };

      # transform into real format
      my $format_chars = join '', keys %format_for;
      $self->{format} =~ s{
            %                      # format marker
            ( -? \d* (?:\.\d+)? )  # number
            ([$format_chars])      # specifier
         }
         {
            $replace->($1, $2);
         }gsmex;
   } ## end if (@_)
   return $self->{format};
} ## end sub format

*layout = \&format;

sub log {
   my $self = shift;
   return if $self->{level} == $DEAD;

   my $level = shift;
   return if $level > $self->{level};

   my %data_for = (
      level   => $level,
      message => \@_,
   );
   my $message = sprintf $self->{format},
     map { $format_for{$_}[1]->(\%data_for); } @{$self->{args}};

   my $fh = $self->{fh};
   ref($fh) eq 'CODE' ? $fh->($message, $self) : print {$fh} $message;

   return;
} ## end sub log

sub ALWAYS { return $_instance->log($OFF, @_); }

sub _exit {
   my $self = shift || $_instance;
   exit $self->{logexit_code} if defined $self->{logexit_code};
   exit $Log::Log4perl::LOGEXIT_CODE
     if defined $Log::Log4perl::LOGEXIT_CODE;
   exit 1;
} ## end sub _exit

sub logwarn {
   my $self = shift;
   $self->warn(@_);
   CORE::warn(@_);
} ## end sub logwarn

sub logdie {
   my $self = shift;
   $self->fatal(@_);
   CORE::die(@_);
   $self->_exit();
} ## end sub logdie

sub logexit {
   my $self = shift;
   $self->fatal(@_);
   $self->_exit();
}

sub logcarp {
   my $self = shift;
   $self->warn(@_);
   require Carp;
   Carp::carp(@_);
} ## end sub logcarp

sub logcluck {
   my $self = shift;
   $self->warn(@_);
   require Carp;
   Carp::cluck(@_);
} ## end sub logcluck

sub logcroak {
   my $self = shift;
   $self->fatal(@_);
   require Carp;
   Carp::croak(@_);
} ## end sub logcroak

sub logconfess {
   my $self = shift;
   $self->fatal(@_);
   require Carp;
   Carp::confess(@_);
} ## end sub logconfess

sub level {
   my $self = shift;
   $self = $_instance unless ref $self;
   if (@_) {
      my $level = shift;
      return unless exists $id_for{$level};
      $self->{level} = $id_for{$level};
      $self->{_count}++;
   } ## end if (@_)
   return $self->{level};
} ## end sub level

sub _set_level_if_first {
   my ($self, $level) = @_;
   if (!$self->{_count}) {
      $self->level($level);
      delete $self->{_count};
   }
   return;
} ## end sub _set_level_if_first

BEGIN {

   # %format_for idea from Log::Tiny by J. M. Adler
   my $last_log = $^T;
   %format_for = (    # specifiers according to Log::Log4perl
      c => [s => sub { 'main' }],
      C => [
         s => sub {
            my ($internal_package) = caller 0;
            for my $i (1 .. 4) {
               my ($package) = caller $i;
               last unless defined $package;
               return $package if $package ne $internal_package;
            }
            return '*undef*';
           }
      ],
      d => [
         s => sub {
            my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday,
               $isdst) = localtime();
            sprintf '%04d/%02d/%02d %02d:%02d:%02d',
              $year + 1900, $mon + 1, $mday, $hour, $min, $sec;
           }
      ],
      F => [s => sub { (caller(3))[1] },],
      H => [
         s => sub {
            eval { require Sys::Hostname; Sys::Hostname::hostname() }
              || '';
           }
      ],
      l => [
         s => sub {
            my (undef, undef, undef, $subroutine) = caller(4);
            my (undef, $filename, $line) = caller(3);
            sprintf '%s %s (%d)', $subroutine, $filename, $line;
           }
      ],
      L => [d => sub { (caller(3))[2] },],
      m => [
         s => sub {
            join(
               (defined $, ? $, : ''),
               map { ref($_) eq 'CODE' ? $_->() : $_; } @{shift->{message}}
            );
         },
      ],
      M => [s => sub { (caller(4))[3] },],
      n => [s => sub { $/ },],
      p => [s => sub { $name_of{shift->{level}} },],
      P => [d => sub { $$ },],
      r => [d => sub { time - $^T },],
      R => [d => sub { my $l = $last_log; ($last_log = time) - $l; },],
      T => [
         s => sub {
            my $level = 4;
            my @chunks;
            while (my @caller = caller($level++)) {
               push @chunks,
                 "$caller[3]() called at $caller[1] line $caller[2]";
            }
            join ', ', @chunks;
         },
      ],
   );

   # From now on we're going to play with GLOBs...
   no strict 'refs';

   for my $name (qw( FATAL ERROR WARN INFO DEBUG TRACE )) {

      # create the ->level methods
      *{__PACKAGE__ . '::' . lc($name)} = sub {
         my $self = shift;
         return $self->log($$name, @_);
      };

      # create ->is_level and ->isLevelEnabled methods as well
      *{__PACKAGE__ . '::is' . ucfirst(lc($name)) . 'Enabled'} =
        *{__PACKAGE__ . '::is_' . lc($name)} = sub {
         return 0 if $_[0]->{level} == $DEAD || $$name > $_[0]->{level};
         return 1;
        };
   } ## end for my $name (qw( FATAL ERROR WARN INFO DEBUG TRACE ))

   for my $name (
      qw(
      FATAL ERROR WARN INFO DEBUG TRACE
      LOGWARN LOGDIE LOGEXIT
      LOGCARP LOGCLUCK LOGCROAK LOGCONFESS
      )
     )
   {
      *{__PACKAGE__ . '::' . $name} = sub {
         $_instance->can(lc $name)->($_instance, @_);
      };
   } ## end for my $name (qw( FATAL ERROR WARN INFO DEBUG TRACE...

   for my $accessor (qw( fh logexit_code )) {
      *{__PACKAGE__ . '::' . $accessor} = sub {
         my $self = shift;
         $self = $_instance unless ref $self;
         $self->{$accessor} = shift if @_;
         return $self->{$accessor};
      };
   } ## end for my $accessor (qw( fh logexit_code ))

   my $index = -1;
   for my $name (qw( DEAD OFF FATAL ERROR WARN INFO DEBUG TRACE )) {
      $name_of{$$name = $index} = $name;
      $id_for{$name}  = $index;
      $id_for{$index} = $index;
      ++$index;
   } ## end for my $name (qw( DEAD OFF FATAL ERROR WARN INFO DEBUG TRACE ))

   get_logger();    # initialises $_instance;
} ## end BEGIN

1;                  # Magic true value required at end of module
__END__

=head1 SYNOPSIS

   use Log::Log4perl::Tiny qw( :easy );
   Log::Log4perl->easy_init({
      file   => '>>/var/log/something.log',
      layout => '[%d] [%-5P:%-5p] %m%n',
      level  => $INFO,
   });

   WARN 'something weird happened';
   INFO 'just doing it';
   DEBUG 'this does not get printed at $INFO level';

   # LOGLEVEL isn't in Log::Log4perl, but might come handy
   LOGLEVEL($DEBUG);   # enable debugging for small section
   # otherwise, "get_logger()->level($DEBUG)", see below

   DEBUG 'now this gets printed';
   LOGLEVEL($INFO);    # disable debugging again
   DEBUG 'skipped, again';
   DEBUG 'complex evaluation value:', sub { 
      # evaluation skipped if log level filters DEBUG out
   };

   # Object-oriented interface is available as well
   my $logger = get_logger();
   $logger->level($DEBUG);   # enable debugging for small section
   $logger->debug('whatever you want');
   $logger->level($INFO);    # disable debugging again

   # All stealth loggers are available
   LOGCONFESS 'I cannot accept this, for a whole stack of reasons!';

   # Want to change layout?
   $logger->layout('[%d %p] %m%n');
   # or, equivalently
   $logger->format('[%d %p] %m%n');

   # Want to send the output somewhere else?
   use IO::Handle;
   open my $fh, '>>', '/path/to/new.log';
   $fh->autoflush();
   $logger->fh($fh);

   # Want to handle the output message by yourself?
   my @queue; # all log messages will be put here
   $logger->fh(sub { push @queue, $_[0] });


=head1 DESCRIPTION

Yes... yet another logging module. Nothing particularly fancy nor
original, too, but a single-module implementation of the features I
use most from L<Log::Log4perl> for quick things, namely:

=over

=item *

easy mode and stealth loggers (aka log functions C<INFO>, C<WARN>, etc.);

=item *

debug message filtering by log level;

=item *

line formatting customisation;

=item *

quick sending of messages to a log file.

=back

There are many, many things that are not included; probably the most
notable one is the ability to provide a configuration file.

=head2 Why?

I have really nothing against L<Log::Log4perl>, to the point that
one of the import options is to check whether L<Log::Log4perl> is installed
and use it if possible. I just needed to crunch the plethora of
modules down to a single-file module, so that I can embed it easily in
scripts I use in machines where I want to reduce my impact as much as
possible.

=head2 Log Levels

L<Log::Log4perl::Tiny> implements all I<standard> L<Log::Log4perl>'s
log levels, without the possibility to change them. The correspondent
values are available in the following variables (in order of increasing
severity or I<importance>):

=over

=item C<< $TRACE >>

=item C<< $DEBUG >>

=item C<< $INFO >>

=item C<< $WARN >>

=item C<< $ERROR >>

=item C<< $FATAL >>

=back

The default log level is C<$INFO>. In addition to the above, the following
levels are defined as well:

=over

=item C<< $OFF >>

also in L<Log::Log4perl>, useful to turn off all logging except for C<ALWAYS>

=item C<< $DEAD >>

not in L<Log::Log4perl>, when the threshold log level is set to this value
every log is blocked (even when called from the C<ALWAYS> stealth logger).

=back

You can import these variables using the C<:levels> import facility,
or you can use the directly from the L<Log::Log4perl::Tiny> namespace.
They are imported automatically if the C<:easy> import option is specified.


=head3 Default Log Level

As of version 1.1.0 the default logging level is still C<$INFO> like
any previous version, but it is possible to modify this value to C<$DEAD>
through the C<:dead_if_first> import key.

This import key is useful to load Log::Log4perl in modules that you
want to publish but where you don't want to force the end user to
actually use it. In other terms, if you do this:

   package My::Module;
   use Log::Log4perl::Tiny qw( :easy :dead_if_first );

you will import all the functionalities associated to C<:easy> but
will silence the logger off I<unless> somewhere else the module
is loaded (and imported) without this option. In this way:

=over

=item *

if the user of your module does I<not> import L<Log::Log4perl::Tiny>,
all log messages will be dropped (thanks to the log level set to
C<$DEAD>)

=item *

otherwise, if the user imports L<Log::Log4perl::Tiny> without the
option, the log level will be set to the default value (unless it
has already been explicitly set somewhere else).

=back

=head2 Easy Mode Overview

I love L<Log::Log4perl>'s easy mode because it lets you set up a
sophisticated logging infrastructure with just a few keystrokes:

   use Log::Log4perl qw( :easy );
   Log::Log4perl->easy_init({
      file   => '>>/var/log/something.log',
      layout => '[%d] [%-5P:%-5p] %m%n',
      level  => $INFO,
   });
   INFO 'program started, yay!';

   use Data::Dumper;
   DEBUG 'Some stuff in main package', sub { Dumper(\%main::) };

If you want, you can replicate it with just a change in the first line:

   use Log::Log4perl::Tiny qw( :easy );
   Log::Log4perl->easy_init({
      file   => '>>/var/log/something.log',
      layout => '[%d] [%-5P:%-5p] %m%n',
      level  => $INFO,
   });
   INFO 'program started, yay!';

   use Data::Dumper;
   DEBUG 'Some stuff in main package', sub { Dumper(\%main::) };

Well... yes, I'm invading the L<Log::Log4perl> namespace in order to
reduce the needed changes as mush as possible. This is useful when I
begin using L<Log::Log4perl> and then realise I want to make a single
script with all modules embedded. There is also another reason why
I put C<easy_init()> in L<Log::Log4perl> namespace:

   use Log::Log4perl::Tiny qw( :full_or_fake :easy );
   Log::Log4perl->easy_init({
      file   => '>>/var/log/something.log',
      layout => '[%d] [%-5P:%-5p] %m%n',
      level  => $INFO,
   });
   INFO 'program started, yay!';

   use Data::Dumper;
   DEBUG 'Some stuff in main package', sub { Dumper(\%main::) };

With import option C<full_or_fake>, in fact, the module first tries to
load L<Log::Log4perl> in the caller's namespace with the provided
options (except C<full_or_fake>, of course), returning immediately if
it is successful; otherwise, it tries to "fake" L<Log::Log4perl> and
installs its own logging functions. In this way, if L<Log::Log4perl>
is available it will be used, but you don't have to change anything
if it isn't.

Easy mode tries to mimic what L<Log::Log4perl> does, or at least
the things that (from a purely subjective point of view) are most
useful: C<easy_init()> and I<stealth loggers>.

=head2 C<easy_init()>

L<Log::Log4perl::Tiny> only supports three options from the big
brother:

=over

=item C<< level >>

the log level threshold. Logs sent at a higher or equal priority
(i.e. at a more I<important> level, or equal) will be printed out,
the others will be ignored. The default value is C<$INFO>;

=item C<< file >>

a file name where to send the log lines. For compatibility with
L<Log::Log4perl>, a 2-arguments C<open()> will be performed, which
means you can easily set the opening mode, e.g. C<<< >>filename >>>.
The default is to send logging messages to C<STDERR>;

=item C<< layout >>

the log line layout (it can also be spelled C<format>, they are
synonims). The default value is the following:

   [%d] [%5p] %m%n

which means I<date in brackets, then log level in brackets always
using five chars, left-aligned, the log message and a newline>.

=back

If you call C<easy_init()> with a single unblessed scalar, it is
considered to be the C<level> and it will be set accordingly.
Otherwise, you have to pass a hash ref with the keys above.


=head2 Stealth Loggers

Stealth loggers are functions that emit a log message at a given
severity; they are installed when C<:easy> mode is turned on
(see L</Easy Mode Overview>).

They are named after the corresponding level:


=over

=item C<< TRACE >>

=item C<< DEBUG >>

=item C<< INFO >>

=item C<< WARN >>

=item C<< ERROR >>

=item C<< FATAL >>

=back

Additionally, you get the following logger functions (again, these are
in line with L<Log::Log4perl>):

=over

=item C<< ALWAYS >>

emit log whatever the configured logging level, apart from C<$OFF> that
disables all logging;

=item C<< LOGWARN >>

emit log at C<WARN> level, C<warn()> and then exit;

=item C<< LOGDIE >>

emit log at C<FATAL> level, C<die()> and then exit (if C<die()>
didn't already exit);

=item C<< LOGEXIT >>

emit log at C<FATAL> level and then exit;

=item C<< LOGCARP >>

emit log at C<WARN> level and then call C<Carp::carp()>;

=item C<< LOGCLUCK >>

emit log at C<WARN> level and then call C<Carp::cluck()>;

=item C<< LOGCROAK >>

emit log at C<FATAL> level and then call C<Carp::croak()>;

=item C<< LOGCONFESS >>

emit log at C<FATAL> level and then call C<Carp::confess()>;

=back

If you want to set the exit code for C<LOGWARN> and C<LOGEXIT> above
(and C<LOGDIE> as well, in case C<die()> does not exit by itself),
you can go "the L<Log::Log4perl> way" and set
C<$Log::Log4perl::LOGEXIT_CODE>, or set a code with
C<logexit_code()> - but you have to wait to read something about the
object-oriented interface before doing this!

There is also one additional stealth function that L<Log::Log4perl>
misses but that I think is of the outmoste importance: C<LOGLEVEL>, to
set the log level threshold for printing. If you want to be 100%
compatible with Log::Log4perl, anyway, you should rather do the following:

   get_logger()->level(...);  # instead of LOGLEVEL(...)

This function does not get imported when you specify C<:easy>, anyway,
so you have to import it explicitly. This will help you remembering that
you are deviating from L<Log::Log4perl>.

=head2 Emitting Logs

To emit a log, you can call any of the stealth logger functions or any
of the corresponding log methods. All the parameters that you pass are
sent to the output stream as they are, except code references that are
first evaluated. This lets you embed costly evaluations (e.g. generate
heavy dumps of variabls) inside subroutines, and avoid the cost
of evaluation in case the log is filtered out:

   use Data::Dumper;
   LOGLEVEL($INFO); # cut DEBUG and TRACE out
   TRACE 'costly evaluation: ', sub { Dumper($heavy_object) };
   # Dumper() is not actually called because DEBUG level is
   # filtered out

If you use the C<log()> method, the first parameter is the log level,
then the others are interpreted as described above.

=head2 Log Line Layout

The log line layout sets the contents of a log line. The layout is
configured as a C<printf>-like string, with placeholder identifiers
that are modeled (with simplifications) after L<Log::Log4perl>'s ones:


    %c Category of the logging event.
    %C Fully qualified package (or class) name of the caller
    %d Current date in yyyy/MM/dd hh:mm:ss format
    %F File where the logging event occurred
    %H Hostname
    %l Fully qualified name of the calling method followed by the
       callers source the file name and line number between 
       parentheses.
    %L Line number within the file where the log statement was issued
    %m The message to be logged
    %M Method or function where the logging request was issued
    %n Newline (OS-independent)
    %p Priority of the logging event
    %P pid of the current process
    %r Number of milliseconds elapsed from program start to logging 
       event
    %% A literal percent (%) sign

Notably, both C<%x> (NDC) and C<%X> (MDC) are missing. Moreover, the
extended specifier feature with additional info in braces (like
C<%d{HH:mm}>) is missing, i.e. the structure of each specifier above
is fixed. (Thanks to C<Log::Tiny> for the cool trick of how to handle
the C<printf>-like string, which is probably mutuated from
C<Log::Log4perl> itself according to the comments).


=head1 INTERFACE 

You have two interfaces at your disposal, the functional one (with all
the stealth logger functions) and the object-oriented one (with
explicit actions upon a logger object). Choose your preferred option.

=head2 Functional Interface

The functional interface sports the following functions (imported
automatically when C<:easy> is passed as import option except for
C<LOGLEVEL>):

=over

=item C<< TRACE >>

=item C<< DEBUG >>

=item C<< INFO >>

=item C<< WARN >>

=item C<< ERROR >>

=item C<< FATAL >>

stealth logger functions, each emits a log at the corresponding level;

=item C<< ALWAYS >>

emit log whatever the configured logging level (except C<$DEAD>);

=item C<< LOGWARN >>

emit log at C<WARN> level, C<warn()> and then exit;

=item C<< LOGDIE >>

emit log at C<FATAL> level, C<die()> and then exit (if C<die()>
didn't already exit);

=item C<< LOGEXIT >>

emit log at C<FATAL> level and then exit;

=item C<< LOGCARP >>

emit log at C<WARN> level and then call C<Carp::carp()>;

=item C<< LOGCLUCK >>

emit log at C<WARN> level and then call C<Carp::cluck()>;

=item C<< LOGCROAK >>

emit log at C<FATAL> level and then call C<Carp::croak()>;

=item C<< LOGCONFESS >>

emit log at C<FATAL> level and then call C<Carp::confess()>;

=item C<< LOGLEVEL >>

(Not in L<Log::Log4perl>) (Not imported with C<:easy>)

set the minimum log level for sending a log message to the output;

=back

=head2 Object-Oriented Interface

The functional interface is actually based upon actions on
a pre-defined fixed instance of a C<Log::Log4perl::Tiny> object,
so you can do the same with a logger object as well:

=over

=item C<< get_logger >>

this function gives you the pre-defined logger instance (i.e. the
same used by the stealth logger functions described above).

=item C<< new >>

if for obscure reasons the default logger isn't what you want, you
can get a brand new object! The constructor accepts either a
list of key-values or a reference to a hash, supporting the
following keys:

=over

=item B<< format >>

=item B<< layout >>

=item B<< file >>

=item B<< level >>

see L<< C<easy_init()> >> and the methods below with the same
name

=item B<< fh >>

see method C<fh> below

=back

=back

The methods you can call upon the object mimic the functional
interface, but with lowercase method names:

=over

=item C<< trace >>

=item C<< debug >>

=item C<< info >>

=item C<< warn >>

=item C<< error >>

=item C<< fatal >>

logging functions, each emits a log at the corresponding level;

=item C<< is_trace >>

=item C<< is_debug >>

=item C<< is_info >>

=item C<< is_warn >>

=item C<< is_error >>

=item C<< is_fatal >>

=item C<< isTraceEnabled >>

=item C<< isDebugEnabled >>

=item C<< isInfoEnabled >>

=item C<< isWarnEnabled >>

=item C<< isErrorEnabled >>

=item C<< isFatalEnabled >>

log level test functions, each returns the status of the corresponding level;

=item C<< always >>

emit log whatever the configured logging level;

=item C<< logwarn >>

emit log at C<WARN> level (if allowed) and C<warn()> (always);

=item C<< logdie >>

emit log at C<FATAL> level, C<die()> and then exit (if C<die()>
didn't already exit);

=item C<< logexit >>

emit log at C<FATAL> level and then exit;

=item C<< logcarp >>

emit log at C<WARN> level and then call C<Carp::carp()>;

=item C<< logcluck >>

emit log at C<WARN> level and then call C<Carp::cluck()>;

=item C<< logcroak >>

emit log at C<FATAL> level and then call C<Carp::croak()>;

=item C<< logconfess >>

emit log at C<FATAL> level and then call C<Carp::confess()>;

=back

The main logging function is actually the following:

=over

=item C<< log >>

the first parameter is the log level, the rest is the message to log
apart from references to subroutines that are first evaluated

=back

Additionally, you have the following accessors:

=over

=item C<< level >>

get/set the minimum level for sending messages to the output stream.
By default the level is set to C<$INFO>.

=item C<< fh >>

get/set the output filehandle.

As an extention over L<Log::Log4perl>,
you can also set a reference to a subroutine as a filehandle, in
which case it will be called with two parameters: the message that
would be print and a reference to the logger object that is calling
the sub. For example, if you simply want to collect the log
messages without actually outputting them anywhere, you can do this:

   my @messages;
   get_logger()->fh(sub {
      my ($message, $logger) = @_;
      push @messages, $message;
      return;
   });

By default this parameter is set to be equal to C<STDERR>.

=item C<< format >>

=item C<< layout >>

get/set the line formatting;

=item C<< logexit_code >>

get/set the exit code to be used with C<logexit()> (and
C<logdie()> as well if C<die()> doesn't exit).

=back

=head1 DEPENDENCIES

None.

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests through http://rt.cpan.org/


=head1 SEE ALSO

L<Log::Log4perl> is one of the most useful modules I ever used, go check it!

=cut
