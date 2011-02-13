NAME
====

Log::Log4perl::Tiny - mimic Log::Log4perl in one single module

SYNOPSIS
========

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
    
    # Want to send the output somewhere else?
    use IO::Handle;
    open my $fh, '>>', '/path/to/new.log';
    $fh->autoflush();
    $logger->fh($fh);
    
    # Change layout?
    $logger->layout('[%d %p] %m%n');
    # or, equivalently
    $logger->format('[%d %p] %m%n');

ALL THE REST
============

Want to know more? [See the module’s documentation](http://search.cpan.org/perldoc?Log::Log4perl::Tiny) to figure out
all the bells and whistles of this module!

Want to install the latest release? [Go fetch it on CPAN](http://search.cpan.org/dist/Log-Log4perl-Tiny/).

Want to contribute? [Fork it on GitHub](https://github.com/polettix/Log-Log4perl-Tiny).

That’s all folks!
