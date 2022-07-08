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
use File::Slurp;
use Getopt::Long;
use DateTime;
use Data::Dumper;

my $web_resources = {
    'dnb' => {
        url => "https://services.dnb.de/sru/dnb?version=1.1&operation=searchRetrieve&query=%s=%s&recordSchema=MARC21-xml",
        xml  => '//recordData/record',
    },
    'loc' => {
        url => "http://lx2.loc.gov:210/lcdb?version=1.1&operation=searchRetrieve&query=bath.%s=%s&maximumRecords=10&recordSchema=MARCXML",
        xml => '//zs:searchRetrieveResponse/zs:records/zs:record/zs:recordData/record',
     },
};

sub get_marc_via_id {
    my $id = shift;
    my $type = shift;
    my $cachedir = shift;
    my $sources = shift; # should be an arrayref [loc, dnb, ]
    my $xml;
    
    # $isbn =~ s/.*\/(.*)/$1/g;

    foreach my $source (@$sources) {

        print Dumper $web_resources->{$source};
        my $filename  = sprintf("%s/%s-sru-export-%s-%s.xml", $cachedir, $source, $type, $id);
        printf("%s \n", $filename);        

        if (-f $filename) {
            $xml = read_file($filename);
            printf("length %d \n", length($xml));
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
        
    
    print "$url \n";
    my $req = HTTP::Request->new(GET => $url);
    my $ua = LWP::UserAgent->new;
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
        write_file($filename, {binmode => ':raw'}, $xml);
        return $xml;
    }
    else {
            printf("Response %s\n", $response->code);
    }
}

1;
