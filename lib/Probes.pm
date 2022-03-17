#!/usr/bin/perl -w
use strict;
use warnings;
use MooseX::Declare;

class Probes is mutable {
    use Try::Tiny;
    use Subtypes qw(IP PosInt NatInt);
    use Types qw(Exception Timeout Proxy);
    use Errno qw(ETIMEDOUT);
    use POSIX qw(strerror);
    use NetAddr::IP::Util qw(inet_ntoa);
    use HTTP;
    use HTTPS;
    use Socks4;
    use Socks5;

    has proxy => (is => 'rw', isa => Proxy, required => 1);

    has target => (is => 'rw', isa => IP);

    has protocols => (
        is      => 'rw',
        isa     => 'ArrayRef',
        default => sub {
            [ 'HTTP', 'HTTPS', 'Socks4', 'Socks5' ];
        }
    );

    has isHTTP => (is => 'rw', isa => 'Bool', default => 0);

    has isHTTPS => (is => 'rw', isa => 'Bool', default => 0);

    has isSocks4 => (is => 'rw', isa => 'Bool', default => 0);

    has isSocks5 => (is => 'rw', isa => 'Bool', default => 0);

    has responseTime => (is => 'rw', isa => NatInt, default => 0);

    has timeout => (
        is      => 'rw',
        isa     => Timeout,
        default => sub { Timeout->new(giveup => 5, retries => 0) }
    );

    has timedout => (
        is      => 'ro',
        isa     => 'Str',
        default => sub { 'Timed-out' }
    );

    has unidentified => (
        is      => 'ro',
        isa     => 'Str',
        default => sub { 'Unidentified' }
    );

    has networkError => (
        is      => 'ro',
        isa     => 'Str',
        default => 'Network Issue'
    );

    method setTarget {
        my $target = gethostbyname('www.google.com');
        Exception->throw(e => $self->networkError) if !$target;
        $self->target(inet_ntoa($target));
    };

    method isUnidentified {
        return ( $self->isHTTP == 0 and $self->isHTTPS == 0
              and $self->isSocks4 == 0
              and $self->isSocks5 == 0);
    };

    method probe {
        $self->setTarget() if !$self->target;
        foreach my $type (@{ $self->protocols }) {
            try {
                if ($type eq 'HTTP') {
                    my $HTTPProbe = HTTP->new(
                        proxy   => $self->proxy,
                        timeout => $self->timeout,
                        target  => $self->target
                    );
                    $self->isHTTP($HTTPProbe->GET);
                    $self->responseTime($HTTPProbe->responseTime)
                      if $self->isHTTP;
                }
                if ($type eq 'HTTPS') {
                    my $HTTPSProbe = HTTPS->new(
                        proxy   => $self->proxy,
                        timeout => $self->timeout,
                        target  => $self->target
                    );
                    $self->isHTTPS($HTTPSProbe->CONNECT);
                    $self->responseTime($HTTPSProbe->responseTime)
                      if $self->isHTTPS;
                }
                if ($type eq 'Socks4') {
                    my $Socks4Probe = Socks4->new(
                        proxy   => $self->proxy,
                        timeout => $self->timeout,
                        target  => $self->target
                    );
                    $self->isSocks4($Socks4Probe->CONNECT);
                    $self->responseTime($Socks4Probe->responseTime)
                      if $self->isSocks4;
                }
                if ($type eq 'Socks5') {
                    my $Socks5Probe = Socks5->new(
                        proxy   => $self->proxy,
                        timeout => $self->timeout,
                        target  => $self->target
                    );
                    $self->isSocks5($Socks5Probe->noAuthConnect);
                    $self->responseTime($Socks5Probe->responseTime)
                      if $self->isSocks5;
                }
            }
            catch {
                Exception->throw(e => $self->timedout)
                  if ($self->isUnidentified and $_->e eq strerror(ETIMEDOUT));
            };
        }
        Exception->throw(e => $self->unidentified) if $self->isUnidentified;
        return 1;
    }
}