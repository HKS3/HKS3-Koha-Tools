#!/usr/bin/perl

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.


use Modern::Perl;

use CGI qw ( -utf8 );
use HTML::Entities;
use Try::Tiny;
use C4::Context;
use C4::Koha;
use C4::Serials;    #uses getsubscriptionfrom biblionumber
use C4::Output;
use C4::Biblio;
use C4::Items;
use C4::Search;        # enabled_staff_search_views
use C4::Tags qw(get_tags);
use C4::XSLT;
use Koha::DateUtils;
use Koha::Biblios;
use Koha::Items;
use Koha::ItemTypes;
use Koha::Patrons;
use Koha::Plugins;
use Data::Dumper;
use Text::CSV;
use Getopt::Long;

$|=1;

my $input_file;

    my $dbh = C4::Context->dbh;
    my $sql= <<'SQL';
with cte as 
    (select biblionumber, 
            ExtractValue(metadata,'//datafield[@tag="856"]/subfield[@code="u"]') AS url 
from biblio_metadata) 
select * from cte where url regexp '^{.*}$';
SQL
    my $query = $dbh->prepare($sql);
    $query->execute();
    my $items = $query->fetchall_arrayref({});

foreach my $item (@$items) {
    say $item->{biblionumber};
    fix_url4biblionumber($item->{biblionumber});
}


sub fix_url4biblionumber {
    my $biblionumber = shift @_;
    my $record       = GetMarcBiblio({ biblionumber => $biblionumber });
    #$record->field("856")->update('u' => $url);
    my @urls = $record->field('856');
    foreach my $u (@urls) {
        my $url = $u->subfield("u");
        $url =~ s/^{+(.*)}+/$1/;
        say $url;
        $u->update('u' => $url);
    }
        
    ModBiblio($record, $biblionumber);
}
