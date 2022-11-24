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

while ( my $record_hash = $parser->next() ) {
    my $record = $record_hash->{record};
    my $isbn = get_isbn($record);
    $count++;
    my $xml = '';
    if ($isbn) {
        say "ISBN: $isbn";
        $count_isbn++;
        $xml = HKS3::MARC21Web::get_marc_via_id($isbn, 'ISBN', $cache_dir, ['dnb']);
        die $xml;
    }
    else {
        say "ISBN: undefined";
        $xml = HKS3::MARC21Web::get_empty_auth_record();
    }

    #$record = MARC::Record->new_from_xml( $xml, 'UTF-8', 'MARC21' );
    #$record->encoding( 'UTF-8' );
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
