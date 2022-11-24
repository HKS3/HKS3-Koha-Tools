#!/usr/bin/env perl
use 5.018;
use warnings;

use Cwd;
use HKS3::MARC21Web;
use MAB2::Parser::Disk;

my $filename = $ARGV[0];
my $cwd = getcwd();
my $file = $cwd . '/' . $filename;

die "Not a file. ($file)" unless -f $file;

my $parser = MAB2::Parser::Disk->new( $file );

my $count = 0;
my $count_isbn = 0;

die "CACHE_DIR not defined" unless $ENV{CACHE_DIR};
my $cache_dir = $ENV{CACHE_DIR};

my $mapping_mab2_marc = get_mapping();

while ( my $record_hash = $parser->next() ) {
    my $record = $record_hash->{record};
    my $isbn = get_isbn($record);
    $count++;
    my $xml = '';
    my $marc;
    if ($isbn) {
        $count_isbn++;
        $xml = HKS3::MARC21Web::get_marc_via_id($isbn, 'ISBN', $cache_dir, ['dnb']);
    }

    if ($xml) {
        $marc = HKS3::MARC21Web::marc_record_from_xml($xml);
    }
    else {
        $xml = HKS3::MARC21Web::get_empty_auth_record();
        $marc = HKS3::MARC21Web::marc_record_from_xml($xml);
        for my $field ($record->@*) {
            if (exists $mapping_mab2_marc->{ $field->[0] }) {
                my $m = $mapping_mab2_marc->{ $field->[0] };
                #say $m->{name} . ': ' . $field->[3];
                HKS3::MARC21Web::add_field(
                    $marc,
                    $m->{'marc-field'},
                    $m->{'marc-subfield'},
                    $m->{'marc-ind1'},
                    $m->{'marc-ind2'},
                    $field->[3],
                );
            }
            else {
                #die "unknown mab2 field: " . $field->[0];
            }
        }
    }

    #$record = HKS3::MARC21Web::marc_record_from_xml($xml);
}
say "$count/$count_isbn";

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
    if ( substr($isbn, 0, length $prefix) eq $prefix ) {
        $isbn = substr($isbn, 1 + length $prefix);
    }
    return $isbn;
}

sub get_mapping {
    # name, mab2-field, mab2-subfield, marc21-field, marc21-subfield
#    my $mapping_data = [
#        [ 'Titel', '331', ' ', '245', 'a', ' ', ' ' ],
#        [ 'ISBN', '540', ' ', '020', 'a', ' ', ' ' ],
#    ];
#    my $mapping_mab2_marc = {};
#    for my $m ($mapping_data->@*) {
#        $mapping_mab2_marc->{ $m->[1] } = {
#                                            name            => $m->[0],
#                                            'mab2-subfield' => $m->[2],
#                                            'marc-field'    => $m->[3],
#                                            'marc-subfield' => $m->[4],
#                                            'marc-ind1'     => $m->[5],
#                                            'marc-ind2'     => $m->[6],
#                                          }
#    }

    my $mapping_mab2_marc = {
        # mab2-field => name, mab2-subfield, marc21-field, marc21-subfield
        '331' =>  { name => 'Titel', 'mab2-subfield' => ' ', 'marc-field' => '245', 'marc-subfield' =>  'a', 'marc-ind1' => ' ', 'marc-ind2' => ' '},
        '540' =>  { name => 'ISBN', 'mab2-subfield' => 'a', 'marc-field' => '020', 'marc-subfield' =>  'a', 'marc-ind1' => ' ', 'marc-ind2' => ' '},
    };
    return $mapping_mab2_marc;
}
