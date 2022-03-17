#!/usr/bin/perl -w
use strict;
use warnings;
use MooseX::Declare;

class Proxter is mutable {
    use lib './lib';
    use Types qw(Proxies Timeout Exception Proxy);
    use Try::Tiny;
    use IOFile;
    use Pool;
    use Getopt;

    has getopt => (is => 'rw', isa => 'Getopt');

    has proxies => (is => 'rw', isa => Proxies);

    has IOFile => (is => 'rw', isa => 'IOFile');

    has messages => (
        is      => 'ro',
        default => sub {{
            load       => '> Loading servers from file...',
            loadEnd    => 'Proxy server has been loaded.',
            process    => '> Processing...',
            export     => 'Alive proxies has been exported. Finished.',
            leftMargin => '  ',
            seperator  => ' ',
        }}
	);

    method loadProxies {
        print $self->messages->{'load'}."\n";
        try {
            $self->IOFile(
                IOFile->new(
                    importPath => $self->getopt->input,
                    exportPath => $self->getopt->output
				)
			);
            my $proxies = $self->IOFile->importProxies();
            $self->proxies($proxies);

            print $self->messages->{'leftMargin'}.
            	scalar(@{ $self->proxies }).
            	$self->messages->{'seperator'}.
            	$self->messages->{'loadEnd'}."\n";
        }
        catch { die $_->e }
    }

    method getprotocols {
        my @protocols;
        push @protocols, 'HTTP'   if $self->getopt->http;
        push @protocols, 'HTTPS'  if $self->getopt->https;
        push @protocols, 'Socks4' if $self->getopt->socks4;
        push @protocols, 'Socks5' if $self->getopt->socks5;
        return \@protocols if @protocols;
        return [ 'HTTPS', 'HTTP', 'Socks5', 'Socks4' ];
    }

    method process {
        print $self->messages->{'process'}."\n";
        my $pool = Pool->new(
            proxies       => $self->proxies,
            protocols     => $self->getprotocols,
            maxThreads    => $self->getopt->threads,
            JSON          => $self->getopt->json,
            timeout       => Timeout->new(
                giveup  => $self->getopt->giveup,
                retries => $self->getopt->retries
			)
		);

        if ($self->getopt->json) {
            $self->IOFile->JSON(1);
            $self->IOFile->JSONProxies($pool->init);
        }
        else { $self->IOFile->proxies($pool->init) }
    }

    method exportProxies {
        $self->IOFile->exportProxies();
        my $alive = 0;
        if ($self->getopt->json) {
            $alive = scalar(@{ $self->IOFile->JSONProxies });
        }
        else { $alive = scalar(@{ $self->IOFile->proxies }); }

        print 
        	"\n".
        	$self->messages->{'leftMargin'}.
        	$alive.
        	$self->messages->{'seperator'}.
        	$self->messages->{'export'}."\n\n";
    }

    method run {
        $self->getopt(Getopt->new_with_options());
        $self->loadProxies();
        $self->process();
        $self->exportProxies();
    }
}

Proxter->new->run();