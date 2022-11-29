use strict;
use warnings;
use Data::Dumper;
use utf8;
use Path::Tiny;

use HKS3::MARC21Web;
use MARC::File::XML();
# use MARC::File::XML (DefaultEncoding=>'utf8');
use Text::CSV qw( csv );
MARC::File::XML->default_record_format('MARC21');
use MARC::Charset;

MARC::Charset->ignore_errors(1);

my $infile = $ARGV[0];

my $csv = csv(in => $infile,
               sep_char=> ",",
               quote_char => '"',
               headers => "auto",
               encoding => "UTF-8",
             );


# Notiz von david: sollte das ned mit UTF-8 encoding sein? ...>>out( 'marc.xml', 'UTF-8' );
my $file = MARC::File::XML->out( 'marc.xml' );

for my $line (@$csv) {
    my $xml = HKS3::MARC21Web::get_empty_auth_record;
    
    my $record = MARC::Record->new_from_xml( $xml, 'UTF-8', 'MARC21' );
    $record->encoding( 'UTF-8' );
    
    my @fields;
    push @fields, MARC::Field->new(
         '040','','',
             'c' => 'intern'
     );
    push @fields, MARC::Field->new(
         '150','','',
             'a' => $line->{Auth},
     );
    
    push @fields, MARC::Field->new(
         '942','','',
             'a' => 'TOPIC_TERM',
    );
    
    my @a= (localtime) [5,4,3,2,1,0]; $a[0]+=1900; $a[1]++;
    $record->field('005')->update(sprintf("%4d%02d%02d%02d%02d%04.1f",@a));
    
    $record->insert_fields_ordered(@fields);
    
    $file->write($record);
}
$file->close();

__END__
<?xml version="1.0" encoding="UTF-8"?>
<record
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.loc.gov/MARC21/slim http://www.loc.gov/standards/marcxml/schema/MARC21slim.xsd"
    xmlns="http://www.loc.gov/MARC21/slim">

  <leader>00207nz  a2200109n  4500</leader>
  <controlfield tag="001">4</controlfield>
  <controlfield tag="003">OSt</controlfield>
  <controlfield tag="005">20221108210357.0</controlfield>
  <controlfield tag="008">221108|| aca||babn           | a|a     d</controlfield>
  <datafield tag="040" ind1=" " ind2=" ">
    <subfield code="a">OSt</subfield>
  </datafield>
  <datafield tag="150" ind1=" " ind2=" ">
    <subfield code="a">StR</subfield>
  </datafield>
  <datafield tag="942" ind1=" " ind2=" ">
    <subfield code="a">TOPIC_TERM</subfield>
  </datafield>
</record>

