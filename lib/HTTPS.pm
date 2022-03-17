#!/usr/bin/perl -w
use strict;
use warnings;
use MooseX::Declare;

class HTTPS extends IOSocket is mutable {
    use Types qw(Exception);
    use Subtypes qw(IP Port);
    use HTTP::Status;

    has target => (is => 'rw', isa => IP, required => 1);

    has targetPort => (is => 'rw', isa => Port, default => '443');

    has connectRequest => (
        is       => 'rw',
        isa      => 'Str',
        lazy     => 1,
        builder  => "setConnectRequest",
        init_arg => 'undef'
    );

    has notHTTPS => (
        is       => 'ro',
        isa      => 'Str',
        default  => 'The server is not a HTTPS server.'
    );

    method setConnectRequest {
        my $CRLF = "\r\n";
        $self->connectRequest(
            'CONNECT '.$self->target.':'.$self->targetPort.' HTTP/1.1'.$CRLF.
            'Host: '.$self->target.$CRLF.$CRLF
        )
    }

    method isConnectReply(Str $reply) {
        if (length($reply) >= 12) {
            if (substr($reply, 0, 8) eq 'HTTP/1.1') {
                my $statusCode = substr($reply, 9, 3);
                return 1 if defined(status_message($statusCode));
            }
        }
        return 0;
    }

    method CONNECT {
        my $reply = $self->interrogate($self->connectRequest, 12);
        if ($self->isConnectReply($reply)) {
            my $statusCode = substr($reply, 9, 3);
            return 1 if is_success($statusCode);
            Exception->throw(e => status_message($statusCode));
        }
        Exception->throw(e => $self->notHTTPS);
    }
}