#!/usr/bin/perl -w
# @author Tim Harsch
# A simple perl script that takes the BigBenchTimes.csv file as a ';' delimited input and transforms
# it into a simpler set of data that is more amendable to charting:
#  * includes only the results of individual queries (no aggregate times)
#  * adjusts the labels to be smaller and title cased
#  * Converts times to Minutes and two decimal places
#  * changes the output format into TSV
#  * 
use strict;
use warnings;
use Text::CSV;
use Data::Dumper qw/ Dumper /;
use Cwd 'abs_path';
use Text::Autoformat;
use File::Basename;

# PROTOTYPES
sub dieWithUsage(;$);

# GLOBALS
my $SCRIPT_NAME = basename( __FILE__ );
my $SCRIPT_PATH = dirname( __FILE__ );

my $file = shift or dieWithUsage("BigBenchTimes.csv file missing");
-e $file or dieWithUsage("'$file' does not exist");
-r $file or dieWithUsage("'$file' must be readable");
$file = abs_path($file);

############### BEGIN MAIN ###############
my @rows;
my $csv = Text::CSV->new ( { binary => 1, sep_char => ';' } )  # should set binary attribute.
                 or dieWithUsage( "Cannot use CSV: ".Text::CSV->error_diag () );

open my $fh, "<:encoding(utf8)", $file or dieWithUsage( "Cannot open '$file': $!" );
$csv->getline( $fh ); # Toss out column headers and make our own...
print "Query\tMinutes\n";
while ( my $row = $csv->getline( $fh ) ) {
   #for( my $i=0; $i < $#$row; $i++ ) {
   #    print "$i:" . $row->[$i] . "\n";
   #}
   #print "\n";
  
   next unless defined($row->[2]) and $row->[2] ne "";
  
   my $label = $row->[1];
   chomp($label);
   $label =~ s/_IN_PROGRESS//;
   $label =~ s/_/ /g;
   $label = autoformat($label, { case => 'title' });
   chomp($label); chomp($label);
   #print $label, "\n";
  
   $label .= "-S" . $row->[2];
   $label .= "-Q" . $row->[3];
   print $label, "\t";
   my $time = $row->[6];
   $time = $time / ( 60 * 1000 );  # convert milliseconds to minutes
   $time = sprintf "%.2f", $time; # round to two places
   print $time, "\n";

   push @rows, $row;
}
$csv->eof or $csv->error_diag();
close $fh;

############### END MAIN ###############


sub dieWithUsage(;$) {
        my $err = shift || '';
        if( $err ne '' ) {
                chomp $err;
                $err = "ERROR: $err\n\n";
        } # end if

        print STDERR <<USAGE;
${err}Usage:
        perl ${SCRIPT_NAME} BigBenchTimes.csv

Description:
        This script parses the results of BigBench run to ready the data for charting via Excel
USAGE
        exit 1;
}
