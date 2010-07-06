package Log::Log4perl::Tiny;

our $VERSION = '0.1';

use warnings;
use strict;

our ($ALL, $TRACE, $DEBUG, $INFO, $WARN, $ERROR, $FATAL, $OFF);
my ($_instance, %name_of, %format_for);

sub import {
   my ($exporter, @list) = @_;
   my ($caller, $file, $line) = caller();
   no strict 'refs';

   if (grep { $_ eq ':full_or_fake' } @list) {
      @list = grep { $_ ne ':full_or_fake' } @list;
      eval "
         package $caller;
         use Log::Log4perl (\@list);
         1;
      " and return;
      unshift @list, ':fake';
   } ## end if (grep { $_ eq ':full_or_fake'...

   my %done;
 ITEM:
   for my $item (@list) {
      next ITEM if $done{$item};
      $done{$item} = 1;
      if ($item =~ /^[a-zA-Z]/mxs) {
         *{$caller . '::' . $item} = \&{$exporter . '::' . $item};
      }
      elsif ($item eq ':levels') {
         for my $level (qw( ALL TRACE DEBUG INFO WARN ERROR FATAL OFF )) {
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
         $INC{'Log/Log4perl.pm'} = __FILE__;
         *Log::Log4perl::import = sub { };
         *Log::Log4perl::easy_init = sub {
            my ($pack, $conf) = @_;
            $_instance = __PACKAGE__->new($conf) if ref $conf;
            if (ref $conf) {
               $_instance->level($conf->{level}) if exists $conf->{level};
               $_instance->format($conf->{format})
                 if exists $conf->{format};
               $_instance->format($conf->{layout})
                 if exists $conf->{layout};
            } ## end if (ref $conf)
            elsif (defined $conf) {
               $_instance->level($conf);
            }
         };
      } ## end elsif ($item =~ /\A : (mimic | mask | fake) \z/mxs)
      elsif ($item eq ':easy') {
         push @list, qw( :levels :subs :fake );
      }
   } ## end for my $item (@list)

   return;
} ## end sub import

sub new {
   my $package = shift;
   my %args = ref($_[0]) ? %{$_[0]} : @_;

   $args{format} = $args{layout} if exists $args{layout};

   if (exists $args{file}) {
      open my $fh, $args{file}
        or die "open('$args{file}'): $!";
      $args{fh} = $fh;
   }

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

sub get_logger {
   return $_instance ||= __PACKAGE__->new();
}

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

sub log {
   my $self = shift;

   my $level = shift;
   return if $level > $self->{level};

   my %data_for = (
      level   => $level,
      message => \@_,
   );
   printf {$self->{fh}} $self->{format},
     map { $format_for{$_}[1]->(\%data_for); } @{$self->{args}};

   return;
} ## end sub log

sub ALWAYS { return $_instance->log($OFF, @_); }

sub _exit {
   my $self = shift || $_instance;
   exit $self->{logexit_code} if defined $self->{logexit_code};
   exit 1;
}

sub logwarn {
   my $self = shift;
   $self->warn(@_);
   CORE::warn(@_);
   $self->_exit();
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

BEGIN {

   # %format_for idea from Log::Tiny by J. M. Adler
   my $last_log = $^T;
   %format_for = (    # specifiers according to Log::Log4perl
      c => [s => sub { 'main' }],
      C => [s => sub { (caller(4))[0] },],
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
      m =>
        [s => sub { join((defined $, ? $, : ''), @{shift->{message}}) },],
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
      *{__PACKAGE__ . '::' . lc($name)} = sub {
         my $self = shift;
         return $self->log($$name, @_);
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

   for my $accessor (qw( level fh )) {
      *{__PACKAGE__ . '::' . $accessor} = sub {
         my $self = shift;
         $self = $_instance unless ref $self;
         $self->{$accessor} = shift if @_;
         return $self->{$accessor};
      };
   } ## end for my $accessor (qw( level fh ))

   my $index = 0;
   for my $name (qw( OFF FATAL ERROR WARN INFO DEBUG TRACE ALL )) {
      $name_of{$$name = $index++} = $name;
   }

   get_logger();    # initialises $_instance;
} ## end BEGIN

1;                  # Magic true value required at end of module
__END__

=head1 NAME

Log::Log4perl::Tiny - [Una riga di descrizione dello scopo del modulo]

=head1 VERSION

This document describes Log::Log4perl::Tiny version 0.0.1. Most likely, this
version number here is outdate, and you should peek the source.


=head1 SYNOPSIS

   use Log::Log4perl::Tiny;

=for l'autore, da riempire:
   Qualche breve esempio con codice che mostri l'utilizzo più comune.
   Questa sezione sarà quella probabilmente più letta, perché molti
   utenti si annoiano a leggere tutta la documentazione, per cui
   è meglio essere il più educativi ed esplicativi possibile.


=head1 DESCRIPTION

=for l'autore, da riempire:
   Fornite una descrizione completa del modulo e delle sue caratteristiche.
   Aiutatevi a strutturare il testo con le sottosezioni (=head2, =head3)
   se necessario.


=head1 INTERFACE 

=for l'autore, da riempire:
   Scrivete una sezione separata che elenchi i componenti pubblici
   dell'interfaccia del modulo. Questi normalmente sono formati o
   dalle subroutine che possono essere esportate, o dai metodi che
   possono essere chiamati su oggetti che appartengono alle classi
   fornite da questo modulo.


=head1 DIAGNOSTICS

=for l'autore, da riempire:
   Elencate qualunque singolo errore o messaggio di avvertimento che
   il modulo può generare, anche quelli che non "accadranno mai".
   Includete anche una spiegazione completa di ciascuno di questi
   problemi, una o più possibili cause e qualunque rimedio
   suggerito.


=over

=item C<< Error message here, perhaps with %s placeholders >>

[Descrizione di un errore]

=item C<< Another error message here >>

[Descrizione di un errore]

[E così via...]

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for l'autore, da riempire:
   Una spiegazione completa di qualunque sistema di configurazione
   utilizzato dal modulo, inclusi i nomi e le posizioni dei file di
   configurazione, il significato di ciascuna variabile di ambiente
   utilizzata e proprietà che può essere impostata. Queste descrizioni
   devono anche includere dettagli su eventuali linguaggi di configurazione
   utilizzati.
  
Log::Log4perl::Tiny requires no configuration files or environment variables.


=head1 DEPENDENCIES

=for l'autore, da riempire:
   Una lista di tutti gli altri moduli su cui si basa questo modulo,
   incluse eventuali restrizioni sulle relative versioni, ed una
   indicazione se il modulo in questione è parte della distribuzione
   standard di Perl, parte della distribuzione del modulo o se
   deve essere installato separatamente.

None.


=head1 INCOMPATIBILITIES

=for l'autore, da riempire:
   Una lista di ciascun modulo che non può essere utilizzato
   congiuntamente a questo modulo. Questa condizione può verificarsi
   a causa di conflitti nei nomi nell'interfaccia, o per concorrenza
   nell'utilizzo delle risorse di sistema o di programma, o ancora
   a causa di limitazioni interne di Perl (ad esempio, molti dei
   moduli che utilizzano filtri al codice sorgente sono mutuamente
   incompatibili).

None reported.


=head1 BUGS AND LIMITATIONS

=for l'autore, da riempire:
   Una lista di tutti i problemi conosciuti relativi al modulo,
   insime a qualche indicazione sul fatto che tali problemi siano
   plausibilmente risolti in una versione successiva. Includete anche
   una lista delle restrizioni sulle funzionalità fornite dal
   modulo: tipi di dati che non si è in grado di gestire, problematiche
   relative all'efficienza e le circostanze nelle quali queste possono
   sorgere, limitazioni pratiche sugli insiemi dei dati, casi
   particolari che non sono (ancora) gestiti, e così via.

No bugs have been reported.

Please report any bugs or feature requests through http://rt.cpan.org/


=head1 AUTHOR

Flavio Poletti  C<< <flavio [at] polettix [dot] it> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2010, Flavio Poletti C<< <flavio [at] polettix [dot] it> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl 5.8.x itself. See L<perlartistic>
and L<perlgpl>.

Questo modulo è software libero: potete ridistribuirlo e/o
modificarlo negli stessi termini di Perl 5.8.x stesso. Vedete anche
L<perlartistic> e L<perlgpl>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

=head1 NEGAZIONE DELLA GARANZIA

Poiché questo software viene dato con una licenza gratuita, non
c'è alcuna garanzia associata ad esso, ai fini e per quanto permesso
dalle leggi applicabili. A meno di quanto possa essere specificato
altrove, il proprietario e detentore del copyright fornisce questo
software "così com'è" senza garanzia di alcun tipo, sia essa espressa
o implicita, includendo fra l'altro (senza però limitarsi a questo)
eventuali garanzie implicite di commerciabilità e adeguatezza per
uno scopo particolare. L'intero rischio riguardo alla qualità ed
alle prestazioni di questo software rimane a voi. Se il software
dovesse dimostrarsi difettoso, vi assumete tutte le responsabilità
ed i costi per tutti i necessari servizi, riparazioni o correzioni.

In nessun caso, a meno che ciò non sia richiesto dalle leggi vigenti
o sia regolato da un accordo scritto, alcuno dei detentori del diritto
di copyright, o qualunque altra parte che possa modificare, o redistribuire
questo software così come consentito dalla licenza di cui sopra, potrà
essere considerato responsabile nei vostri confronti per danni, ivi
inclusi danni generali, speciali, incidentali o conseguenziali, derivanti
dall'utilizzo o dall'incapacità di utilizzo di questo software. Ciò
include, a puro titolo di esempio e senza limitarsi ad essi, la perdita
di dati, l'alterazione involontaria o indesiderata di dati, le perdite
sostenute da voi o da terze parti o un fallimento del software ad
operare con un qualsivoglia altro software. Tale negazione di garanzia
rimane in essere anche se i dententori del copyright, o qualsiasi altra
parte, è stata avvisata della possibilità di tali danneggiamenti.

Se decidete di utilizzare questo software, lo fate a vostro rischio
e pericolo. Se pensate che i termini di questa negazione di garanzia
non si confacciano alle vostre esigenze, o al vostro modo di
considerare un software, o ancora al modo in cui avete sempre trattato
software di terze parti, non usatelo. Se lo usate, accettate espressamente
questa negazione di garanzia e la piena responsabilità per qualsiasi
tipo di danno, di qualsiasi natura, possa derivarne.

=head1 SEE ALSO

=for l'autore, da riempire:
   Una lista di moduli/link da considerare per completare le funzionalità
   del modulo, o per trovarne di alternative.

=cut
