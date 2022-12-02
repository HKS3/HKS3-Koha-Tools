#!/usr/bin/env perl
use 5.018;
use warnings;

use Cwd;

my $cwd = getcwd();
my $filename = $ARGV[0];
my $file = $cwd . '/' . $filename;
die "Not a file. ($file)" unless -f $file;

my $seen = {};

open( my $fh, '<', $filename )
  or die "Could not open file for reading. ($!)";

for my $line (<$fh>) {
    chomp $line;
    my $mab = substr($line,0,4);
    next unless $mab;
    $seen->{$mab}++;
}

my @sorted_keys = sort { $seen->{$a} <=> $seen->{$b} } keys $seen->%*;

for my $key (@sorted_keys) {
    say sprintf('[%s]: %d', $key, $seen->{$key});
}
