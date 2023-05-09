package HKS3::Dabis;

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
use MARC::Record;
use MARC::File::XML qw//;
use Text::CSV qw/ csv /;
use Data::Dumper;
use Moo;

our @EXPORT_OK = qw/
                    parse_file
                    to_marc
                    get_mapping
                 /;

sub get_mapping {
    my ($mappingfile) = @_;

    my $csv = csv(
        in         => $mappingfile,
        sep_char   => ";",
        quote_char => '"',
        headers    => "auto",
        encoding   => "UTF-8",
    );

    my $mapping2marc = {};
    my $count = 1; # start at 1 because of csv HEADER line
    {
    no warnings ('uninitialized', 'substr');

    for my $mapping (@$csv) {                 
        $mapping->{field} = substr($mapping->{MARC21},0,3); 
        $mapping->{subfield} = substr($mapping->{MARC21},3,1); 
        $mapping->{ind1} = substr($mapping->{MARC21},4,1) // ' '; 
        $mapping->{ind2} = substr($mapping->{MARC21},5,1) // ' '; 
        $mapping2marc->{ $mapping->{dabis} } = $mapping;
    }
    }
    return $mapping2marc;
}

sub parse_file {
    my $filename = shift;
    # my @lines = path($filename)->lines_utf8;
    my @lines = path($filename)->lines;
    my @records;
    my $record = {};
    my $current_field = '';
    my $current_value = '';
    my $i = 0;

    foreach my $line (@lines) {
    # printf "%d %s\n", $i++, $line;
        chomp $line;
        # next if $line =~ /^ENDE/;
		if ($line =~ /^ENDE/) {
		} elsif ($line =~ /^ HDR (.+)/) {
            if (keys %$record) {
                push @records, $record;
            } else {
                $record = {'HDR' => [$1] };
            }
            $current_field = '';
            $current_value = '';
        } elsif ($line =~ /^END[BH]/) {
            if ($current_field && $current_value) {
                push @{$record->{$current_field}}, $current_value;
                # $record->{$current_field} = $current_value;
                $current_field = '';
                $current_value = '';
            }
            push @records, $record;
            $record = {};
        } elsif ($line =~ /^\s+/) {
            # Continuation of previous value
            chomp($line);
            $current_value .= "$line";
        } else {
            if ($current_field && $current_value) {
                chomp($current_value);
                push @{$record->{$current_field}}, $current_value
                    if $current_value !~ /^\s*$/;
                $current_field = '';
                $current_value = '';
            }
            # my ($field, $value) = split / /, $line, 2;
            my ($field, $value) = $line =~ /(.{4}).(.*)/;
		    $field =~ s/\s+$//;
            $value =~ s/\s+/ /;
            chomp($field);
            chomp($value);
			# printf "%s %s\n", $field, $value;
            # push (@{$record->{$field}}, $value) if $value !~ /^\s*$/;
            $current_field = $field;
            $current_value = $value;
        }
    }

    if (keys %$record) {
        push @records, $record;
    }
    return \@records;
}

## 7510 buch 11/9
## 7510 1602/P IGF
## 7520 buch 11/9
## 7520 1602/P IGF
## 7550 28763
## 7550 1602/P IGF
## 7560 Verb.Nr.: 28763
## 7560 Verb.Nr.: 1602/P IGF
## 7570   -  Sign.: buch 11/9
## 7570   -  Sign.: 1602/P IGF
## 7600 Sto.: IKT Petzenkirchen
## 7600 Sto.: IGF Scharfling | Gewässerökol

sub to_marc {
        my $record = shift;
        my $mapping = shift;

        print Dumper $record->{'7570'};

        foreach my $f (sort keys %$record) {
                if ($f =~ /^75/) {
                        printf ("%s \n", $f);
                }
        }
}

q{ listening to: Mahler 1. Symphonie, Bernstein/Wiener Philharmoniker, https://www.youtube.com/watch?v=ISBfOpztUZM };


__END__

 HDR TIT00000004 04
CMD  IDN=1-* #n STS=ag
IDN  4
SDN  20.01.2000
SDU  08.09.2009
TYP  2
MEX  1
BDE  33
3000*Aqua-press
4000 Wien
4010 Bohmann
4400 Nebent.: Aqua press international. - Nachgewiesen 1998 -
4671 BAWW
4672 bt ; sa ; rs
4700 Aqua press international
5100 Zeitschrift
5100 Serie
5650 Wasserwirtschaft
5655 Wasserwirtschaft
7510 Zeitschrift/ 81
7520 Zeitschrift/ 81
7550 28121
7560 Verb.Nr.: 28121
7570   -  Sign.: Zeitschrift/ 81
7600 Sto.: IKT Petzenkirchen
STO1 IKT Petzenkirchen
STO2 IKT
7620  
7630  
7660  
7675  
9000 wurde im September 2009 ausgeschieden, 2 Exemplaren wurden wegen Dok bzw. I
     nhalt aufgehoben
9950 {{http://www.aquamedia.at}} Link anwählen
VORP  
VORK  
B107 1
B100 33
B110 1
ENDH
