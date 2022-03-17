#!/usr/bin/perl -w
use strict;
use warnings;
use MooseX::Declare;

class HTTP extends IOSocket is mutable {
    use Types qw(Exception);
    use Subtypes qw(IP);
    use HTTP::Status;

    has target => (is => 'rw', isa => IP, required => 1);

    has targetURL => ( 
        is => 'rw', 
        isa => 'Str',
        default => 'http://www.google.com:80'
    );

    has getRequest => (
        is       => 'rw',
        isa      => 'Str',
        lazy     => 1,
        builder  => 'setGetRequest',
        init_arg => 'undef'
    );

    has notHTTP => (
        is       => 'ro',
        isa      => 'Str',
        default  => 'The server is not a HTTP server.'
    );

    method setGetRequest {
        my $CRLF = "\r\n";
        $self->getRequest(
            'GET '.$self->targetURL.' HTTP/1.1'.$CRLF.
            'Host: '.$self->target.$CRLF.$CRLF
        )
    }

    method isGetReply(Str $reply) {
        if (length($reply) >= 12) {
            if (substr($reply, 0, 8) eq 'HTTP/1.1') {
                my $statusCode = substr($reply, 9, 3);
                return 1 if defined(status_message($statusCode));
            }
        }
        return 0;
    }

    method GET {
        my $reply = $self->interrogate($self->getRequest, 12);
        if ($self->isGetReply($reply)) {
            my $statusCode = substr($reply, 9, 3);
            return 1 if is_success($statusCode);
            Exception->throw(e => status_message($statusCode));
        }
        Exception->throw(e => $self->notHTTP);
    }
}