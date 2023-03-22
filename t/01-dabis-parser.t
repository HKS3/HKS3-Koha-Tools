use strict;
use warnings;
use Test::Exception;
use Test::More;
use Test::Warn;
use Data::Dumper;
use utf8;

use HKS3::Dabis qw/ parse_file /;

my $records = parse_file('./t/single-record.txt');

print Dumper $records;

done_testing;
