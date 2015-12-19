#-------------------------------------------------------------------------------------------------------------------#
# tripmerge.pl                                                                                                      #
#                                                                                                                   #
# Info:  Merges various trip files, makes a backup called mergebackup.txt and print the result to trip.txt          #
# Usage: tripmerge.pl [FILE1] [FILE2] [FILE3]...                                                                    #
#-------------------------------------------------------------------------------------------------------------------#

### Print help
if( $ARGV[0] eq "help" )
  {
  print <<"END_HELP";

+-------------------------------------------------------------------------------------------------------------------+
| Usage: tripmerge.pl [FILE1] [FILE2] [FILE3]...                                                                    |
|                                                                                                                   |
| This tool merges trip files and trip file backups.                                                                |
| If trip.txt exists then it will be used as the base file, otherwise the first file will be used as the base file. |
| If no file is provided, then it will search for the backup directory (tripbackup).                                |
+-------------------------------------------------------------------------------------------------------------------+
END_HELP
  exit();
  }


#-------------------------------------------------------------------------------------------------------------------#
# Get files                                                                                                         #
#-------------------------------------------------------------------------------------------------------------------#

### Gets files from tripbackup folder if there are no arguments
if( !$ARGV[4] and -e "tripbackup" )
  {
  ### Read tripbackup
  opendir(TRIPBACKUP, "tripbackup") or die "Couldn't open tribackup.\n";
  @filelist = readdir(TRIPBACKUP);
  
  ### Delete ".., ..." files and format the file name
  @filelist      = grep(!/^\.+$/, @filelist);
  
  ### Exits if there are no backup files
  print "There are no backup files. Type help if you don't know how to use this tool.\n" and exit() if !@filelist;

  ### List of files to delete at the end without ".., ..." files
  @filestodelete = @filelist;

  ### Format file list
  @filelist      = map("tripbackup/$_", @filelist);
  print @filelist;
  die;
  close(TRIPBACKUP);
  }

else { @filelist = @ARGV; }

### Makes a backup of the original trip.txt
system("copy trip.txt \"tripbackup\mergebackup.txt\"") if -e "trip.txt";

push(@filelist, "tripbackup.txt") if "tripbackup.txt";


### Load base file
$base       = -e "trip.txt" ? "trip.txt" : shift(@filelist);
$totalfiles = int(@filelist);
$actualfile = 0;

open(BASE, "<", $base);
@base = <BASE>;
chomp(@base);
die "Error: File is empty.\n" if $base[0] eq "" or $base[0] eq " " or !$base[0];
close(BASE);


#-------------------------------------------------------------------------------------------------------------------#
# Merge them                                                                                                        #
#-------------------------------------------------------------------------------------------------------------------#

foreach my $file (@filelist)
    {
    ### not utf8
    print "file: '$file'.\n";
    open(FILE, "<", $file) or die "Error: Couldn't open file.\n";
    my @file = <FILE>;
    chomp(@file);
    die "Error: File is empty.\n" if $file[0] eq "" or $file[0] eq " " or !$file[0];
    close(FILE);
              
    my $totallines = int(@base);
    $actualfile++;
    my $line;
    ### For each trip in the second file...
    foreach my $entry (@file)
        {
        ### Print progress
        $line++;
        print "total:$totallines line:$line | file: $actualfile/$totalfiles\n";
        
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


#-------------------------------------------------------------------------------------------------------------------#
# Print them                                                                                                        #
#-------------------------------------------------------------------------------------------------------------------#

### Print the result to the base file
open(TRIP, ">", "trip.txt") or die "Couldn't create trip.txt.\n";
print TRIP "$_\n" foreach (@base);
close(TRIP);

### Delete backup files
if( !@ARGV and -e "tripbackup" )
  {
  sleep(1);
  print "Do you want to delete backup files?(Y/N): ";
  $YorN = <>;
  chomp($YorN);
  @filestodelete = map("tripbackup\\$_", @filestodelete);
  if ($YorN eq "Y") { system("del \"$_\"") foreach (@filestodelete); }
  }
