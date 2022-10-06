# NAME

Log::Log4perl::Tiny - mimic Log::Log4perl in one single module

# VERSION

This document describes Log::Log4perl::Tiny version {{\[ version \]}}.

<div>
    <a href="https://travis-ci.org/polettix/Log-Log4perl-Tiny">
    <img alt="Build Status" src="https://travis-ci.org/polettix/Log-Log4perl-Tiny.svg?branch=master">
    </a>

    <a href="https://www.perl.org/">
    <img alt="Perl Version" src="https://img.shields.io/badge/perl-5.8+-brightgreen.svg">
    </a>

    <a href="https://badge.fury.io/pl/Log-Log4perl-Tiny">
    <img alt="Current CPAN version" src="https://badge.fury.io/pl/Log-Log4perl-Tiny.svg">
    </a>

    <a href="http://cpants.cpanauthors.org/dist/Log-Log4perl-Tiny">
    <img alt="Kwalitee" src="http://cpants.cpanauthors.org/dist/Log-Log4perl-Tiny.png">
    </a>

    <a href="http://www.cpantesters.org/distro/L/Log-Log4perl-Tiny.html?distmat=1">
    <img alt="CPAN Testers" src="https://img.shields.io/badge/cpan-testers-blue.svg">
    </a>

    <a href="http://matrix.cpantesters.org/?dist=Log-Log4perl-Tiny">
    <img alt="CPAN Testers Matrix" src="https://img.shields.io/badge/matrix-@testers-blue.svg">
    </a>
</div>

# SYNOPSIS

    use Log::Log4perl::Tiny qw( :easy );
    Log::Log4perl->easy_init({
       file   => '/var/log/something.log',
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

    # Want to multiplex output to different channels?
    $logger->fh(
       build_channels(
          fh          => \*STDERR,
          file_create => '/var/log/lastrun.log',
          file_append => '/var/log/overall.log',
       )
    );

    # Want to handle the output message by yourself?
    my @queue; # e.g. all log messages will be put here
    $logger->fh(sub { push @queue, $_[0] });

    # As of 1.4.0, you can set key-value pairs in the logger
    $logger->loglocal(foo => 'bar');
    LOGLOCAL(baz => 100);

    # You can later retrieve the value in the format with %{key}e
    $logger->format("[%{foo}e] [%{baz}e] %m%n");

    # You are not limited to scalars, you can use references too
    LOGLOCAL(baz => sub {
       my ($data, $op, $ekey) = @_;
       return join '.', @{$data->{tod}}; # epoch from gettimeofday
    });
    LOGLOCAL(foo => sub { return rand 100 });

# DESCRIPTION

Yes... yet another logging module. Nothing particularly fancy nor
original, too, but a single-module implementation of the features I
use most from [Log::Log4perl](https://metacpan.org/pod/Log%3A%3ALog4perl) for quick things, namely:

- easy mode and stealth loggers (aka log functions `INFO`, `WARN`, etc.);
- debug message filtering by log level;
- line formatting customisation;
- quick sending of messages to a log file.

There are many, many things that are not included; probably the most
notable one is the ability to provide a configuration file.

## Why?

I have really nothing against [Log::Log4perl](https://metacpan.org/pod/Log%3A%3ALog4perl), to the point that
one of the import options is to check whether [Log::Log4perl](https://metacpan.org/pod/Log%3A%3ALog4perl) is installed
and use it if possible. I just needed to crunch the plethora of
modules down to a single-file module, so that I can embed it easily in
scripts I use in machines where I want to reduce my impact as much as
possible.

## Log Levels

[Log::Log4perl::Tiny](https://metacpan.org/pod/Log%3A%3ALog4perl%3A%3ATiny) implements all _standard_ [Log::Log4perl](https://metacpan.org/pod/Log%3A%3ALog4perl)'s
log levels, without the possibility to change them. The correspondent
values are available in the following variables (in order of increasing
severity or _importance_):

- `$TRACE`
- `$DEBUG`
- `$INFO`
- `$WARN`
- `$ERROR`
- `$FATAL`

The default log level is `$INFO`. In addition to the above, the following
levels are defined as well:

- `$OFF`

    also in [Log::Log4perl](https://metacpan.org/pod/Log%3A%3ALog4perl), useful to turn off all logging except for `ALWAYS`

- `$DEAD`

    not in [Log::Log4perl](https://metacpan.org/pod/Log%3A%3ALog4perl), when the threshold log level is set to this value
    every log is blocked (even when called from the `ALWAYS` stealth logger).

You can import these variables using the `:levels` import facility,
or you can use the directly from the [Log::Log4perl::Tiny](https://metacpan.org/pod/Log%3A%3ALog4perl%3A%3ATiny) namespace.
They are imported automatically if the `:easy` import option is specified.

### Default Log Level

As of version 1.1.0 the default logging level is still `$INFO` like
any previous version, but it is possible to modify this value to `$DEAD`
through the `:dead_if_first` import key.

This import key is useful to load Log::Log4perl in modules that you
want to publish but where you don't want to force the end user to
actually use it. In other terms, if you do this:

    package My::Module;
    use Log::Log4perl::Tiny qw( :easy :dead_if_first );

you will import all the functionalities associated to `:easy` but
will silence the logger off _unless_ somewhere else the module
is loaded (and imported) without this option. In this way:

- if the user of your module does _not_ import [Log::Log4perl::Tiny](https://metacpan.org/pod/Log%3A%3ALog4perl%3A%3ATiny),
all log messages will be dropped (thanks to the log level set to
`$DEAD`)
- otherwise, if the user imports [Log::Log4perl::Tiny](https://metacpan.org/pod/Log%3A%3ALog4perl%3A%3ATiny) without the
option, the log level will be set to the default value (unless it
has already been explicitly set somewhere else).

## Easy Mode Overview

I love [Log::Log4perl](https://metacpan.org/pod/Log%3A%3ALog4perl)'s easy mode because it lets you set up a
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

Well... yes, I'm invading the [Log::Log4perl](https://metacpan.org/pod/Log%3A%3ALog4perl) namespace in order to
reduce the needed changes as mush as possible. This is useful when I
begin using [Log::Log4perl](https://metacpan.org/pod/Log%3A%3ALog4perl) and then realise I want to make a single
script with all modules embedded. There is also another reason why
I put `easy_init()` in [Log::Log4perl](https://metacpan.org/pod/Log%3A%3ALog4perl) namespace:

    use Log::Log4perl::Tiny qw( :full_or_fake :easy );
    Log::Log4perl->easy_init({
       file   => '>>/var/log/something.log',
       layout => '[%d] [%-5P:%-5p] %m%n',
       level  => $INFO,
    });
    INFO 'program started, yay!';

    use Data::Dumper;
    DEBUG 'Some stuff in main package', sub { Dumper(\%main::) };

With import option `full_or_fake`, in fact, the module first tries to
load [Log::Log4perl](https://metacpan.org/pod/Log%3A%3ALog4perl) in the caller's namespace with the provided
options (except `full_or_fake`, of course), returning immediately if
it is successful; otherwise, it tries to "fake" [Log::Log4perl](https://metacpan.org/pod/Log%3A%3ALog4perl) and
installs its own logging functions. In this way, if [Log::Log4perl](https://metacpan.org/pod/Log%3A%3ALog4perl)
is available it will be used, but you don't have to change anything
if it isn't.

Easy mode tries to mimic what [Log::Log4perl](https://metacpan.org/pod/Log%3A%3ALog4perl) does, or at least
the things that (from a purely subjective point of view) are most
useful: `easy_init()` and _stealth loggers_.

## `easy_init()`

[Log::Log4perl::Tiny](https://metacpan.org/pod/Log%3A%3ALog4perl%3A%3ATiny) only supports three options from the big
brother, plus its own:

- `level`

    the log level threshold. Logs sent at a higher or equal priority
    (i.e. at a more _important_ level, or equal) will be printed out,
    the others will be ignored. The default value is `$INFO`;

- `file`

    a file name where to send the log lines. For compatibility with
    [Log::Log4perl](https://metacpan.org/pod/Log%3A%3ALog4perl), a 2-arguments `open()` will be performed, which
    means you can easily set the opening mode, e.g. `>>filename`.

    Note that the 2-arguments `open()` is intrinsically insecure and will
    trigger the following error when running setuid:

        Insecure dependency in open while running setuid

    so be sure to use either `file_create` or `file_append` instead if
    you're running setuid. These are extensions added by Log::Log4perl::Tiny
    to cope with this specific case (and also to allow you avoid the 2-args
    `open()` anyway).

    Another Log::Log4perl::Tiny extension added as of version 1.3.0 is
    the key `channels` where you can pass an array reference with
    channels descriptions (see ["build\_channels"](#build_channels) for details).

    The default is to send logging messages to `STDERR`;

- `filter`

    (Not in [Log::Log4perl](https://metacpan.org/pod/Log%3A%3ALog4perl)) (As of 1.8.0)

    a filter function to be applied onto every message before it is emitted.
    This can be useful for multi-line log messages, when a specific
    start-of-line is needed (e.g. a hash character).

    By default nothing is done.

- `layout`

    the log line layout (it can also be spelled `format`, they are
    synonims). The default value is the following:

        [%d] [%5p] %m%n

    which means _date in brackets, then log level in brackets always
    using five chars, left-aligned, the log message and a newline_.

If you call `easy_init()` with a single unblessed scalar, it is
considered to be the `level` and it will be set accordingly.
Otherwise, you have to pass a hash ref with the keys above.

In addition to the above keys, the `easy_init()` method installed
by Log::Log4perl::Tiny also accepts all keys defined for ["new"](#new), e.g.
`format` (an alias for `layout`) and the different alternatives to
`file` (`file_insecure`, `file_create` and `file_append`).

## Stealth Loggers

Stealth loggers are functions that emit a log message at a given
severity; they are installed when `:easy` mode is turned on
(see ["Easy Mode Overview"](#easy-mode-overview)).

They are named after the corresponding level:

- `TRACE`
- `DEBUG`
- `INFO`
- `WARN`
- `ERROR`
- `FATAL`

Additionally, you get the following logger functions (again, these are
in line with [Log::Log4perl](https://metacpan.org/pod/Log%3A%3ALog4perl)):

- `ALWAYS`

    emit log whatever the configured logging level, apart from `$DEAD` that
    disables all logging;

- `LOGWARN`

    emit log at `WARN` level and then `warn()` it;

- `LOGDIE`

    emit log at `FATAL` level, `die()` and then exit (if `die()`
    didn't already exit);

- `LOGEXIT`

    emit log at `FATAL` level and then exit;

- `LOGCARP`

    emit log at `WARN` level and then call `Carp::carp()`;

- `LOGCLUCK`

    emit log at `WARN` level and then call `Carp::cluck()`;

- `LOGCROAK`

    emit log at `FATAL` level and then call `Carp::croak()`;

- `LOGCONFESS`

    emit log at `FATAL` level and then call `Carp::confess()`;

If you want to set the exit code for `LOGEXIT` above
(and `LOGDIE` as well, in case `die()` does not exit by itself),
you can go "the [Log::Log4perl](https://metacpan.org/pod/Log%3A%3ALog4perl) way" and set
`$Log::Log4perl::LOGEXIT_CODE`, or set a code with
`logexit_code()` - but you have to wait to read something about the
object-oriented interface before doing this!

As indicated, functions ["LOGWARN"](#logwarn), ["LOGDIE"](#logdie), ["LOGCARP"](#logcarp),
["LOGCLUCK"](#logcluck), ["LOGCROAK"](#logcroak), and ["LOGCONFESS"](#logconfess) (as well as their
lowercase counterparts called as object methods) both emit the log
message on the normal output channel for Log::Log4perl::Tiny and call
the respective function. This might not be what you want in the default
case where the output channel is standard error, because you will end up
with duplicate error messages. You can avoid the call to the
_canonical_ function setting import option `:no_extra_logdie_message`,
in line with what [Log::Log4perl](https://metacpan.org/pod/Log%3A%3ALog4perl) provides.

There is also one additional stealth function that [Log::Log4perl](https://metacpan.org/pod/Log%3A%3ALog4perl)
misses but that I think is of the outmoste importance: `LOGLEVEL`, to
set the log level threshold for printing. If you want to be 100%
compatible with Log::Log4perl, anyway, you should rather do the following:

    get_logger()->level(...);  # instead of LOGLEVEL(...)

This function does not get imported when you specify `:easy`, anyway,
so you have to import it explicitly. This will help you remembering that
you are deviating from [Log::Log4perl](https://metacpan.org/pod/Log%3A%3ALog4perl).

## Emitting Logs

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

If you use the `log()` method, the first parameter is the log level,
then the others are interpreted as described above.

## Log Line Layout

The log line layout sets the contents of a log line. The layout is
configured as a `printf`-like string, with placeholder identifiers
that are modeled (with simplifications) after [Log::Log4perl](https://metacpan.org/pod/Log%3A%3ALog4perl)'s ones:

    %c Category of the logging event.
    %C Fully qualified package (or class) name of the caller
    %d Current date in yyyy/MM/dd hh:mm:ss format
    %D Current date in strftime's "%Y-%m-%d %H:%M:%S.$u%z" (localtime)
    %{type}D Current date as strftime's "%Y-%m-%d %H:%M:%S.$u%z"
       (type can be utc or local)
    %{key}e Evaluate or substitute (extension WRT Log::Log4perl)
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
    %R Number of milliseconds elapsed from last logging event including
       a %R to current logging event
    %T A stack trace of functions called
    %% A literal percent (%) sign

Notably, both `%x` (NDC) and `%X` (MDC) are missing. The functionality
for the latter is partially covered by the extension `%e` explained
below.  Moreover, the extended specifier feature with additional info in
braces (like `%d{HH:mm}`) is missing, i.e. the structure of each
specifier above is fixed. (Thanks to `Log::Tiny` for the cool trick of
how to handle the `printf`-like string, which is probably mutuated from
`Log::Log4perl` itself according to the comments).

There are also two extensions with respect to Log::Log4perl, that help
partially cover the missing items explained above, as of release 1.4.0:

- `%D`
- `%{type}D`

    expanded to a timestamp according to ["strftime" in POSIX](https://metacpan.org/pod/POSIX#strftime) specifier
    `%Y-%m-%d %H:%M:%S.$u%z`, i.e. a timestamp that includes up to the
    microsecond (on platform where this is available, otherwise zeros will
    be used for sub-second values). By default the local time is used, but
    you can also pass a `type` specifier set to the string `utc`, in which
    case the UTC time will be used (via `gmtime`).

- `%{key}e`

    expanded according to what set via ["loglocal"](#loglocal)/["LOGLOCAL"](#loglocal). These two
    functions allow setting key-value pairs; the `key` is used to find the
    associated value, then the value is returned as-is if it's a simple
    defined scalar, otherwise if it is a sub reference it is invoked,
    otherwise the empty string is returned.

    In case a subroutine reference is set, it is called with the following
    parameters:

        $sub->($data, $op, $options);

    where `$data` is a reference to a hash that contains at least the
    `tod` key, associated to an array with the output of `gettimeofday`
    (if [Time::HiRes](https://metacpan.org/pod/Time%3A%3AHiRes) is available) or its equivalent (if [Time::HiRes](https://metacpan.org/pod/Time%3A%3AHiRes) is
    not available), `$op` is the letter `e` and `$options` is the string
    containing the `key` in braces (e.g. `{this-is-the-key}`).

As of release 1.4.0 all time-expansions in a single log refer to the
same time, i.e. if you specify the format string `%D %D` and you have
microsecond-level resolution, the two values in output will be the same
(as opposed to show two slightly different times, related to the
different expansion times of the `%D` specifier).

## Wrapping Log::Log4perl::Tiny

As of release 1.4.0, all expansion sequences that imply using `caller`
(namely `%C`, `%F`, `%l`, `%L`, `%M`, and `%T`) will honor
whatever you set for `$Log::Log4perl::caller_depth` or
`$Log::Log4perl::Tiny::caller_depth` (they're aliased), defaulting to
value `0`. You can basically increase this value by 1 for each wrapper
function that you don't want to appear from the _real_ caller's point
of view. In the following example, we have two nested wrappers, each of
which takes care to increase the value by 1 to be hidden:

    sub my_wrapper_logger {
       local $Log::Log4perl::Tiny::caller_depth =
          $Log::Log4perl::Tiny::caller_depth + 1; # ignore my_wrapper_logger
       INFO(@_);
    }

    # ... somewhere else...
    sub wrap_wrapper {
       local $Log::Log4perl::Tiny::caller_depth =
          $Log::Log4perl::Tiny::caller_depth + 1; # ignore wrap_wrapper
       my_wrapper_logger(@_);
    }

The _control_ variable is either `$Log::Log4perl::Tiny::caller_depth`
or `$Log::Log4perl::caller_depth`, as a matter of fact they are aliased
(i.e. changing either one will also change the other). This is
intentional to let you switch towards [Log::Log4perl](https://metacpan.org/pod/Log%3A%3ALog4perl) should you need
to upgrade to it.

See
["Using Log::Log4perl with wrapper functions and classes" in Log::Log4perl](https://metacpan.org/pod/Log%3A%3ALog4perl#Using-Log::Log4perl-with-wrapper-functions-and-classes)
for further information.

# INTERFACE

You have two interfaces at your disposal, the functional one (with all
the stealth logger functions) and the object-oriented one (with
explicit actions upon a logger object). Choose your preferred option.

## Functional Interface

The functional interface sports the following functions (imported
automatically when `:easy` is passed as import option except for
`LEVELID_FOR`, `LEVELNAME_FOR` and `LOGLEVEL`):

- `TRACE`
- `DEBUG`
- `INFO`
- `WARN`
- `ERROR`
- `FATAL`

    stealth logger functions, each emits a log at the corresponding level;

- `ALWAYS`

    emit log whatever the configured logging level (except `$DEAD`);

- `LEVELID_FOR`

    returns the identifier related to a certain level. The input level can be
    either a name or an identifier itself. Returns `undef` if it is neither.

    It can be used e.g. if you want to use ["log"](#log) but you only have the level
    name, not its identifier;

- `LEVELNAME_FOR`

    returns the name related to a certain level. The input level can be either
    a name or an identifier itself. Returns `undef` if it is neither.

- `LOGWARN`

    emit log at `WARN` level and then `warn()` it;

- `LOGDIE`

    emit log at `FATAL` level, `die()` and then exit (if `die()`
    didn't already exit);

- `LOGEXIT`

    emit log at `FATAL` level and then exit;

- `LOGCARP`

    emit log at `WARN` level and then call `Carp::carp()`;

- `LOGCLUCK`

    emit log at `WARN` level and then call `Carp::cluck()`;

- `LOGCROAK`

    emit log at `FATAL` level and then call `Carp::croak()`;

- `LOGCONFESS`

    emit log at `FATAL` level and then call `Carp::confess()`;

- `LOGLEVEL`

    (Not in [Log::Log4perl](https://metacpan.org/pod/Log%3A%3ALog4perl)) (Not imported with `:easy`)

    set the minimum log level for sending a log message to the output;

- `LOGLOCAL`

    (Not in [Log::Log4perl](https://metacpan.org/pod/Log%3A%3ALog4perl)) (Not imported with `:easy`) (As of 1.4.0)

    set a key-value pair useful for later expansion via code `%{key}e`. See
    ["loglocal"](#loglocal) below;

- `FILTER`

    (Not in [Log::Log4perl](https://metacpan.org/pod/Log%3A%3ALog4perl)) (Not imported with `:easy`) (As of 1.8.0)

    set a filter function to apply to every expanded message before it is
    printed. See ["filter"](#filter) below;

- `build_channels`

    (Not in [Log::Log4perl](https://metacpan.org/pod/Log%3A%3ALog4perl)) (Not imported with `:easy`)

    build multiple channels for emitting logs.

        my $channels = build_channels(@key_value_pairs);  # OR
        my $channels = build_channels(\@key_value_pairs);

    The input is a sequence of key-value pairs, provided either as
    a list or through a reference to an array containing them. They
    are not forced into a hash because the same key can appear
    multiple times to initialize multiple channels.

    The key specifies the type of the channel, while the value
    is specific to the key:

    - **fh**

        value is a filehandle (or anything that can be passed to the
        `print` function)

    - **sub**
    - **code**

        value is a reference to a subroutine. This will be called with
        two positional parameters: the message (already properly formatted)
        and a reference to the logger message

    - **channel**

        whatever can be passed to keys `fh` or to `sub`/`code` above

    - **file**
    - **file\_insecure**
    - **file\_create**
    - **file\_append**

        value is the file where log data should be sent.

        The first one is kept for compliance with Log::Log4perl::easy\_init's way
        of accepting a file. It eventually results in a two-arguments `open()`
        call, so that you can quickly set how you want to open the file:

            file => '>>/path/to/appended', # append mode
            file => '>/path/to/new-file',  # create mode

        You should avoid doing this, because it is intrinsically insecure and will
        yield an error message when running setuid:

            Insecure dependency in open while running setuid

        `file_insecure` is an alias to `file`, so that you can explicitly signal
        to the maintainer that you know what you're doing.

        `file_create` and `file_append` will use the three-arguments `open()`
        call and thus they don't trigger the error above when running setuid. As
        the respective names suggest the former creates the file from scratch
        (possibly deleting any previous file with the same path) while the latter
        opens the file in append mode.

## Object-Oriented Interface

The functional interface is actually based upon actions on
a pre-defined fixed instance of a `Log::Log4perl::Tiny` object,
so you can do the same with a logger object as well:

- `get_logger`

    this function gives you the pre-defined logger instance (i.e. the
    same used by the stealth logger functions described above).

- `new`

    if for obscure reasons the default logger isn't what you want, you
    can get a brand new object! The constructor accepts either a
    list of key-values or a reference to a hash, supporting the
    following keys:

    - **channels**

        set a list (through an array reference) of channels. See
        ["build\_channels"](#build_channels) for additional information.

    - **fh**

        see method `fh` below

    - **file**
    - **file\_insecure**
    - **file\_create**
    - **file\_append**

        set the file where the log data will be sent.

        The first one is kept for compliance with Log::Log4perl::easy\_init's way
        of accepting a file. It eventually results in a two-arguments `open()`,
        so you might want to take care when running in taint mode.

        See also ["build\_channels"](#build_channels) for additional information. This option takes
        precedence over `fh` described below.

    - **filter**
    - **format**
    - **layout**
    - **level**

        see [`easy_init()`](https://metacpan.org/pod/easy_init%28%29) and the methods below with the same
        name

    - **loglocal**

        pass a reference to a hash with key-value pairs to be set via
        ["loglocal"](#loglocal);

The methods you can call upon the object mimic the functional
interface, but with lowercase method names:

- `trace`
- `debug`
- `info`
- `warn`
- `error`
- `fatal`

    logging functions, each emits a log at the corresponding level;

- `is_trace`
- `is_debug`
- `is_info`
- `is_warn`
- `is_error`
- `is_fatal`
- `isTraceEnabled`
- `isDebugEnabled`
- `isInfoEnabled`
- `isWarnEnabled`
- `isErrorEnabled`
- `isFatalEnabled`

    log level test functions, each returns the status of the corresponding level;

- `always`

    emit log whatever the configured logging level;

- `logwarn`

    emit log at `WARN` level (if allowed) and `warn()` (always);

- `logdie`

    emit log at `FATAL` level, `die()` and then exit (if `die()`
    didn't already exit);

- `logexit`

    emit log at `FATAL` level and then exit;

- `logcarp`

    emit log at `WARN` level and then call `Carp::carp()`;

- `logcluck`

    emit log at `WARN` level and then call `Carp::cluck()`;

- `logcroak`

    emit log at `FATAL` level and then call `Carp::croak()`;

- `logconfess`

    emit log at `FATAL` level and then call `Carp::confess()`;

The main logging function is actually the following:

- `log`

    the first parameter is the log level, the rest is the message to log
    apart from references to subroutines that are first evaluated

- `emit_log`

    emit the message in the first positional parameter to all logging
    channels

Additionally, you have the following accessors:

- `level`

    get/set the minimum level for sending messages to the output stream.
    By default the level is set to `$INFO`.

- `fh`

    get/set the output channel.

    As an extention over [Log::Log4perl](https://metacpan.org/pod/Log%3A%3ALog4perl),
    you can also pass a reference to a subroutine or to an array.

    If you set a reference to a sub,
    it will be called with two parameters: the message
    that would be print and a reference to the logger object that is
    calling the sub. For example, if you simply want to collect the log
    messages without actually outputting them anywhere, you can do this:

        my @messages;
        get_logger()->fh(sub {
           my ($message, $logger) = @_;
           push @messages, $message;
           return;
        });

    If you set a reference to an array, each item inside will be used
    for log output; its elements can be either filehandles or sub
    references, used as described above. This is a handy way to set
    multiple output channels (it might be implemented externally
    through a proper subroutine reference of course).

    By default this parameter is set to be equal to `STDERR`.

- `filter`

    (Not in [Log::Log4perl](https://metacpan.org/pod/Log%3A%3ALog4perl)) (As of 1.8.0)

    get/set a filter CODE reference to be applied to every expanded message.
    The filter function is passed the message as its only argument.

    This can be e.g. useful in case a specific start-of-line character
    sequence is needed for multi-line messages:

        get_logger()->filter(sub {
           my $message = shift;
           $message =~ s{^}{# }gmxs; # pre-pend "# " to each line
           return $message;
        });

    Another use case might be taming some sensitive data:

        get_logger()->filter(sub {
           my $message = shift;
           $message =~ s{password<.*?>}{password<***>}gmxs;
           return $message;
        });

    It is anyway suggested to deal with these cases explicitly at the source
    and not as an afterthought (only). As an example, the regular expression
    in the example above will leak parts of passwords that contain the `>` character, and there might be other ways passwords are written too.

- `format`
- `layout`

    get/set the line formatting;

- `logexit_code`

    get/set the exit code to be used with `logexit()` (and
    `logdie()` as well if `die()` doesn't exit).

- `loglocal`

    get/set a local key-value pair for expansion with `%{key}e`.

    Always returns the previous value associated to the provided key,
    removing it:

        my $value = $logger->loglocal('some-key');
        # now, 'some-key' does not exist any more and has no value associated

    If you pass a value too, it will be set:

        $logger->loglocal(foo => 'bar');
        my $old = $logger->loglocal(foo => 'whatever');
        # $old is 'bar'
        # current value associated to foo is 'whatever'

# DEPENDENCIES

Runs on perl 5.8.0 on with no additional runtime requirements.

See `cpanfile` for additional requirements when testing and/or developing. In
particular, developing will require Log::Log4perl to perform a comparison
between the expansions of a few items related to `caller()`.

# BUGS AND LIMITATIONS

Please view/report any bugs or feature requests through Github at
[https://github.com/polettix/Log-Log4perl-Tiny/issues](https://github.com/polettix/Log-Log4perl-Tiny/issues).

# SEE ALSO

[Log::Log4perl](https://metacpan.org/pod/Log%3A%3ALog4perl) is one of the most useful modules I ever used, go check it!

# AUTHOR

Flavio Poletti <polettix@cpan.org>

# COPYRIGHT AND LICENSE

Copyright (C) 2010-2016, 2022 by Flavio Poletti <polettix@cpan.org>.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.
