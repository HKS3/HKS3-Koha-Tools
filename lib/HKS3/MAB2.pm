package HKS3::MAB2;

use strict;
use warnings;
use feature qw/say/;
use Exporter qw/import/;

our @EXPORT_OK = qw/ mab2hash /;

sub mab2hash {
    my ($mab_raw) = @_;
    my $record;
    for my $r (@$mab_raw) {
        my @ra = @$r;
        push @{$record->{$r->[0]}->{$r->[1]}}, [@ra[2..3]];
    }
    return $record;
}

1;
