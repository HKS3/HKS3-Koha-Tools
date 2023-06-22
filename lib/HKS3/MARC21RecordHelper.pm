package HKS3::MARC21RecordHelper;

use strict;
use warnings;
use Exporter 'import';
use MARC::Record;
use MARC::Field;
use MARC::Charset;

our @EXPORT_OK = qw(add delete_field insert_if_missing upsert upsert_control_field);

sub add {
    my ($record, $field, $ind1, $ind2, %subfields) = @_;
    my @new_field = ($field, $ind1, $ind2);
    my $added=0;
    while (my ($sf, $val) = each %subfields) {
        push(@new_field, $sf, $val) if defined $val;
        $added++;
    }
    $record->insert_fields_ordered(MARC::Field->new( @new_field )) if $added;
}

sub insert_if_missing {
    my ($record, $field, $ind1, $ind2, %subfields) = @_;

    return if $record->field($field);
    add(@_);
}

sub upsert {
    my ($record, $field, $ind1, $ind2, %subfields) = @_;

    # deal with control fields
    if ($field =~ m/^00[135678]$/xms) {
        my @notsopretty = %subfields; # extract control field number
        upsert_control_field($record, $field, $notsopretty[1] );
        return;
    }

    if (my $f = $record->field($field)) {
        while (my ($sf, $val) = each %subfields) {
            $f->update($sf,$val) if defined $val;
        }
    }
    else {
        add(@_);
    }
}

sub upsert_control_field {
    my ($record, $field, $value ) = @_;
    return unless defined $value;
    if (my $f = $record->field($field)) {
        $f->update($value);
    }
    else {
        $record->insert_fields_ordered(MARC::Field->new( $field, $value ));
    }
}

# just for the sake of completeness
sub delete_field {
    my ($record, $field ) = @_;
	my @fields  = $record->field($field);
	my $df = $record->delete_fields(@fields);
	return $df;
}

q{ listening to: Clara Luzia - Howl at the Moon, gaze at the Stars };
