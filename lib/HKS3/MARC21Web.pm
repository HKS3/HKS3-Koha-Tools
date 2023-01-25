package HKS3::MARC21Web;

use strict;
use warnings;
use Encode;
use feature qw/say/;
use POSIX qw();
use Exporter 'import';
use XML::XPath;
use List::Util qw/ any /;
use LWP;
use Path::Tiny;
use Getopt::Long;
use DateTime;
use Data::Dumper;
use Encode qw(decode encode);
use ZOOM;
use MARC::Record;
use MARC::File::XML qw//;

our @EXPORT_OK = qw/
                     get_marc_via_id
                     get_empty_record
                     get_empty_auth_record
                     marc_record_from_xml
                     add_field
                     get_marc_file
                 /;

my $z3950_connections = {};

my $web_resources = {
    'dnb' => {
        url => "https://services.dnb.de/sru/dnb?version=1.1&operation=searchRetrieve&query=%s=%s&recordSchema=MARC21-xml",
        xml  => '//recordData/record',
        search => 'dnb.isbn',
    },
    'loc' => {
        url => "http://lx2.loc.gov:210/lcdb?version=1.1&operation=searchRetrieve&query=bath.%s=%s&maximumRecords=10&recordSchema=MARCXML",
        xml => '//zs:searchRetrieveResponse/zs:records/zs:record/zs:recordData/record',
        search => 'lccn',
     },
    'k10p-sru' => {
        url => "https://sru.bsz-bw.de/swb?version=1.1&query=pica.%s=%s&operation=searchRetrieve&maximumRecords=10&recordSchema=marcxmlk10os",
        xml => '//zs:searchRetrieveResponse/zs:records/zs:record/zs:recordData/record',
     },
    'bvb-sru' => {
        url => "http://bvbr.bib-bvb.de:5661/bvb01sru?version=1.1&recordSchema=marcxml&operation=searchRetrieve&query=marcxml.%s=%s&maximumRecords=1",
        xml => '//zs:searchRetrieveResponse/zs:records/zs:record/zs:recordData/record',
        search => 'idn',
     },
     'bnl' => {
        type => 'Z3950',
        url  => 'z3950cat.bl.uk:9909/ZBLACU',
        search => '@attr 1=12 "%s"',
     },
     'harvard' => {
        type => 'Z3950',
        url  => 'hvd.alma.exlibrisgroup.com:1921/01HVD_INST',
        search => '@attr 1=12 "%s"',
     },
     'yale' => {
        type => 'Z3950',
        url  => 'z3950.library.yale.edu:7090/voyager',
        search => '@attr 1=12 "%s"',
     },
     'bobcat' => {
        type => 'Z3950',
        url  => 'aleph.library.nyu.edu:9991/NYU01PUB',
        search => '@attr 1=12 "%s"',
     },
     'kobv' => {
        type => 'Z3950',
        url  => 'z3950.kobv.de:210/k2',
        search => '@attr 1=12 "%s"',
     },
     'bvb' => {
        type => 'Z3950',
        url  => 'bvbr.bib-bvb.de:9991/BVB01MCZ',
        search => '@attr 1=12 "%s"',
     },
     'k10p' => {
        type => 'Z3950',
        url  => 'z3950.k10plus.de:210/opac-de-627',
        search => '@attr 1=12 "%s"',
     },
     'loc_z39' => {
        type => 'Z3950',
        url  => 'lx2.loc.gov:210/LCDB',
        search => '@attr 1=12 "%s"',
     },
};

sub get_marc_via_id {
    my $id = shift;
    my $type = shift;
    my $cachedir = shift;
    my $sources = shift; # should be an arrayref [loc, dnb, ]
    my $xml;

    if ( ! -d $cachedir ) {
        die "cachedir is not a directory: $cachedir";
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
            printf("length %d \n", length($xml));
            next if length($xml) == 0;
            return $xml;
        }

        # printf("Source %s\n", $source->{name});
        if ($web_resources->{$source}->{type} eq 'Z3950') {
            $xml = fetch_marc_from_z3950($source, $filename, $id, $web_resources->{$source});
            sleep(1);
        } else {
            my $url = sprintf($web_resources->{$source}->{url}, $web_resources->{$source}->{search}, $id);
            $xml = fetch_marc_from_url($url, $filename, $web_resources->{$source}->{xml});
            sleep(5);
        }
        path($filename)->spew_utf8($xml);
        return $xml if $xml && length($xml) > 0;
    }

    return $xml;
}

sub fetch_marc_from_url {
    my $url = shift;
    my $filename = shift;
    my $record_node = shift;

    print "$url \n";
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
        printf("%s \n", $record_node);
        my $nodeset = $xp->find($record_node);
        my $xml;
        foreach my $node ($nodeset->get_nodelist) {
            $xml = XML::XPath::XMLParser::as_string($node);
            last;
        }
        $xml //= '';
        # write_file($filename, {binmode => ':raw'}, $xml);
        return $xml;
    }
    else {
            printf("Response %s\n", $response->code);
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


sub fetch_marc_from_z3950 {
    my $source = shift;
    my $filenname = shift;
    my $id = shift;
    my $source_attrib = shift;

    my $conn;
    # die 'no user/pwd given' unless $ENV{LIB_USER} && $ENV{LIB_PASSWORD};

    printf "[%s] [%s] %s\n", $ENV{LIB_USER}, $ENV{LIB_PASSWORD}, $web_resources->{$source}->{url};
    printf "searching [%s]\n", $id;

    if (! exists($z3950_connections->{$source})) {
        my $o1 = new ZOOM::Options();
        $o1->option(user => $ENV{LIB_USER});
        my $o2 = new ZOOM::Options();
        $o2->option(password => $ENV{LIB_PASSWORD});
        my $opts = new ZOOM::Options($o1, $o2);
        $conn = create ZOOM::Connection($opts);
        $conn->connect($web_resources->{$source}->{url});
    # British National Bibliography number (only on BNB03U) 10
    # Local control number    12
    # print("server is '", $conn->option("serverImplementationName"), "'\n");
        $conn->option(preferredRecordSyntax => "usmarc");
        if ($conn->errcode() != 0) {
            die("somthing went wrong: " . $conn->errmsg())
        } else {
            printf ("new [%s] connection \n", $source);
        }
        $z3950_connections->{$source} = $conn;
    } else {
        $conn = $z3950_connections->{$source};
    }

    my $searchstring = sprintf ('@attr 1=12 "%s"', $id);
    my $rs = $conn->search_pqf( $searchstring );
    my $n = $rs->size();
    printf ("%s\n", $n);
    return if $n == 0;
    my $rec = $rs->record(0);
    my $raw = $rec->raw();
    my $marc = new_from_usmarc MARC::Record($raw);
    # my $trans = $rec->render("charset=latin1,utf8");
    # use Data::Dumper;
    $rs->destroy();
    return $marc->as_xml;
}

sub get_marc_file {
    my $filename = shift;
    die "output file exists. ($filename)" if -f $filename;

    MARC::File::XML->default_record_format('MARC21');
    my $file = MARC::File::XML->out( $filename, 'UTF-8' );
    return $file;
}

sub add_field {
    my ($record, $field, $ind1, $ind2, $subfield, $value) = @_;
    $record->append_fields(
        MARC::Field->new( $field, $ind1, $ind2, $subfield, $value )
    );
}

sub marc_record_from_xml {
    my $xml = shift;
    my $record = MARC::Record->new_from_xml( $xml, 'UTF-8', 'MARC21' );
    return $record;
}

1;
