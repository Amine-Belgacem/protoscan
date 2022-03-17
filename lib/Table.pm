#!/usr/bin/perl -w
use strict;
use warnings;
use MooseX::Declare;

class Table is mutable {
    use MooseX::Types::Moose qw(ArrayRef);

    has seperator => (
        is      => 'ro',
        default => sub {{
                length => 4,
                char   => ' ',
            };
        }
    );

    has unknown => (is => 'ro', isa => 'Str', default => '-');

    has row => (
        is      => 'ro',
        default => sub {{
                firstCol => {
                    title     => 'Server',
                    minLength => 21
                },
                secondCol => {
                    title     => 'T(ms)',
                    minLength => 8
                },
                thirdCol => {
                    title     => 'Response',
                    minLength => 5
                }
            };
        }
    );

    has leftMargin => (is => 'rw', isa => 'Str', default => '  ');

    method addSep($string, $length) {
        for (my $i = 1 ; $i <= $length ; $i++) {
            $string .= $self->seperator->{'char'};
        }
        return $string;
    }

    method formatFirstCol( Str $string) {
        my $col = $self->row->{'firstCol'};
        my $sep = $self->seperator;
        return $self->addSep($string,
            $col->{'minLength'} + $sep->{'length'} - length($string));
    }

    method formatSecondCol( Str $string) {
        my $col = $self->row->{'secondCol'};
        my $sep = $self->seperator;
        $string = $self->unknown if !$string;
        return $self->addSep($string,
            $col->{'minLength'} + $sep->{'length'} - length($string));
    }

    method formatThirdCol($input) {
        if (UNIVERSAL::isa($input, 'ARRAY')) {
            my $string;
            foreach (@{$input}) {
                $string .= $_." ";
            }
            return $string;
        }
        else { return $input }
    }

    method toRow($firstCol, $secondCol, $thirdCol) {
        return
            $self->leftMargin.
            $self->formatFirstCol($firstCol).
            $self->formatSecondCol($secondCol).
            $self->formatThirdCol($thirdCol)."\n";
    }

    method getHeader {
        return
            $self->leftMargin.
            $self->formatFirstCol($self->row->{'firstCol'}->{'title'}).
            $self->formatSecondCol($self->row->{'secondCol'}->{'title'}).
            $self->formatThirdCol($self->row->{'thirdCol'}->{'title'});
    }
}