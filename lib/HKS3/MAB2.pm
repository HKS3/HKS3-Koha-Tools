package HKS3::MAB2;

use strict;
use warnings;
use feature qw/say/;
use Exporter qw/import/;

our @EXPORT_OK = qw/ mab2hash get_mapping /;

sub mab2hash {
    my ($mab_raw) = @_;
    my $record;
    for my $r (@$mab_raw) {
        my @ra = @$r;
        push @{$record->{$r->[0]}->{$r->[1]}}, [@ra[2..3]];
    }
    return $record;
}

sub get_mapping {
    my ($mappingfile) = @_;    

    my $csv = csv(
        in         => $mappingfile,
        sep_char   => ";",
        quote_char => '"',
        headers    => "auto",
        encoding   => "UTF-8",
    );

    my $mapping_mab2_marc = {};
    my $count = 1; # start at 1 because of csv HEADER line
    for my $mapping (@$csv) {
        $count++;
        my $field_MARC    = $mapping->{FIELD};
        my $ind1_MARC     = $mapping->{IND1};
        my $ind2_MARC     = $mapping->{IND2};
        my $subfield_MARC = $mapping->{SUBFIELD};
        my $info_MARC     = $mapping->{INFO} // '';

        my $marc = "$field_MARC $ind1_MARC$ind2_MARC \$$subfield_MARC";

        my $re_MAB2 = qr/
                          ^
                          (\d\d\d)
                          ([a-zA-Z0-9\ ])
                          $
                      /xms;
        my ($field_MAB, $subfield_MAB) = $mapping->{MAB2} =~ $re_MAB2;

        if (   defined $field_MAB
            && defined $subfield_MAB
            && length $field_MARC
            && length $ind1_MARC
            && length $ind2_MARC
            && length $subfield_MARC
        ) {
            say sprintf('map [%s%s] to [%s]', $field_MAB, $subfield_MAB, $marc);

            $mapping_mab2_marc->{ $field_MAB } = {
                                                    'mab2-field'    => $field_MAB,
                                                    'mab2-subfield' => $subfield_MAB,
                                                    'marc-field'    => $field_MARC,
                                                    'marc-ind1'     => $ind1_MARC,
                                                    'marc-ind2'     => $ind2_MARC,
                                                    'marc-subfield' => $subfield_MARC,
                                                    info            => $info_MARC,
                                                 };
        }
        else {
            print "invalid mapping: $field_MAB$subfield_MAB to $marc (line $count in mapping file)";
            if ($field_MAB) {
                say " (MARC21 ERROR)";
            }
            else {
                say " (MAB2 ERROR)";
            }
        }
    }

    return $mapping_mab2_marc;
}


1;

__END__

 printf "CN   %s \n", $mab->{'076'}->{i}->[0]->[1];
