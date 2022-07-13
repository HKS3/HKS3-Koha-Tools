package HKS3::FixKohaDB;

use strict;
use warnings;
use feature qw/say/;
use Exporter qw/import/;
use C4::Context;

our @EXPORT_OK = qw/ get_koha_dbh fix_koha_db /;

$| = 1;

sub get_koha_dbh {
    my $dbh = C4::Context->dbh;
    return $dbh;
}

sub fix_koha_db {
    my ($sql, $sub) = @_;

    my $dbh = get_koha_dbh();
    my $sth = $dbh->prepare($sql);
    $sth->execute();

    my $total = $sth->rows;
    print "Got $total rows\n";

    my $count = 0;
    while (my $row = $sth->fetchrow_hashref) {
        if ($count % 50 == 0) {
            print "\n" . sprintf('%010d/%010d', $count, $total) . ' .';
        }
        else {
            print '.';
        }
        $count++;
        $sub->($row);
    }
}

1;
