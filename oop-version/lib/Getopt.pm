#!/usr/bin/perl -w
use strict;
use warnings;
use MooseX::Declare;

class Getopt is mutable {
    with 'MooseX::Getopt';

    has input => (
        is            => 'ro',
        isa           => 'Str',
        traits        => ['Getopt'],
        cmd_aliases   => ['i'],
        default       => './proxies.txt',
        documentation => 'Path to input proxy file',
    );
    has output => (
        is            => 'ro',
        isa           => 'Str',
        traits        => ['Getopt'],
        cmd_aliases   => ['o'],
        default       => './output.txt',
        documentation => 'Path to output proxy file',
    );
    has json => (
        is            => 'ro',
        traits        => ['Getopt'],
        cmd_aliases   => ['j'],
        default       => 0,
        documentation => 'Enable export in JSON format',
    );
    has http => (
        is            => 'ro',
        traits        => ['Getopt'],
        cmd_aliases   => ['p'],
        default       => 0,
        documentation => 'Enable HTTP probe',
    );
    has https => (
        is            => 'ro',
        traits        => ['Getopt'],
        cmd_aliases   => ['s'],
        default       => 0,
        documentation => 'Enable HTTPS probe',
    );
    has socks4 => (
        is            => 'ro',
        traits        => ['Getopt'],
        cmd_aliases   => ['4'],
        default       => 0,
        documentation => 'Enable SOCKS4 probe',
    );
    has socks5 => (
        is            => 'ro',
        traits        => ['Getopt'],
        cmd_aliases   => ['5'],
        default       => 0,
        documentation => 'Enable SOCKS5 probe',
    );
    has threads => (
        is            => 'ro',
        isa           => 'Int',
        traits        => ['Getopt'],
        cmd_aliases   => ['t'],
        default       => 5,
        documentation => 'Number of worker threads to be used',
    );
    has giveup => (
        is            => 'ro',
        isa           => 'Int',
        traits        => ['Getopt'],
        cmd_aliases   => ['g'],
        default       => 10,
        documentation => 'Request giveup timeout per host in seconds',
    );
    has retries => (
        is            => 'ro',
        isa           => 'Int',
        traits        => ['Getopt'],
        cmd_aliases   => ['r'],
        default       => 3,
        documentation => 'Number of request retries per host',
    );
}