package HKS3::MARC21Web;

use strict;
use warnings;
use Encode;
use feature qw/say/;
use POSIX qw();
use Exporter 'import';
use XML::XPath;

our @EXPORT_OK = qw(get_marc_via_id);

use List::Util qw/ any /;

use LWP;
# use File::Slurp;
use Path::Tiny;
use Getopt::Long;
use DateTime;
use Data::Dumper;
use Encode qw(decode encode);
use MARC::File::XML qw//;
use MARC::Charset;

my $web_resources = {
    'dnb' => {
        url => "https://services.dnb.de/sru/dnb?version=1.1&operation=searchRetrieve&query=%s=%s&recordSchema=MARC21-xml",
        xml  => '//recordData/record',
    },
    'loc' => {
        url => "http://lx2.loc.gov:210/lcdb?version=1.1&operation=searchRetrieve&query=bath.%s=%s&maximumRecords=10&recordSchema=MARCXML",
        xml => '//zs:searchRetrieveResponse/zs:records/zs:record/zs:recordData/record',
     },
    'k10p' => {
        url => "https://sru.bsz-bw.de/swb?version=1.1&query=pica.%s=%s&operation=searchRetrieve&maximumRecords=10&recordSchema=marcxmlk10os",
        xml => '//zs:searchRetrieveResponse/zs:records/zs:record/zs:recordData/record',
     },
};

sub get_marc_via_id {
    my $id = shift;
    my $type = shift;
    my $cachedir = shift;
    my $sources = shift; # should be an arrayref [loc, dnb, ]
    my $xml;

    if ( ! -d $cachedir ) {
        die "not a directory: $cachedir";
    }

    # $isbn =~ s/.*\/(.*)/$1/g;

    foreach my $source (@$sources) {

        if (! exists( $web_resources->{$source} ) ) {
            die "Source '$source' not available. Use one of these: [" . join(', ', keys $web_resources->%*) . ']';
        }

        #print Dumper $web_resources->{$source};
        # in k10plus the search term for isbn is isb
        if ($source eq 'k10p' && $type eq 'isbn') {
            $type = 'isb';
        }
        my $filename  = sprintf("%s/%s-sru-export-%s-%s.xml", $cachedir, $source, $type, $id);
        printf("%s \n", $filename);

        if (-f $filename) {
            $xml = path($filename)->slurp_utf8;
            printf("file length %d \n", length($xml));
            next if length($xml) == 0;
            return $xml;
        }

        # printf("Source %s\n", $source->{name});
        my $url = sprintf($web_resources->{$source}->{url}, $type, $id);
        $xml = fetch_marc_from_url($url, $filename, $web_resources->{$source}->{xml});
        sleep(5);
        return $xml if $xml &&  length($xml) > 0;
    }

    return $xml;
}

sub fetch_marc_from_url {
    my $url = shift;
    my $filename = shift;
    my $record_node = shift;


    print "URL $url \n";
    my $req = HTTP::Request->new(GET => $url);
    my $ua = LWP::UserAgent->new;
    $ua->default_header(
        'Accept-Charset' => 'utf-8',
    );
    my $agent = "sru downloader";
    $ua->agent($agent);


    $req->content_type('text/html');
    $req->protocol('HTTP/1.0');

    my $response = $ua->request($req);
    if ($response->is_success) {
        my $xp = XML::XPath->new(xml => $response->content);
        #printf("Record Node: %s \n", $record_node);
        my $nodeset = $xp->find($record_node);
        my $xml;
        foreach my $node ($nodeset->get_nodelist) {
            $xml = XML::XPath::XMLParser::as_string($node);
            last;
        }
        # write_file($filename, {binmode => ':raw'}, $xml);
        path($filename)->spew_utf8($xml);
        return $xml;
    }
    else {
        printf("Response %s\n", $response->code);
        #use Data::Dumper;
        #warn Dumper($response);
    }
}

sub get_empty_record {
my $xml = <<XML;
<?xml version="1.0" encoding="UTF-8"?>
<record
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.loc.gov/MARC21/slim http://www.loc.gov/standards/marcxml/schema/MARC21slim.xsd"
    xmlns="http://www.loc.gov/MARC21/slim">

  <leader>00199nam a22000977a 4500</leader>
  <controlfield tag="005">20221016160626.0</controlfield>
  <controlfield tag="008">221016b        |||||||| |||| 00| 0 ger d</controlfield>
</record>
XML

return $xml;
}

sub get_empty_auth_record {
my $xml = <<XML;
<?xml version="1.0" encoding="UTF-8"?>
<record
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.loc.gov/MARC21/slim http://www.loc.gov/standards/marcxml/schema/MARC21slim.xsd"
    xmlns="http://www.loc.gov/MARC21/slim">

  <leader>00207nz  a2200109n  4500</leader>
  <controlfield tag="005">20221016160626.0</controlfield>
  <controlfield tag="008">221108|| aca||babn           | a|a     d</controlfield>
</record>

XML

return $xml;
}

sub marc_record_from_xml {
    my $xml = shift;
    #MARC::File::XML->default_record_format('MARC21');
    my $record = MARC::Record->new_from_xml( $xml, 'UTF-8', 'MARC21' );
    $record->encoding( 'UTF-8' );
    return $record;
}

1;
