### Load base file
$base = shift(@ARGV);

open(BASE, "<", $base);
@base = <BASE>;
chomp(@base);
die "Error: File is empty.\n" if $base[0] eq "" or $base[0] eq " " or !$base[0];
close(BASE);

foreach my $file (@ARGV)
    {
    ### not utf8
    open(FILE, "<", $file) or die "Error: Couldn't open file.\n";
    my @file = <FILE>;
    chomp(@file);
    die "Error: File is empty.\n" if $file[0] eq "" or $file[0] eq " " or !$file[0];
    close(FILE);
              
    my $totallines = int(@base);
    my $line;
    ### For each trip in the second file...
    foreach my $entry (@file)
        {
        ### Print progress
        $line++;
        print "$line/$totallines\n";
        
        ### Delete trip from the second entry
        my $trip = substr($entry, 0, 10);
        
        ### Search for a match in the first...
        foreach my $baseentry (@base)
            {
            next if $baseentry !~ /^\Q$trip\E/;            
            $match = 1;

            ### And if there is a match search for each name...
            
            ### Format name list
            $namelist  = substr($entry, 13);
            my @name   = split(/: /, $namelist);
            
            ### Delete last spaces
            $_ =~ s/\s$// foreach (@name);
            
            ### And add it if it doesn't exist
            foreach my $name (@name)
                {
                next if $baseentry =~ /: \Q$name\E/;
                $baseentry .= " : $name";
                }
            }
        ### Add a new entry if trip doesn't exist
        push(@base, $entry) if !$match;
        $match = 0;
        }
    }

### And print the result to the base file
open(TRIP, ">", "trip.txt");
print TRIP "$_\n" foreach (@base);
close(TRIP);
