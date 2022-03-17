#!/usr/bin/perl -w
use strict;
use warnings;
use MooseX::Declare;

role ImportProxies {
    use Try::Tiny;
    use autodie qw(:file);
    use Types qw(Proxy Exception);

    has importPath => (
        is       => 'rw',
        isa      => 'Str',
        required => 1,
        trigger  => \&canOpenFile
   );

    has linesCount => (
        is       => 'rw',
        isa      => 'Int',
        default  => 0,
        init_arg => 'undef'
   );

    has importCount => (
        is       => 'rw',
        isa      => 'Int',
        default  => 0,
        init_arg => 'undef'
   );

    has importError => (
        is       => 'ro',
        isa      => 'Str',
        default  => 'No proxies found in the specified file.'
   );

    method canOpenFile {
        try {
            open(FILE, '<', $self->importPath);
            close(FILE);
        }
        catch {
            Exception->throw(e => $_->format_default())
        };
    }

    method importProxies {
        my $disjoinIPandPort = sub {
            my ($proxy, $sep) = @_;
            my ($ip, $port, $indSep);

            $indSep = index($proxy, $sep);
            $ip     = substr($proxy, 0, $indSep);
            $port   = substr($proxy, $indSep + 1, length($proxy));

            return Proxy->new($ip, $port);
        };

        my ($fileHandle, @fileLines, $lines);
        my $ipRegex   = $Subtypes::IPRegex;
        my $portRegex = $Subtypes::PortRegex;
        my $sep       = ':';

        open($fileHandle, '<', $self->importPath);
        while (<$fileHandle>) {
            while ($_ =~ /(\b$ipRegex$sep$portRegex\b)/g) {
                push @fileLines, $disjoinIPandPort->($1, $sep);
            }
            $lines++;
        }
        close($fileHandle);

        Exception->throw(e => $self->importError) unless (@fileLines);

        $self->linesCount($lines);
        $self->importCount(scalar(@fileLines));

        return \@fileLines;
    }
}

role ExportProxies {
    use Try::Tiny;
    use autodie qw(:file);
    use Types qw(Proxies Exception);
    use JSON;

    has exportPath => (
        is       => 'rw',
        isa      => 'Str',
        required => 1
   );

    has proxies => (is => 'rw', isa => Proxies);

    has JSONProxies => (is => 'rw', isa => 'ArrayRef');

    has JSON => (is => 'rw', isa => 'Bool', default => 0);

    has exportError => (
        is       => 'ro',
        isa      => 'Str',
        default  => 'No proxies to export.'
   );

    method writeJSON {
        my $fileHandle;
        my $i = 0;
        open($fileHandle, '>', $self->exportPath);
        print $fileHandle '[';
        foreach (@{ $self->JSONProxies }) {
            $i++;
            print $fileHandle $_;
            print $fileHandle ',' if $i != @{ $self->JSONProxies };
        }
        print $fileHandle ']';
        close($fileHandle);
        return 1;
    }

    method writeProxies {
        my $joinIPandPort = sub {
            my $proxy = shift;
            my $sep   = shift;
            return $proxy->IP . $sep . $proxy->Port;
        };

        my ($fileHandle, $proxyLine);
        my $sep     = ':';
        my $lineEnd = "\n";

        open($fileHandle, '>', $self->exportPath);
        foreach (@{ $self->proxies }) {
            $proxyLine = $joinIPandPort->($_, $sep);
            $proxyLine = $proxyLine . $lineEnd;
            print $fileHandle $proxyLine;
        }
        close($fileHandle);

        return 1;
    }

    method exportProxies {
        Exception->throw(e => $self->exportError)
          if (!defined($self->proxies) && !defined($self->JSONProxies));
        if ($self->JSON) { $self->writeJSON() }
        else { $self->writeProxies }
    }
}

class IOFile with (ImportProxies, ExportProxies) is mutable;