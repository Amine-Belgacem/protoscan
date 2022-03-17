#!/usr/bin/perl -w
use strict;
use warnings;
use MooseX::Declare;

class Types {
    use MooseX::Types::Moose qw(ArrayRef);
    use MooseX::Types -declare => [qw(Proxy Proxies Timeout Exception)];

    class ProxyObj is mutable {
        use Subtypes qw(IP Port);

        has IP   => (is => 'rw', isa => IP,   required => 1);
        
        has Port => (is => 'rw', isa => Port, required => 1);

        around BUILDARGS (ClassName $self: @args) {
            return $self->SUPER::BUILDARGS(IP => $args[0], Port => $args[1])
              if (@args == 2);
            return $self->SUPER::BUILDARGS(@args);
        }
    }

    class TimeoutObj is mutable {
        use Subtypes qw(NatInt PosInt);

        has giveup => (
            is       => 'rw',
            isa      => PosInt,
            required => 1,
            default  => 5,
            trigger  => \&setAttempt
        );

        has retries => (
            is      => 'rw',
            isa     => NatInt,
            default => 0,
            trigger => \&setAttempt
        );

        has attempt => (is => 'rw', isa => 'Num', init_arg => 'undef');

        method setAttempt {
            $self->attempt( $self->giveup / $self->retries )
              if ($self->retries > 1);
            $self->attempt($self->giveup)
              unless ($self->retries);
        }

        around BUILDARGS (ClassName $self: @args) {
            return $self->SUPER::BUILDARGS(giveup => $args[0])
              if (@args == 1);
            return $self->SUPER::BUILDARGS(
                giveup  => $args[0],
                retries => $args[1]
            ) if (@args == 2);
            return $self->SUPER::BUILDARGS(@args);
        }
    }

    class ExceptionObj with Throwable {
        has e => (is => 'rw', isa => 'Str')
    }

    class_type Proxy, { class => 'ProxyObj' };
    subtype Proxies, as ArrayRef [Proxy];

    class_type Timeout,   { class => 'TimeoutObj' };
    class_type Exception, { class => 'ExceptionObj' };
}