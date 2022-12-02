#!/usr/bin/env perl
use 5.018;
use warnings;

use Cwd;
use MAB2::Parser::Disk;
use HKS3::MARC21Web qw/
                       get_marc_via_id
                       get_empty_auth_record
                       marc_record_from_xml
                       add_field
                       get_marc_file
                    /;
use Text::CSV qw/ csv /;

die "CACHE_DIR not defined" unless $ENV{CACHE_DIR};
my $cwd = getcwd();

my $filename = $ARGV[0];
my $file = $cwd . '/' . $filename;
die "Not a file. ($file)" unless -f $file;

my $mappingfilename = $ARGV[1];
my $mappingfile = $cwd . '/' . $mappingfilename;
die "Not a file. ($mappingfile)" unless -f $mappingfile;

my $parser = MAB2::Parser::Disk->new( $file );

my $count = 0;
my $count_isbn = 0;
my $cache_dir = $ENV{CACHE_DIR};

my $mapping_mab2_marc = get_mapping();

my $marc_file = get_marc_file( 'hdn_marc.xml' );

while ( my $mab_record_hash = $parser->next() ) {
    my $mab_record = $mab_record_hash->{record};
    my $isbn = get_isbn($mab_record);
    $count++;
    my $xml = '';
    my $marc_record;
    if ($isbn) {
        $count_isbn++;
        $xml = get_marc_via_id($isbn, 'ISBN', $cache_dir, ['dnb']);
    }

    if ($xml) {
        $marc_record = marc_record_from_xml($xml);
    }
    else {
        $xml = get_empty_auth_record();
        $marc_record = marc_record_from_xml($xml);
        for my $field ($mab_record->@*) {
            if (exists $mapping_mab2_marc->{ $field->[0] }) {
                my $m = $mapping_mab2_marc->{ $field->[0] };
                #say sprintf( '%s (%s)', $field->[3], $m->{info});
                add_field(
                    $marc_record,
                    $m->{'marc-field'},
                    $m->{'marc-ind1'},
                    $m->{'marc-ind2'},
                    $m->{'marc-subfield'},
                    $field->[3],
                );
            }
            else {
                #die "unknown mab2 field: " . $field->[0];
            }
        }
    }

    $marc_file->write($marc_record);
}

say "$count records exported.";
#say "$count/$count_isbn";

sub get_isbn {
    my ($record) = @_;
    my $isbn = '';
    for my $field ($record->@*) {
        if ( $field->[0] eq '540' && $field->[1] eq 'a' ) {
            $isbn = $field->[3];
            $isbn = strip_isbn_prefix($isbn);
        }
    }
    return $isbn;
}
sub strip_isbn_prefix {
    my $isbn = shift;
    my $prefix = 'ISBN';
    #my $prefix = 'ISBN ';
    if ( substr($isbn, 0, length $prefix) eq $prefix ) {
        #$isbn = substr($isbn, length $prefix);
        $isbn = substr($isbn, 1 + length $prefix);
    }
    return $isbn;
}

sub get_mapping {

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
