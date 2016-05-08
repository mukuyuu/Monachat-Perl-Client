#------------------------------------------------------------------------------------------------------------------------------#
# Converts 10 digit trip text files into json files                                                                            #
#------------------------------------------------------------------------------------------------------------------------------#

#use strict;
use warnings;
use diagnostics;
use Encode qw{encode decode};
use JSON::Parse qw{parse_json json_file_to_perl};

%triplist = ();

open(JSON, ">", "trip.json");
print JSON "{\n";
open(TRIP, "<", "trip.txt");
for my $line (<TRIP>)
    {
    my @namelist;
    my $trip = substr($line, 0, 10);
    next if $trip =~ /\s+/;
    my $line = substr($line, 13, -1);
    if   ($line !~ /:/ )
         {
         push(@namelist, $line);
         }
    else {
         while($line =~ /(.+?) : |: (.+?)$/g)
              {
              push(@namelist, $1);
              }
         push(@namelist, $1) if $line =~ /.+: (.+?)$/;
         }
    
    print JSON "\"", qq{$trip}, "\": ";
    print JSON qq{[};
    while(@namelist)
         {
         my $name = shift(@namelist);
         @namelist ? print JSON qq{"$name", } : print JSON qq{"$name"};
         }
    #foreach my $name (@namelist)
    #    {
    #    print JSON "$name, ";
    #    }
    print JSON qq{],\n};
    }

print JSON "}";
close(JSON);
