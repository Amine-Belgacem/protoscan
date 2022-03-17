#!/usr/bin/perl -w
use strict;
use warnings;
use MooseX::Declare;

role Connect {
    use Types qw(Timeout Exception);
    use Subtypes qw(NatInt);
    use Errno qw(ETIMEDOUT);
    use POSIX qw(strerror);
    use IO::Socket::INET;
    use Time::HiRes qw(time);
    use Math::Round;

    requires('proxy', '_socket');

    has timeout => (
        is      => 'rw',
        isa     => Timeout,
        default => sub { Timeout->new(giveup => 5, retries => 0) }
    );

    has WinReuseError => (
        is      => 'ro',
        isa     => 'Str',
        default => 'A connect request was made on an already connected socket.'
    );

    has responseTime => (
        is      => 'rw',
        isa     => NatInt,
        default => 0
    );

    method _connect {
        my $tryConnect = sub {
            my $_socket = IO::Socket::INET->new(
                Proto    => 'TCP',
                PeerAddr => $self->proxy->IP,
                PeerPort => $self->proxy->Port,
                Timeout  => $self->timeout->attempt,
                Blocking => 0
           );
            Exception->throw(e => $!) if ($! ne '' and
                (($! ne strerror(ETIMEDOUT) and $! ne $self->WinReuseError)));
            return $_socket;
        };

        my $previousTime = time;
        my $_socket      = $tryConnect->();
        if (defined($_socket)) {
            $self->_socket($_socket);
            $self->responseTime(round((time - $previousTime) * 1000));
            return $_socket;
        }
        if ($self->timeout->retries) {
            for (1 .. $self->timeout->retries) {
                $previousTime = time;
                $_socket      = $tryConnect->();
                if (defined($_socket)) {
                    $self->_socket($_socket);
                    $self->responseTime(
                        round((time - $previousTime) * 1000));
                    return $_socket;
                }
            }
        }

        Exception->throw(e => strerror(ETIMEDOUT));
    }
}

role Write {
    use Types qw(Timeout Exception);
    use Errno qw(EWOULDBLOCK ETIMEDOUT ENOTCONN);
    use POSIX qw(strerror);
    use IO::Select;

    requires('_socket', 'size', 'error');

    method _write(Str $message) {
        my $tryWrite = sub {
            my $selector = IO::Select->new($self->_socket);
            if ($selector->can_write( $self->timeout->attempt)) {
                my $written = $self->_socket->syswrite($message);
                if ($! ne '') {
                    return undef if ($! eq strerror(EWOULDBLOCK) or 
                        $! eq strerror(ETIMEDOUT));
                    Exception->throw(e => $!);
                }
                Exception->throw(e => $!) unless $self->_socket->connected;
                return $written if ($written == $self->size($message));
            }
            return undef;
        };

        my $written = $tryWrite->();
        return $written if defined($written);
        if ($self->timeout->retries) {
            for (1 .. $self->timeout->retries) {
                $written = $tryWrite->();
                return $written if defined($written);
            }
        }

        Exception->throw(e => strerror(ETIMEDOUT));
    }
}

role Read {
    use Types qw(Timeout Exception);
    use Errno qw(EWOULDBLOCK ETIMEDOUT EAGAIN);
    use POSIX qw(strerror);
    use IO::Select;

    requires('_socket', 'size', 'error');

    method _read(ScalarRef $buffer, Int $limit) {
        my $tryRead = sub {
            my $selector = IO::Select->new($self->_socket);
            if ($selector->can_read($self->timeout->attempt)) {
                my $read = $self->_socket->sysread($$buffer, $limit);
                if ($! ne '') {
                    return undef if ($! eq strerror(EWOULDBLOCK)
                        or $! eq strerror(ETIMEDOUT));
                    Exception->throw(e => $!);
                }
                return $read if ($read >= 0);
            }
            return undef;
        };

        my $read = $tryRead->();
        return $read if (defined($read));
        if ($self->timeout->retries) {
            for (1 .. $self->timeout->retries) {
                $read = $tryRead->();
                return $read if (defined($read));
            }
        }

        Exception->throw(e => strerror(ETIMEDOUT));
    }
}

class IOSocket with (Connect, Read, Write) is mutable {
    use Types qw(Timeout Proxy);
    use Errno qw(EWOULDBLOCK ENOTCONN);
    use IO::Socket::INET;
    use bytes;

    has proxy => (is => 'rw', isa => Proxy, required => 1);

    has _socket => (
        is  => 'rw',
        isa => 'IO::Socket::INET',
        init_arg => 'undef'
    );

    has error => (
        is       => 'ro',
        isa      => 'Str',
        default  => 'No socket has been created.'
    );

    method size(Str $string) { return length($string) }

    method interrogate($request, $limit) {
        $self->_write($request);
        my $buffer;
        $self->_read(\$buffer, $limit);
        return $buffer;
    }

    method BUILD { $self->_connect }
}