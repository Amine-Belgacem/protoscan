#!/usr/bin/perl -w
use strict;
use warnings;
use MooseX::Declare;

class Pool is mutable {
    use threads;
    use Thread::Queue;
    use Try::Tiny;
    use Types qw(Proxies Proxy Exception Timeout);
    use Subtypes qw(PosInt NatInt);
    use Probes;
    use JSON;
    use Table;

    has proxies => (is => 'rw', isa => Proxies);

    has maxThreads => (is => 'rw', isa => PosInt, default => 1);

    has protocols => (
        is      => 'rw',
        isa     => 'ArrayRef',
        default => sub {
            [ 'HTTPS', 'HTTP', 'Socks5', 'Socks4' ];
        }
    );

    has JSON => (is => 'rw', isa => 'Bool', default => 0);

    has jobs => (is => 'rw', isa => 'Thread::Queue');

    has timeout => (
        is      => 'rw',
        isa     => Timeout,
        default => sub { Timeout->new(giveup => 5, retries => 0) }
    );

    method toSTDOUT {
        shift; my ($ip, $port, $responseTime, $proto) = @_;
        STDOUT->flush();
        print Table->new()->toRow($ip.':'.$port, $responseTime, $proto);
    }

    method toJSON {
        shift; my ($ip, $port, $responseTime, $proto) = @_;
        my %response;
        my %protocols = map { $_ => 1 } @{$proto};
        foreach (@{ $self->protocols }) {
            if (exists($protocols{$_})) { $response{$_} = 1 }
            else { $response{$_} = 0 }
        }
        $response{'Response'} = $responseTime;
        my $json = JSON->new->allow_nonref;
        return $json->encode({ $ip.':'.$port => \%response });
    }

    method process {
        my @proxies;
        while (my $jobsLeft = $self->jobs->pending) {
            last if $jobsLeft == 0;
            my $current = $self->jobs->dequeue;
            try {
                my $probe = Probes->new(
                    proxy     => $current,
                    protocols => $self->protocols,
                    timeout   => $self->timeout
                );
                $probe->probe;

                my @proto;
                push @proto, 'HTTP'   if $probe->isHTTP;
                push @proto, 'HTTPS'  if $probe->isHTTPS;
                push @proto, 'Socks4' if $probe->isSocks4;
                push @proto, 'Socks5' if $probe->isSocks5;

                $self->toSTDOUT($current->IP, $current->Port,
                    $probe->responseTime, \@proto);

                if ($self->JSON) {
                    push @proxies,
                      $self->toJSON($current->IP, $current->Port,
                        $probe->responseTime, \@proto);
                }
                else {
                    push @proxies, Proxy->new($current->IP, $current->Port);
                }
            }
            catch {
                STDOUT->flush();
                print Table->new->toRow(
                    $current->IP.':'.$current->Port, '', $_->e);
            };
        }
        return @proxies;
    }

    method init {
        $self->jobs(Thread::Queue->new(@{ $self->proxies }));
        print Table->new()->getHeader."\n";

        my @threads = map {
            threads->create(sub { $self->process });
        } 1 .. $self->maxThreads;

        my @aliveProxies;
        foreach (@threads) {
            push @aliveProxies, $_->join;
        }
        return \@aliveProxies;
    }
}