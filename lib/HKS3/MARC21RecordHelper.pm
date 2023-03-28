package HKS3::MARC21RecordHelper;

use strict;
use warnings;
use Exporter 'import';
use MARC::Record;
use MARC::Field;

our @EXPORT_OK = qw(add insert_if_missing upsert upsert_control_field);

sub add {
    my ($record, $field, $ind1, $ind2, %subfields) = @_;
    my @new_field = ($field, $ind1, $ind2);
    my $added=0;
    while (my ($sf, $val) = each %subfields) {
        push(@new_field, $sf, $val) if $val;
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

    if (my $f = $record->field($field)) {
        while (my ($sf, $val) = each %subfields) {
            $f->update($sf,$val) if $val;
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

q{ listening to: Clara Luzia - Howl at the Moon, gaze at the Stars };
