#!/usr/bin/perl -w
use strict;
use warnings;
use MooseX::Declare;

role NegociateAuthMethod {
    use Subtypes qw(AuthMethod);
    use Types qw(Exception);
    use MooseX::Types::Moose qw(ArrayRef);

    requires('interrogate', 'notSocks5', 'size');

    has methods => (
        is      => 'rw',
        isa     => ArrayRef [AuthMethod],
        default => sub { ["\x00"] },
        trigger => \&setNegociationRequest
    );

    has negociationRequest => (
        is      => 'rw',
        isa     => 'Str',
        default => sub { "\x05\x01\x00" }
    );

    has selectedMethod => (is => 'rw', isa => AuthMethod);

    has unsupportedMethod => (
        is       => 'ro',
        isa      => 'Str',
        default  => 'Unsupported authentification method'
    );

    method setNegociationRequest {
        my $ver      = "\x05";
        my $nMethods = scalar(@{ $self->methods });
        my $methods  = join("", @{ $self->methods });
        $self->negociationgRequest($ver . $nMethods . $methods);
    }

    method negociate {
        my $reply = $self->interrogate($self->negociationRequest, 5000);
        if ($self->isNegociationReply($reply)) {
            my $method = substr($reply, 1, 1);
            $self->selectedMethod($method);
            my %methods = map { $_ => 1 } @{  $self->methods };
            return if (exists($methods{$method}));
            Exception->throw(e => $self->unsupportedMethod);
        }
        Exception->throw(e => $self->notSocks5);
    }

    method isNegociationReply(Str $reply) {
        if ($self->size($reply) == 2) {
            return 1 if (substr( $reply, 0, 1) eq "\x05" );
        }
        return 0;
    }
}

role CONNECT {
    use NetAddr::IP::Util qw(inet_aton ipv6_ntoa);
    use Types qw(Exception);
    use Subtypes qw(IP Port Domain);
    use Try::Tiny;

    requires qw(interrogate notSocks5 size target targetPort);

    has connectRequest => (
        is      => 'rw',
        isa     => 'Str',
        lazy    => 1,
        builder => 'setConnectRequest'
    );

    has connectResults => (
        is      => 'ro',
        isa     => 'HashRef[Str]',
        default => sub {
            {
                "\x00" => 'succeeded',
                "\x01" => 'general SOCKS server failure',
                "\x02" => 'connection not allowed by ruleset',
                "\x03" => 'Network unreachable',
                "\x04" => 'Host unreachable',
                "\x05" => 'Connection refused',
                "\x06" => 'TTL expired',
                "\x07" => 'Command not supported',
                "\x08" => 'Address type not supported',
                "\x09" => 'unassigned'
            };
        },
        init_arg => 'undef'
    );

    method setConnectRequest {
        my $destIP   = inet_aton($self->target);
        my $targetPort = pack('n', $self->targetPort);
        my $request  = "\x05\x01\x00\x01" . $destIP . $targetPort;
    }

    method CONNECT {
        my $reply = $self->interrogate($self->connectRequest, 259);
        if ($self->isConnectReply($reply)) {
            my $result = substr($reply, 1, 1);
            return 1 if ($result eq "\x00");
            Exception->throw(e => ${ $self->connectResults }{$result})
              if defined(${ $self->connectResults }{$result});
            Exception->throw(e => ${ $self->connectResults }{"\x09"});
        }
        Exception->throw(e => $self->notSocks5);
    }

    method isConnectReply(Str $reply) {
        my $replySize = $self->size($reply);
        if ($self->size($reply) >= 10 and $replySize <= 260) {
            my $ver      = substr($reply, 0, 1);
            my $reserved = substr($reply, 2, 1);
            if ($ver eq "\x05" and $reserved eq "\x00") {
                my $atype = substr($reply, 3, 1);
                if ($atype eq "\x01") {
                    my $bndAddr = substr($reply, 4, 4);
                    $bndAddr = join('.', unpack("C*", $bndAddr));
                    my $bndPort = unpack("n", substr($reply, 8, 2));
                    return 1 if (is_IP($bndAddr) and is_Port($bndPort));
                }
                if ($atype eq "\x03") {
                    my $bndHostLen = unpack("C", substr($reply, 4, 1)) ;
                    my $bndAddr = substr($reply, 5, $bndHostLen);
                    my $bndPort =
                      unpack("n", substr($reply, $bndHostLen + 5, 2));
                    return 1 if (is_Domain($bndAddr) and is_Port($bndPort));
                }
                if ($atype eq "\x04") {
                    my $bndAddr = substr($reply, 4, 16);
                    my $bndPort = unpack("n", substr($reply, 20, 2));
                    my $bndAddrIPv6;
                    try { $bndAddrIPv6 = ipv6_ntoa($bndAddr) };
                    return 1 if (defined($bndAddrIPv6) and is_Port($bndPort));
                }
            }
        }
        return 0;
    }
}

class Socks5 with (NegociateAuthMethod, CONNECT) extends IOSocket is mutable {
    use Subtypes qw(IP Port);

    has target => (is => 'rw', isa => IP, required => 1);
    
    has targetPort => (is => 'rw', isa => Port, default => '80');

    has notSocks5 => (
        is      => 'ro',
        isa     => 'Str',
        default => 'The server is not a Socks 5 server'
    );

    method noAuthConnect {
        $self->negociate;
        $self->CONNECT if ($self->selectedMethod eq "\x00");
    }
}