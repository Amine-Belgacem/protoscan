#!/usr/bin/perl -w
use strict;
use warnings;
use MooseX::Declare;

class Socks4 extends IOSocket is mutable {
    use NetAddr::IP::Util qw(inet_aton);
    use Types qw(Exception);
    use Subtypes qw(IP Port);

    has target => (is => 'rw', isa => IP, required => 1);

    has targetPort => (is => 'rw', isa => Port, default => '80');

    has userID => (is => 'rw', isa => 'Str', predicate => 'hasUserID');

    has connectRequest => (
        is       => 'rw',
        isa      => 'Str',
        lazy     => 1,
        builder  => "setConnectRequest",
        init_arg => 'undef'
    );

    has connectResults => (
        is      => 'ro',
        isa     => 'HashRef',
        default => sub { {
                "\x5A" => 'granted',
                "\x5B" => 'Request rejected or failed',
                "\x5C" => 'Request rejected because SOCKS server'.
                    'cannot connect to identd on the client ',
                "\x5D" => 'Request rejected because the client '.
                    'program and identd report different user-ids'
            };
        }
    );

    has result => (
        is => 'rw',
        isa => 'Str',
        init_arg => 'undef'
    );

    has notSocks4 => (
        is       => 'ro',
        isa      => 'Str',
        default  => 'The server is not a Socks 4 server.'
    );

    method setConnectRequest {
        my $destIP = inet_aton($self->target);
        my $targetPort = pack('n', $self->targetPort);
        if ($self->hasUserID) {
            $self->connectRequest("\x04\x01".$targetPort.$destIP.$self->userID."\x00");
        }
        else { $self->connectRequest("\x04\x01".$targetPort.$destIP."\x00"); }
    }

    method isConnectReply(Str $reply) {
        if ($self->size($reply) == 8) {
            if (substr($reply, 0, 1) eq "\x00") {
                my $result = substr($reply, 1, 1);
                if (defined(${ $self->connectResults }{$result})) {
                    my $bndPort = unpack("n", substr($reply, 2, 2));
                    my $bndHost = substr($reply, 4, 4);
                    $bndHost = join('.', unpack("C*", $bndHost));
                    return 1 if (is_Port($bndPort) and is_IP($bndHost));
                }
            }
        }
        return 0
    }

    method CONNECT {
        my $reply = $self->interrogate($self->connectRequest, 8);
        if ($self->isConnectReply($reply)) {
            my $result = substr($reply, 1, 1);
            $self->result($result);
            return 1 if ($result eq "\x5A");
            Exception->throw(e => ${ $self->connectResults }{$result});
        }
        Exception->throw(e => $self->notSocks4);
    }
}