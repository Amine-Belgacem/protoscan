#!/usr/bin/perl -w
use strict;
use warnings;
use MooseX::Declare;

class Subtypes {
    use MooseX::Types::Moose qw(Str Int);
    use MooseX::Types -declare => [qw(IP Port Domain AuthMethod PosInt NatInt)];

    our $IPRegex = qr/
            (?:(?:25[0-5]|2[0-4]
            [0-9]|[01]?[0-9]
            [0-9]?)\.){3}(?:25[0-5]
            |2[0-4][0-9]|[01]?
            [0-9][0-9]?)
        /x;

    our $PortRegex = qr/
            6553[0-5]|
            655[0-2]\d|
            65[0-4]\d\d|
            6[0-4]\d\d\d|
            [1-5]\d\d\d\d|
            [1-9]\d?\d?\d?|0
        /x;

    our $DomainRegex = qw/^((([a-z]|[0-9]|\-)+)\.)+([a-z])+$/;

    subtype IP, as Str, where { return ($_ =~ /(\b^$IPRegex\b$)/) };

    subtype Port, as Str, where { return ($_ =~ /(\b^$PortRegex\b$)/) };

    subtype Domain, as Str, where { return ($_ =~ /(\b^$DomainRegex\b$)/i) };

    subtype PosInt, as Int, where { $_ > 0 };
    
    subtype NatInt, as Int, where { $_ >= 0 };

    subtype AuthMethod, as Str, where { length($_) == 1 };
}