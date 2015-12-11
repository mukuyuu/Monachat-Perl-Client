use strict;
no strict "vars"; ### Because of continous global variable errors
no strict "subs"; ### For constants
use warnings;
use diagnostics;
use Socket;
use IO::Socket;
use IO::Socket::Socks;
use IO::Select;
use threads;
use threads::shared qw(share shared_clone);
use Thread::Semaphore;
use Thread::Queue;
use Encode qw(encode decode);
use Win32::GUI;
use Win32::GUI::Constants qw(EN_LINK ENM_LINK);
use LWP::UserAgent;
use POSIX qw(LC_COLLATE);

use lib "lib";
use Userdata;
use Language;

### Load locale
$LOCALE = POSIX::setlocale(LC_COLLATE);
share($LANGUAGE);
share($ENCODING);

### Set global configuration
open(CONFIG, "<", "config.txt") or die "Couldn't open config.txt.";
for my $line (<CONFIG>)
    {
    $ENABLE_GRAPHIC_INTERFACE = $1 if $line =~ /^graphicinterface = (\d)$/;
    if( $line =~ /^language = (\w{7,8})$/ )
      {
      ($LANGUAGE, $ENCODING) =
          $1 eq "english" ?
          ("english",  "cp932") :
          ("japanese", "UTF-8");
      }
    }
close(CONFIG);

### Set space length    
($LOGINSPACE, $ROOMSPACE) =
    $LANGUAGE eq "japanese" ?
    (" " x 73, " " x 90)    :
    (" " x 82, " " x 87);


### SDL constants
sub SDL_QUIT            { 12 }
sub SDL_KEYDOWN         { 2 }
sub SDL_MOUSEBUTTONDOWN { 6 }
sub SDL_MOUSEBUTTONUP   { 9 }
sub SDL_BUTTON_LEFT     { 1 }

if( $ENABLE_GRAPHIC_INTERFACE )
  {
  require SDL;
  require SDL::Surface;
  require SDL::Video;
  require SDL::Color;
  require SDL::Event;
  require SDL::Events;
  require SDLx::App;
  require SDLx::Rect;
  require SDLx::Sprite;
  require SDLx::Text;
  }

### Write the date to log.txt
open(LOG, ">", "log.txt") or die "Couldn't open log.txt: $!";
(undef, undef, undef, $DAY, $MONTH, $YEAR) = localtime(time());
$YEAR = substr($YEAR, 1);
print LOG "[$DAY/$MONTH/$YEAR]\n";
close(LOG);

### Write warnings and errors to log.txt
$SIG{__WARN__} = sub {
    my($second, $minute, $hour) = localtime(time());
    open(LOG, ">>", "log.txt");
    print LOG "[$hour:$minute:$second] Warning: @_";
    print "Warning: ", @_;
    close(LOG);
};
$SIG{__DIE__}  = sub {
    my($second, $minute, $hour) = localtime(time());
    open(LOG, ">>", "log.txt");
    print LOG "[$hour:$minute:$second] Error: @_";
    print "Error: ", @_;
    close(LOG);
};



#--------------------------------------------------------------------------------------------------------------------



### The event loop in Win32::GUI is ended when -1 is returned
###
### Issues:
###
### - Too many lines
###
sub Window_Terminate
    {
    if( $config{savelog} )
      {
      my($second, $minute, $hour, $day, $month, $year) = localtime(time());
      system("mkdir LOG") if !-e "/LOG";
         
      ### Fix month and year format
      $month++;
      $year += 1900;
      local $filename = "[$day-$month-$year].txt";
         
      ### Save log
      open(CHATLOG, ">>", "LOG/$filename") or print_output("ERROR", SAVELOG_ERROR);
      print CHATLOG "--- [$second:$minute:$hour] ---\n";
      print CHATLOG $outputfield->Text();
      close(CHATLOG);
      }
    return -1;
    }

### Send the window to the taskbar icon when minimized
sub Window_Minimize
    {
    $window->Disable();
    $window->Hide();
    }

### Window move event
###
### Takes:
### scalar: Window handle
### Returns:
### array:  Position of the window [up, down, left, right]
###
### Issues:
### - Not very useful
###
sub Window_Move
    {
    my $window   = shift;
    my @position = $window->GetWindowRect();
    print "$position[0], $position[1], $position[2], $position[3]\n";
    };

### Show the window when the taskbar icon is clicked
sub NotifyIcon_Click
    {
    $window->Enable();
    $window->Show();
    }

### So that inputfield never loses focus
###
### Issues:
### - Write so that focus is recovered automatically unless outputfield is expresessly clicked
###
sub Inputfield_LostFocus { $inputfield->SetFocus() if $option{readonly}; }

### Do something when a url is clicked
###
### Takes:
### - Click related data
### Returns:
### - scalar: Url address
### Issues:
### - Currently not implemented (25/11)
###
sub Outputfield_URL
    {
    my($event, $wparam, $lparam, $type, $msgcode) = @_;
    if( $lparam == 2416736 )
      {
      #$text = $event->GetSel("-1", "-2000");
      my $text = $event->Text();
      my @url  = $text =~ /(www\..+?\..+)\s/g;
      my $url  = pop(@url);
      print "url: $url\n";
      }
    }
### If enter(13) is pressed send the text and erases inputfield
### If up(38) is pressed loop between previous comments upside
### If down(40) is pressed loop between previous comments downside
### Keys:
### - 13 : Enter
### - 38 : Up
### - 40 : Down
### - 39 : Right
### - 37 : Left
###
### Takes:
### - Inputfield related data
### Returns:
### - Nothing
###
### Issues:
### - Annoying sound when pressing enter
### - When looping between @inputline elements upside cursor position isn't in the last position
### - Also you can't move between $inputfield positions with left and right
### - /change doesn't work
###
sub Inputfield_KeyDown
    {
    shift;
    my $key  = shift;
    
    ### If key is enter...
    ### Issues:
    ### - no decoding before pushing it to @inputline ?
    if( $key == 13 )
      {
      my $text = $inputfield->Text();
      
      ### If text isn't undef(which is what inputfield send when there isn't
      ### nothing in inputfield and enter is pressed)
      if( $text )
        {
        ### Push current line into @inputline
        chomp($text);
        pop(@inputline) if $inputline[9];
        unshift(@inputline, $text);
        
        ### Decode it and send to command_handler if starts with /
        $text = decode("cp932", $text) or die "Couldn't decode: $!\n";
        if   ( $text =~ /^\// ) { command_handler($text); }
        else { $writesocketqueue->enqueue("COMMENT", $text); }
        
        ### Empty inputfield
        $inputfield->SelectAll();
        $inputfield->ReplaceSel("");
        }
     }
   
   ### Or key is up
   ###
   ### Issues:
   ### - Use of uninitialized value in subroutine entry at 1711 (22/11)
   ### - utf8?
   elsif( $key == 38 )
        {
        ### Get text and decode it from utf8
        my $text = $inputfield->Text()||"";
        $text    = decode("utf8", $text);
        
        ### Create $inputcounter if it doesn't exist and push current line into @inputline
        if( !$inputcounter )
          {
          $inputcounter = 0;
          unshift(@inputline, $text);
          }

        ### And copy previous line to $inputfield
        if( $inputline[$inputcounter + 1] )
          {
          $inputcounter++;
          $inputfield->SelectAll();
          $inputfield->ReplaceSel($inputline[$inputcounter]);
          }
        }
   
   ### Or down...
   ###
   ### Issues:
   ### - Argument "" isn't numeric in subroutine entry at 1711 (22/11)
   elsif( $key == 40 )
        {
        ### Create $inputcounter in case it doesn't exist
        $inputcounter = 0 if !$inputcounter;
        if( $inputline[$inputcounter - 1] and $inputcounter )
          {
          $inputcounter--;
          $inputfield->SelectAll();
          $inputfield->ReplaceSel($inputline[$inputcounter]);
          }
        }
   
   ### Or left...
   elsif( $key == 37 )
        {
        my($x, $y) = Win32::GUI::GetCursorPos();
        Win32::GUI::SetCursorPos(++$x, $y);
        }

   ### Or right...
   elsif( $key == 39 )
        {
        my($x, $y) = Win32::GUI::GetCursorPos();
        Win32::GUI::SetCursorPos(--$x, $y);
        }
   }
### Handles $inputfield input
###
### Takes:
### - scalar: An inputfield command
### Returns:
### - Nothing
###
### Issues:
### - Trip search in /addname not yet implemented
### - Antistalk not well implemented
###
sub command_handler
    {
    local $command = shift;
    my    $loginid = $logindata->get_id();
    if   ( $command eq "/login" )
         { $readsocketthread->kill("STOP"); }
    elsif( $command =~ /\/relogin\s*(.*)/ )
         {
         $proxy{skip} = $1 if $1 =~ /skip (\d+)/;
         $readsocketthread->kill("STOP");
         }
    elsif( $command eq "/reenter" )
         { $writesocketqueue->enqueue("REENTER"); }
    elsif( $command eq "/disconnect" )
         {
         $writesocketqueue->enqueue("<EXIT />", "<NOP />", "<NOP />");
         $readsocketthread->kill("KILL");
         }
    elsif( $command =~ /\/name (.+)/ )
         {
         if( length($1) > 20 ) {
             print_output("ERROR", NAME_TOO_LARGE);
             return;
         }
         $userdata->set_name($1, $loginid);
         $writesocketqueue->enqueue("REENTER");
         }
    elsif( $command =~ /\/character (.+)/ )
         {
         $userdata->set_character($1, $loginid);
         $writesocketqueue->enqueue("REENTER");
         }
    elsif( $command =~ /\/stat (.+)/ )
         {
         if( length($1) > 20 ) {
             print_output("ERROR", STAT_TOO_LARGE);
             return;
         }
         $writesocketqueue->enqueue("<SET stat=\"$1\" />");
         }
    elsif( $command =~ /\/trip (.+)/ )
         {
         ### Just in case
         my $trip = $1 ne " " ? $1 : "";
         $logindata->set_trip($trip);
         $writesocketqueue->enqueue("REENTER");
         }
    elsif( $command =~ /\/room (.+)/ )
         {
         $logindata->set_room2($1);
         $writesocketqueue->enqueue("REENTER");
         }
    elsif( $command =~ /\/rgb (\d{1,3}|x) (\d{1,3}|x) (\d{1,3}|x)/ )
         {
         #return if $_ !~ /\d{1,3}|x/ for ($1, $2, $3);
         
         my $r = $1 eq "x" ? $userdata->get_r($loginid) : $1;
         my $g = $2 eq "x" ? $userdata->get_g($loginid) : $2;
         my $b = $3 eq "x" ? $userdata->get_b($loginid) : $3;
         $userdata->set_r($r, $loginid);
         $userdata->set_g($g, $loginid);
         $userdata->set_b($b, $loginid);
         $writesocketqueue->enqueue("REENTER");
         }
    elsif( $command =~ /\/x (.+)/ )
         { $writesocketqueue->enqueue("SETXYSCL", "x$1"); }
    elsif( $command =~ /\/y (.+)/ )
         { $writesocketqueue->enqueue("SETXYSCL", "y$1"); }
    elsif( $command =~ /\/move (.+)/ )
         { $writesocketqueue->enqueue("SETXYSCL$1"); }
    elsif( $command eq "/scl" )
         {
         my $scl = $userdata->get_scl($loginid) == 100 ? -100 : 100;
         $writesocketqueue->enqueue("SETXYSCL", "scl$scl");
         }
    elsif( $command eq "/attrib" )
         {
         my $attrib = $userdata->get_attrib($loginid) eq "on" ? "off" : "on";
         $logindata->set_attrib($attrib);
         $writesocketqueue->enqueue("REENTER");
         }
    elsif( $command =~ /\/ignore (\d{1,3})/ )
         { $writesocketqueue->enqueue("IGNORE", $1); }
    elsif( $command =~ /\/search\s*(.*)/ )
         {
         if   ( $1 eq "main" or !$1 ) { $writesocketqueue->enqueue("SEARCH", "MAIN"); }
         elsif( $1 eq "all" )         { $writesocketqueue->enqueue("SEARCH", "ALL" ); }
         elsif( $1 =~ /user (.+)/ )
              {
              $option{searchuser} = $1;
              $writesocketqueue->enqueue("SEARCH", "ALL");
              }
         }
    elsif( $command =~ /\/stalk (.+)/ )
         {
         if   ( $1 eq "on" or $1 eq "off"  )
              {
              $option{stalk} = $1 eq "on" ? 1 : 0;
              print_output("NOTIFICATION", STALK_ON);
              }
         elsif( $1 eq "nomove" )
              { $option{nomove} = $option{nomove} ? 0 : 1; }
         elsif( $1 =~ /(\d{1,3})/ )
              {
              my $id           = $1;
              my($x, $y, $scl) = $userdata->get_x_y_scl($id);
              $option{stalk}   = 1;
              $userdata->set_stalk($id);
              $writesocketqueue->enqueue("SETXYSCL", "x$x"."y$y"."scl$scl");
              print_output("NOTIFICATION", STALK_ID);
              }
         }
    elsif( $command =~ /\/antistalk (.+)/ )
         {
         if   ( $1 eq "on" or $1 eq "off"  )
              {
              $option{antistalk} = $1 eq "on" ? 1 : 0;
              print_output("NOTIFICATION", ANTISTALK_ON);
              }
         elsif( $1 =~ /(\d{1,3})/ )
              {
              my $id = $1;
              $option{antistalk} = 1;
              $userdata->set_antistalk($id);
              print_output("NOTIFICATION", ANTISTALK_ID);
              }
         }
    elsif( $command =~ /\/copy (.+)/ )
         {
         my $id = $1;
         return if $id =~ /\d{1,3}/;
         
         $userdata->copy($id, $loginid);
         $writesocketqueue->enqueue("REENTER");
         }
    elsif( $command eq "/default" )
         {
         ### Not all options are resetted
         $userdata->default($logindata);
         $option{stalk}         = 0;
         $option{nomove}        = 0;
         $option{antiignore}    = 0;
         $option{antiignoreall} = 0;
         $writesocketqueue->enqueue("REENTER");
         }
    elsif( $command eq "/invisible" )
         {
         $userdata->invisible($loginid);
         $writesocketqueue->enqueue("REENTER");
         }
    elsif( $command =~ /profile (.+)/ )
         {
         if( $1 =~ /^(\d+)$/)
           {
           my($pname, $pcharacter, $pstatus, $ptrip, $pr, $pg, $pb, $px, $py, $pscl) =
             ("p".$1."name", "p".$1."character", "p".$1."status", "p".$1."trip",
              "p".$1."r", "p".$1."g", "p".$1."b", "p".$1."x", "p".$1."y", "p".$1."scl");
           
           $userdata->set_data(
               $config{$pname},
               $loginid,
               $config{$pcharacter},
               $config{$pstatus},
               $config{$ptrip},
               $userdata->get_ihash($loginid),
               $config{$pr},
               $config{$pg},
               $config{$pb},
               $config{$px},
               $config{$py},
               $config{$pscl} );
           }
         $writesocketqueue->enqueue("REENTER");
         }
    elsif( $command =~ /\/proxy\s*(.*)/ )
         {
         if   ( $1 eq "on" or $1 eq "off" )
              {
              $proxy{on} = $1 eq "on" ? 1 : 0;
              print_output("NOTIFICATION", PROXY_ON);
              }
         elsif( $1 =~ /timeout (\d\.*\d*)/ )
              { $proxy{timeout} = $1; }
         elsif( $1 =~ /change (\w{2,3})/ )
              {
              $proxy{change} =
                  $1 eq "on"  ? 1 :
                  $1 eq "off" ? 0 : $proxy{change};
              }
         $readsocketthread->kill("STOP");
         }
    elsif( $command =~ /\/clear (.+)/ )
         {
         if   ( $1 eq "screen" )
              {
              $outputfield->SelectAll();
              $outputfield->ReplaceSel("");
              }
         elsif( $1 eq "userdata" )
              {
              undef $userdata;
              $userdata = Userdata->new_user_data();
              enter_room("REENTER");
              }
         }
    elsif( $command =~ /\/end/ )
         { $outputfield->Scroll(-1); }
    elsif( $command =~ /\/new\s*(.*)|\/newinstance\*(.*)/ )
         {
         ### It would be better if a instance skipped the ip other instances are currently using
         ### x doesnt work
         my $search = $1;
         
         ### Make a backup of trip.txt
         system("copy trip.txt tripbackup.txt") if $option{savetrip} and -e "trip.txt";
         
         if( $search =~ /skip (\d+)/ ) {
             $proxy{skip} = $1;
         }
         if( $search =~ /here\s*(.*)/ ) {
             my $instancecounter = $1||1;
             my $room = $logindata->get_room2();
             
             for(1..$instancecounter) {
                 system("start perl monachat.pl -proxy yes -room $room -savetrip no");
                 sleep(1);
             }
         }
         else { system("start perl monachat.pl -proxy yes -savetrip no"); }
         }
    elsif( $command =~ /\/antiignore (.+)/ )
         {
         if   ( $1 eq "on" or $1 eq "off" )
              {
              $option{antiignore}    = $1 eq "on" ? 1 : 0;
              $option{antiignoreall} = 0 if $1 eq "off";
              print_output("NOTIFICATION", ANTIIGNORE_ON);
              }
         elsif( $1 =~ /(\d{1,3})/ )
              {
              my $id = $1;
              $option{antiignore} = 1;
              $userdata->set_antiignore($id);
              print_output("NOTIFICATION", ANTIIGNORE_ID);
              }
         elsif( $1 eq "all" )
              { $option{antiignoreall} = $option{antiignoreall} ? 0 : 1; }
         }
    elsif( $command =~ /\/mute (.+)/ )
         {
         my $search = $1;
         
         if   ( $search eq "on" or $search eq "off" ) {
                print_output("NOTIFICATION", MUTE_ON);
                $option{mute} = $1 eq "on" ? 1 : 0;
         }
         elsif( $search =~ /(\d{1,3})/ ) {
                local $id = $1;
              
                if ( $search =~ /com/ ) {
                    $mute{"com$id"} = $mute{"com$id"} ? 0 : 1;
                    print_output("NOTIFICATION", MUTE_COMMENT_ID);
                    return;
                }
              
                $mute{$id} = $mute{$id} ? 0 : 1;
                print_output("NOTIFICATION", MUTE_ID);
         }
         }
    elsif( $command =~ /\/roominfo (.+)/ )
         {
         return if $1 ne "on" or $1 ne "off";
         $option{roominfo} = $1 eq "on" ? 1 : 0;
         print_output("NOTIFICATION", ROOMINFO_ON);
         }
    elsif( $command eq "/shutup" )
         { $writesocketqueue->enqueue("SHUTUP"); }
    elsif( $command =~ /\/popup (.+)/ )
         {
         if   ( $1 eq "on" or $1 eq "off" )
              {
              $option{popup} = $1 eq "on" ? 1 : 0;
              print_output("NOTIFICATION", POPUP_ON);
              }
         elsif( $1 eq "all" )
              {
              $option{popup}    = 1;
              $option{popupall} = 1;
              }
         else {
              $option{popup} = 1;
              push(@popuptrigger, $1);
              }
         }
    elsif( $command eq "/open" )
         {
         $ENABLE_GRAPHIC_INTERFACE = 1;
         $sdlwindowthread = threads->create(\&sdl_window);
         }
    elsif( $command eq "/close" )
         {
         return if !$ENABLE_GRAPHIC_INTERFACE;
         
         $ENABLE_GRAPHIC_INTERFACE = 0;
         $event->type(SDL_QUIT);
         SDL::Events::push_event($event);
         }
    elsif( $command =~ /\/debug (.+)/ )
         {
         return if $1 ne "on" or $1 ne "off";
         $option{debug} = $1 eq "on" ? 1 : 0;
         print_output("NOTIFICATION", DEBUG_ON);
         }
    elsif( $command =~ /\/language/ )
         {
         $LANGUAGE = $LANGUAGE eq "english" ? "japanese" : "english";
         $ENCODING = $ENCODING eq "cp932"   ? "UTF-8"    : "cp932";
         }
    elsif( $command =~ /\/readonly (.+)/ )
         {
         return if $1 ne "on" or $1 ne "off";
         $option{readonly} = $1 eq "on" ? 1 : 0;
         $outputfield->Change(-readonly => $option{readonly});
         }
    elsif( $command =~ /\/backgroundcolor (.+)/ )
         {
         return if $1 !~ /#\d{6}/;
         $outputfield->SetBkgndColor($1);
         }
    elsif( $command =~ /\/getname (.+)/ )
         { search_trip($1); }
    elsif( $command =~ /\/gettrip (.+)/ )
         {
         my $search = $1;
         my $result;
         my @result;
         
         my $name = $search =~ /name (\d{1,3})/ ?
             encode("utf8", $1) :
             encode("utf8", $userdata->get_name($1));
         
         ### Load trip.txt
         open(TRIP, "<", "trip.txt");
         @triplist = <TRIP>;
         @triplist = grep(/(.+)\n/, @triplist);
         chomp(@triplist);
         close(TRIP);
         
         ### Search for name in trip.txt
         foreach my $line (@triplist)
             {
             if( $line =~ /\Q$name\E/ )
               {
               $result .= substr($line, 0, 10).", ";
               push(@result, substr($line, 0, 10));
               }
             }

         ### Delete the comma at the end 
         $result = substr($result, 0, -2);
         
         ### Print result
         $name = decode("utf8", $name);
         print_output("SEARCH", "$name: $result\n");
         search_trip($_) foreach (@result);
         }
    elsif( $command =~ /\/addname (\d{1,3}) (.+)/ )
         {
         if( !$option{savetrip} ) {
             print_output("ERROR", TRIP_NOT_ENABLED);
             return;
         }
         my $trip = length($1) == 10 ? $trip : $userdata->get_ihash($1);
         my $name = $2;
         $tripqueue->enqueue($trip, $name);
         }
    elsif( $command eq "/getroom" )
         { foreach my $id (keys %roomid) { print_data("USER", $id); } }
    elsif( $command =~ /\/save\s*(.*)/  )
         {
         my($second, $minute, $hour, $day, $month, $year) = localtime(time());
         system("mkdir LOG") if !-e "/LOG";
         
         ### If there is no filename, defaults to the rooms name
         my $name = $1 ? $1 : $logindata->get_room2();
         my $text = $outputfield->Text();
         
         ### Fix month and year format
         $month++;
         $year += 1900;
         local $filename  = "[$day-$month-$year ".$hour."h".$minute."m".$second."s"."] $name.txt";
         
         ### Save log
         open(CHATLOG, ">", "LOG/$filename") or print_output("ERROR", SAVELOG_ERROR);
         print CHATLOG $text;
         close(CHATLOG);
         print_output("NOTIFICATION", SAVELOG_SUCCESS) if -e "LOG/$filename";
         }
    elsif( $command eq "/exit" ) { die; } ### Not working
    else { print_output("ERROR", NO_COMMAND); }
    }

### Takes data from print_output and prints it on outputfield
###
### Takes:
### - array: An array sorted with a color/phrase scheme
### Returns:
### - Nothing
###
### Issues:
### - Nothing
###
sub print_list
    {
    my @arguments = @_;
    while(@arguments)
         {
         my $color = shift(@arguments)||"#000000";
         my $text  = shift(@arguments)||"";
         $text     = encode("cp932", $text);
         
         ### Parse the string (not currently implemented)
         if( $text =~ /&amp|&quot|&apos|&lt|&gt/ )
           {
           push(@arguments, "#FF0000");
           push(@arguments, "xml parse not currently supported: &\"'<>.\n");
           $text =~ s/&amp;/&/;
           $text =~ s/&quot;/"/;
           $text =~ s/&apos;/'/;
           $text =~ s/&lt;/</;
           $text =~ s/&gt;/>/;
           }
         
         ### Print in outputfield
         $outputfield->Select("-1", "-1");
         $outputfield->SetCharFormat(-color => $color);
         $outputfield->ReplaceSel($text);
         }
    }


### Sort data to send it to print_list
###
### Takes:
### - scalar: An option with the type of data to print
### - scalar: A color related to the user (optional)
### Returns:
### - Nothing
###
### Issues:
### - Nothing
###
sub print_output {
    my($option, $usercolor) = (shift, "");
    my $line = "-" x 191;
    
    ### Sets the user color
    if( $_[0] eq "USERCOLOR" ) {
        shift;
        $usercolor = shift;
        $usercolor = "#000000" if $usercolor eq "#FFFFFF" or $usercolor eq "#646464";
    }
    
    if( $option eq "USERDATA" ) {
        my($name, $trip, $ihash, $id, $status, $character, $x, $scl, $option) = @_;
      
        print_list("#000000", "--> ") if $option =~ ENTER and $id != $logindata->get_id();
        print_list(
            $usercolor||"#000000", $name,
            $usercolor||"#000000", "$trip$ihash",
            $usercolor||"#000000", " ($id)",
            $usercolor||"#000000", " $status",
            $usercolor||"#000000", " $character",
            $usercolor||"#000000", " x$x $scl",
            $usercolor||"#000000", $option
        );
        print_list("#0000FF", "$line\n\n") if $option =~ ENTER and $id == $logindata->get_id();
    }
    elsif( $option eq "COMMENT" ) {
        my($date, $name, $trip, $ihash, $id, $comment) = @_;
         
        print_list(
            "#000000", $date,
            $usercolor||"#000000", " $name",
            $usercolor||"#000000", "$trip$ihash",
            $usercolor||"#000000", " ($id)",
            "#000000", ": $comment"
        );
    }
    elsif( $option eq "IGNORE" ) {
        my($name, $ihash, $id, $ignore, $ignorecolor, $ignorename, $ignoreihash, $ignoreid) = @_;
        $ignorecolor = "#000000" if $ignorecolor eq "#FFFFFF" or $ignorecolor eq "#646464";
        $ignorega    = $LANGUAGE eq "japanese" ? GA : " $ignore";
        #$ignorename  = $LANGUAGE eq "japanese" ? "$ignorename" : " $ignorename"; ?
         
        print_list(
            $usercolor||"#000000", $name,
            $usercolor||"#000000", " $ihash",
            $usercolor||"#000000", " ($id)",
            "#000000", "$ignorega",
            $ignorecolor||"#000000", $ignorename,
            $ignorecolor||"#000000", " $ignoreihash",
            $ignorecolor||"#000000", " ($ignoreid)"
        ); 
        $LANGUAGE eq "japanese" ?
            print_list("#000000", "$ignore") :
            print_list("#000000", "\n");
    }
    elsif( $option eq "LOGIN" ) {
        my $text = shift;
        chomp($text);
         
        print_list(
            "#000000", "$line\n",
            "#000000", "$LOGINSPACE$text",
            "#000000", "$line\n"
        );
    }
    elsif( $option eq "ROOM" ) {
        my $text = shift;
        chomp($text);
         
        print_list(
            "#0000FF", "$line\n",
            "#0000FF", "$ROOMSPACE$text\n",
            "#0000FF", "$line\n"
        );
    }
    elsif( $option eq "EXIT" ) {
        my $text = shift;
        return if $text eq "\n"; # ?
         
        print_list(
            "#000000", "<-- ",
            $usercolor||"#000000", $text
        );
    }
    elsif( $option eq "SEARCH" ) {
        my $text = shift;
        chomp($text);
         
        print_list(
            "#FFFF00", "$line\n",
            "#FFFF00", "$text\n",
            "#FFFF00", "$line\n"
        );
    }
    else {
        my $text  = shift;
        my $color =
            $option eq "NOTIFICATION" ? "#0000FF" :
            $option eq "ENTER"        ? $usercolor||"#000000" :
            $option eq "CHANGE"       ? $usercolor||"#000000" :
            $option eq "RSET"         ? $usercolor||"#000000" :
            $option eq "ERROR"        ? "#FF0000" : "#000000";
        print_list($color, $text);
    }
}

### Login function, this function is never called from the main thread
###
### Takes:
### - scalar: option with FIRSTTIME (optional)
### Returns:
### - Nothing
###
### Issues:
### - Hangs up a lot when logging with a proxy, too slow
### - ^A bit better, but frequently relogs with the same proxy (14/11)
### - Use of initialized value $option in string eq at 340, 353, 356
### Login with proxies take too long, for some reason the connection is more unnestable than before?
###
sub login
    {
    my $option = shift||"";
    $pingsemaphore->down();
    $pingthread->kill("STOP");
    
    if( $proxy{on} ) {
      ### my $previousaddress; ?
      while() {
          ### Get proxy list if it's empty
          get_proxy_list() if !@proxyaddr or !@proxyport;
           
          ### Connect to the proxy
          $remote = IO::Socket::Socks->new(
              ProxyAddr    => $proxyaddr[0],
              ProxyPort    => $proxyport[0],
              ConnectAddr  => $socketdata{address},
              ConnectPort  => $socketdata{port},
              SocksDebug   => $proxy{debug},
              Timeout      => $proxy{timeout},
              SocksVersion => $proxy{version}
          ) or warn "$SOCKS_ERROR\n" and shift(@proxyaddr) and shift(@proxyport) and redo;
           
          ### Redo if skip is higher than 0
          if( $proxy{skip} or $proxy{change} ) {
              shift(@proxyaddr);
              shift(@proxyport);
              $proxy{skip}--;
              next;
          }
          print "Connected to proxy.\n";
          last;
      }
    }
    else {
        $remote = IO::Socket::INET->new(
            PeerAddr => $socketdata{address},
            PeerPort => $socketdata{port},
            Proto    => "tcp"
        ) or die "Couldn't connect: $!";
    }
    $select = IO::Select->new($remote);
    
    print $remote "MojaChat\0";
    $option eq "FIRSTTIME" ? enter_room("FIRSTTIME") : enter_room();
    $pingsemaphore->up();
    }

### Send monachat a signal to enter a room, if $option eq "REENTER" a exit signal is sent first,
### this signal is only not send the first time
###
### Takes:
### - scalar: option with FIRSTTIME (optional)
### Returns:
### - Nothing
###
### Issues:
### - Frequent infinite loop when declaring variables
### - ^Change doesn't work (16/11)
### - Trip doesn't change until relogin (16/11)
### - Use of initialized value $attrib at line 359 (?)
### - Use of initialized value ALL at 360 (?)
### - Wide character in print at line 573 (14/11)
### - Wide character in print at line 668 (16/11) when changing to a room with hiragana
### - Wide character in print at 805 with $name (24/11)
###
sub enter_room
    {
    my($option, $enter) = (shift||"", "");
    my $id     = $logindata->get_id();
    my $room   = $logindata->get_room2() eq "main" ?
        $logindata->get_room() :
        $logindata->get_room()."/".$logindata->get_room2();
    my $attrib = $logindata->get_attrib();
    my($name, $character, $status, undef, $ihash, $r, $g, $b, $x, $y, $scl) =
        $option eq "FIRSTTIME" ? $logindata->get_data() : $userdata->get_data($id);
    
    ### For the time being
    ($name, $character, $status, undef, $ihash, $r, $g, $b, $x, $y, $scl) = ("") x 11 if !$name;
    my $trip   = $logindata->get_trip();
    
    ### Set $option{room} to true so that a line is drawn in the screen
    $option{room} = 1;
    ### And empty rooms user list
    %roomid = ();
    ### Push a delete all room users event to SDL queue
    push_event(26, "all") if $ENABLE_GRAPHIC_INTERFACE;
    
    ### Send data
    print $remote qq{<EXIT no="$id" \/>\0} if $option eq "REENTER";
    if   ( $logindata->get_room2() eq "main" )
         { print $remote qq{<ENTER room="$room" name="$name" attrib="$attrib" />\0}; }
    else {
         no warnings;
         $enter  = qq{<ENTER room="$room" umax="0" type="$character" name="$name" };
         $enter .= qq{trip=\"$trip\" } if $trip ne "";
         $enter .= qq{x="$x" y="$y" r="$r" g="$g" b="$b" scl="$scl" stat="$status" />\0};
         print $remote $enter;
         }
    }

### Send x, y and scl(direction) signal to the server, calls to this function are in the format "x$x y$y scl$scl"
sub send_x_y_scl
    {
    my $line = shift;
    my $id   = $logindata->get_id();
    my $x    = $line =~ /x\s?(\d+)/     ? $1 : $userdata->get_x($id);
    my $y    = $line =~ /y\s?(\d+)/     ? $1 : $userdata->get_y($id);
    my $scl  = $line =~ /scl\s?(-?\d+)/ ? $1 : $userdata->get_scl($id);
    print $remote qq{<SET x="$x" scl="$scl" y="$y" />\0};
    }

### Search function, first searches the main room and stores room with users, then if $option{ALL} is
### true searches those rooms, if $option{USER $user} is on then stops if that user is found
###
### Takes:
### - scalar: Option with ALL or USER
### Returns:
### - Nothing
###
### Issues:
### - Not sure if ping problem while looping between all rooms is fixed
### - Search print probably doesn't work
sub search
    {
    local $option = shift||"";
    my($read, $counter, $end);
    local $room;
    local %roomdata;
    
    ### Moves to main room
    my $currentroom = $logindata->get_room2();
    $logindata->set_room2("main");
    enter_room("REENTER");
    sleep(2); ### With proxy, it's probably different without proxy
    
    ### Gets a list of rooms with users
    sysread($remote, $read, 20000) if $select->can_read();
    $read = decode("utf8", $read);
    while( $read =~ /<ROOM c="(.+?)" n="(.+?)" \/>/g )
         {
         local($room, $number) = ($2, $1);
         $roomdata{$room} = $number if $number != 0;
         }
         
    ### Goes through that list
    if( $option eq "ALL" )
      {
      foreach $room ( sort( keys %roomdata ) )
        {
        $logindata->set_room2($room);
        enter_room("REENTER");
        ### Checks for ping
        ### Issues:
        ### - Invalid argument(undef) when that index doesn't exist
        ###
        #for( my $counter; $writesocketqueue->peek($counter); $counter++ )
        #   {
        #   if( $writesocketqueue->peek($counter) eq "<NOP />" )
        #    {
        #    $writesocketqueue->extract($counter);
        #    print $remote "<NOP />\0";
        #    }
        #   }
        ### Gets and shows the list of users in each room
        sleep(2);
        sysread($remote, $read, 20000) if $select->can_read();
        $read = decode("utf8", $read);
        print_output("SEARCH", SEARCH_ROOM);
        
        while( $read =~ m/<(USER)\s r="(\d{1,3})"\s name="(.*?)"\s(.+?)stat="(.*?)"\s g="(\d{1,3})"\s
                          type="(.*?)"\s b="(\d{1,3})"\s y="(.*?)"\s x="(.*?)"\s scl="(.+?)"\s \/>/xg )
             {
             my($enteruser, $name, $idtripihash, $character, $status, $r, $g, $b, $x, $y, $scl) =
               ($1, $3, $4, $7, $5, $2, $6, $8, $10, $9, $11);
             my $id    = $idtripihash =~ /id="(\d{1,3})"/  ? $1 : "";
             my $trip  = $idtripihash =~ /trip="(.{10})"/  ? $1 : "";
             my $ihash = $idtripihash =~ /ihash="(.{10})"/ ? $1 : "";
             $userdata->set_data($name, $id, $character, $status, $trip, $ihash, $r, $g, $b, $x, $y, $scl);
             print_data($enteruser, $id);
             
             if( $option{searchuser} and $option{searchuser} eq $name ) { $end = 1; }
             }
        last if $end;
        }
      ### Stops if user is found
      if   ( $end )
           {
           print_output("SEARCH", SEARCH_USER_FOUND);
           $option{searchuser} = undef;
           }
      else { $logindata->set_room2($currentroom); }
      enter_room("REENTER");
      }
      
    ### Prints the results
    else {
         my $text;
         local $roomswithusers = scalar keys %roomdata;
         $logindata->set_room2($currentroom);
         enter_room("REENTER");
    
         $text = SEARCH_USER_NUMBER."\n";
         foreach $room ( sort( keys %roomdata ) )
           {
           $option = ++$counter < $roomswithusers ? ", " : "";
           $text .= SEARCH_RESULT;
           }
         
         print_output("SEARCH", "$text\n");
         }
    }

### Gets proxy list, this site blocks the user agent from LWP::Simple::get()
###
### Takes:
### - Nothing
### Returns:
### - Nothing
###
### Issues:
### - Maybe too little proxies
###
sub get_proxy_list
    {
    my $useragent = LWP::UserAgent->new();
    $useragent->agent("getproxylist");
    $useragent->show_progress(1);
    my $proxylist  = $useragent->get("http://socks-proxy.net");
    $proxylist     = $proxylist->content();
    @proxyaddr     = $proxylist =~ /<td>(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})<\/td><td>\d{4,5}<\/td>.+?Socks4/g;
    @proxyport     = $proxylist =~ /<td>\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}<\/td><td>(\d{4,5})<\/td>.+?Socks4/g;
    }

### Ping function, this function is only used as a separate thread
###
### Takes:
### - Nothing
### Returns:
### - Nothing
###
### Issues:
### - Can't write directly to socket, so it's a bit unreliable
###
sub ping {
    my $counter;
    while() {
        local $SIG{"STOP"} = sub {
            $pingsemaphore->down();
            $counter = 0;
            $pingsemaphore->up();
        };
         
        for( $counter = 0; $counter <= 100; $counter++ ) {
            select(undef, undef, undef, 0.2);
            $writesocketqueue->enqueue("<NOP />") if $counter >= 100;
        }
    }
}

### Stores all the names of an ihash
###
### Info:
###
### 1. Copies trip.txt to @array 
### 2. Loops for all the lines searching for a line that starts which $ihash
### 3. If it's found, searches for $name in that line
### 4. If there is a match, that name is appended to the list
### 5. If there isn't a match, a new line is appended to the end of trip.txt
### 6. Copies @array to trip.txt
###
### Takes:
### - scalar: ihash
### - scalar: name
### Returns:
### - Nothing
###
### Issues:
### - Doesn't really match names, but look inside them
###
sub trip_store
    {
    no warnings;
    while( my $ihash = $tripqueue->dequeue() )
         {
         my $name = $tripqueue->dequeue();
         
         ### Creates a new file and prints the ihash and name in it if it doesn't exist
         if( !-e "trip.txt" )
           {
           open(TRIP, ">", "trip.txt") or die "Couldn't create trip.txt\n";
           print TRIP "$ihash : $name";
           }
         else {
              open(TRIP, "<:encoding(UTF-8)", "trip.txt") or print_output("ERROR", TRIP_ERROR) and redo;
              my @trip = <TRIP>;
              print_output("ERROR", TRIP_ERROR) if $trip[0] eq "" or $trip[0] eq " " or !$trip[0];
              close(TRIP);
              
              ### Loops through the file to find the trip and create one if doesn't exist
              foreach my $line ( keys @trip )
                      {
                      chomp($trip[$line]);                      
                      if( $trip[$line] =~ /^\Q$ihash\E/)
                        {
                        $trip[$line] .= " : $name" if $trip[$line] !~ /\Q: $name\E/;
                        last;
                        }
                      elsif( !$trip[$line + 1] ) { push(@trip, "$ihash : $name"); }
                      }
              
              ### And prints @trip into trip.txt
              open(TRIP, ">", "trip.txt") or print_output("ERROR", TRIP_ERROR) and redo;
              chomp(@trip);
              if( $trip[0] eq "" or $trip[0] eq " " or !$trip[0] ) # if( $trip[0] !~ /^.{10}/ )
                {
                print_output("ERROR", TRIP_EMPTY);
                redo;
                }
              foreach my $line ( keys @trip )
                {
                my $endline = $trip[$line + 1] ? "\n" : "";
                print TRIP "$trip[$line]$endline";
                }
              close(TRIP);
              }
         }
    }

sub search_trip
    {
    my($search, $match) = (shift, 0);
    local $trip;
    my(@tripfile, @triplist);
         
    ### Push trips into an array
    if   ( $search =~ /^.{10}$/ )   { push(@triplist, $search); }
    elsif( $search =~ /^\d{1,3}$/ ) { push(@triplist, $userdata->get_ihash($search)); }
    elsif( $search eq "all" )       { push(@triplist, $userdata->get_ihash($_)) foreach (keys %roomid); }
    else { return; }
         
    ### Return if any trip has an incorrect format
    foreach $trip (@triplist)
        {
        if( length($trip) != 10 )
          {
          print_output("ERROR", TRIP_NOT_FOUND);
          return;
          }
        }
         
    ### Load file
    open(TRIP, "<:encoding(UTF-8)", "trip.txt") or print_output("ERROR", TRIP_ERROR) and return;
    @tripfile = <TRIP>;
    @tripfile = grep(/(.+?)\n/, @tripfile);
    chomp(@tripfile);
    close(TRIP);
         
    ### Search in trip.txt
    foreach $trip (@triplist)
        {
        foreach my $line (@tripfile)
            {
            next if $line !~ /^\Q$trip\E/;
                
            my($name, undef) = $userdata->get_data_by_ihash($trip);
            $line =~ s/^(.{10})/$name ($1)/;
            print_output("SEARCH", "$line\n");
                
            $match = 1;
            last;
            }
        if(!$match) { print_output("ERROR", TRIP_NOT_FOUND); }
        $match = 0;
        }
    }

### This is the main thread, login("firsttime") send login information from $logindata and not from $userdata,
### as there is no information stored in it yet, $starttime purpose is only to store time from the creation of
### the thread, this function tries to read from $writesocketqueue and send the argument to write_handler(),
### then try to read from socket with a timeout of 0.2s or so and send results to read_handler()
###
### Takes:
### - Nothing
### Returns:
### - Nothing
###
### Issues:
### - Uptime doesn't show correctly when relogging
###
sub read_socket
    {
    login("FIRSTTIME");
    my($read, $write);
    my $starttime = time();
    my @read;
    while()
         {
         local $SIG{"KILL"} = sub {
             $remote->close();
             print_output("NOTIFICATION", DISCONNECT);
         };
         local $SIG{"STOP"} = sub {
             local $second = time() - $starttime;
             local $minute = $second / 60;
             $second      %= 60;
             $starttime    = time();
             print_output("NOTIFICATION", RELOGIN);
             print_output("NOTIFICATION", UPTIME);
             login();
         };
         
         ### Send signal to write queue if there is any
         write_handler($write) if $write = $writesocketqueue->dequeue_nb();
         
         ### Read from socket
         if($select->can_read(0.2))
           {
           sysread($remote, $read, 20000);
           if(!$read) { login(); redo; } ### There are some errors with postfix form?
         
           ### And send to read handler
           $read = decode("utf8", $read) or warn "Couldn't decode: $!";
           @read = $read =~ /(<.+?>|\+connect id=\d{1,3}|Connection timeout\.\.)/g;
           read_handler(@read);
           }
         }
    }

### Prints user login data and calls user_code 25 to create a sprite, then checks if that users ihash exists
### in stalk or antistalk and if so, the id is added
###
### Takes:
### - scalar: ENTER or USER
### - scalar: id
### Returns:
### - Nothing
###
### Issues:
### - Argument "" isn't numeric at 528
###
sub print_data
    {
    my($enteruser, $id) = @_;
    my($name, $character, $status, $trip, $ihash, $r, $g, $b, $x, $y, $scl) = $userdata->get_data($id);
    local $room = $logindata->get_room2();
    if( $name ne $userdata->get_name($id) )
      { ($name, $character, $status, $trip, $ihash, $r, $g, $b, $x, $y, $scl) = $userdata->get_data($id); }
    $scl       = $scl eq "100" ? LEFT : RIGHT;
    $trip      = $trip eq "" ? " " : " $trip ";
    $enteruser = $enteruser eq "ENTER" ? ENTER : "\n";
    
    if( $option{room} )
      {
      ### Issues:
      ### - Change space indentation to print_output() with japanese ?
      ### - Don't work correctly when there is no </ROOM> signal
      #$room = $logindata->get_room2() if !$room;
      print_output("ROOM", ROOM);
      $option{room} = 0;
      }
      
    print_output("USERDATA", "USERCOLOR", $userdata->get_hex_rgb($id), $name, $trip, $ihash, $id, $status,
                 $character, $x, $scl, $enteruser);
    
    $roomid{$id} = 1;
    if( $ENABLE_GRAPHIC_INTERFACE )
      {
      $eventsemaphore->down();
      push_event(25, $id);
      }
    
    $name = "null"                     if !$name;
    $tripqueue->enqueue($ihash, $name) if $option{savetrip};
    $userdata->set_stalk($id)          if $option{stalk}     and $userdata->get_stalk($userdata->get_ihash($id));
    $userdata->set_antistalk($id)      if $option{antistalk} and $userdata->get_antistalk($userdata->get_ihash($id));
    }

### Handles information sent from read_socket()
###
### Takes:
### - scalar: A signal or xml data
### Returns:
### - Nothing
###
### Issues:
### - $write !~ />$/ : ?
### - Maybe there are issues with the first chomp
###
sub write_handler
    {
    my $write = shift;
    
    if   ( $write eq "REENTER"  ) { enter_room("REENTER"); }
    elsif( $write eq "SETXYSCL" ) { send_x_y_scl($writesocketqueue->dequeue()); }
    elsif( $write eq "SEARCH"   ) { search($writesocketqueue->dequeue()); }
    elsif( $write eq "SHUTUP"   ) { for (1..9) { print $remote "<RSET cmd=\"go\" param=\"$_\" />\0"; } }
    elsif( $write eq "IGNORE"   )
         {
         my $id    = $writesocketqueue->dequeue();
         my $ihash = $userdata->get_ihash($id);
         my $stat  = $userdata->get_ignore($ihash, $id) ? "off" : "on";
         print "id: $id ihash: $ihash, stat: $stat\n";
         print $remote qq{<IG ihash="$ihash" stat="$stat" />\0};
         }
    elsif( $write eq "COMMENT"  )
         {
         $write = encode("utf8", $writesocketqueue->dequeue());
         $write =~ s/&/&amp;/;
         $write =~ s/#/&#35;/;
         $write =~ s/"/&#34;/;
         $write =~ s/'/&#39;/;
         $write =~ s/</&#60;/;
         $write =~ s/>/&#62;/;
         my $xml = qq{<COM cmt="$write" />\0};
         print $remote $xml if $select->can_write();
         }
    else {
         $write .= $writesocketqueue->dequeue() if ($write !~ />$/) and ($write ne "MojaChat"||"");
         chomp($write);
         print $remote "$write\0" if $select->can_write();
         }
    }

### Handles information send from read_socket()
###
### Signals:
### - +connect id="ID"          : Sent when you connect to the server
### - <CONNECT id="ID" />       : Same
### - <ROOM>, <ROOM />, </ROOM> : Room count ?/When you enter the room/When sending the rooms user list
### - <USER|ENTER r="RED" name="NAME" id="ID" trip="TRIP" ihash="IHASH" stat|status="STATUS" g="GREEN"
###   type="CHARACTER" b="BLUE" y="Y" x="X" scl="SCL" /> :
###   Login data, login when someone enters the room, user when someone is already in
### - <USER ihash="IHASH" name="NAME" id="ID" />, <ENTER id="ID" /> : Sent when someone enters main
### - <UINFO name="NAME" id="ID" />         : Sent when you enter main room, your name and id
### - <SET stat="STAT" id="ID" />           : Status change
### - <SET x="X" scl="SCL" id="ID" y="Y" /> : Position change
### - <IG ihash="IHASH" id="ID" />          : Ignore signal
### - <EXIT />, <EXIT id="ID" />            : Sent when you / someone exits the room
### - <COUNT>, <COUNT />, </COUNT>          : Count start / end
### - <ROOM c="COUNT" n="NUMBER" />         : Room number and user count
### - <COM cmt="COMMENT" id="ID" >          : Comment signal, there are various patterns
###
### Issues:
### - Some signals are repeated or have an unknown meaning
### - Antistalk is bad implemented
### - There are three kind of comment signals
### - Not sure if the signal repair function works correctly
### - There are times when your login data isn't sent and therefore the <\ROOM> endline isn't shown in screen
### - Use of initialized value $name, $ihash in concatenation or string at 689
### - Argument "" isn't numeric at 966, 971
### - Argument "100" escap..." isn't numeric ne (!=)at
### - <SET cmd="ev" pre="0" param="0" id=\d{1,3} /> - ?
###
sub read_handler
    {
    my @read = @_;
    while( @read )
         {
         print_output("NOTIFICATION", $read[0]) if $option{debug};
         if   ( $read[0] =~ /\+connect id=\d{1,3}/ ) {}
         elsif( $read[0] =~ /<CONNECT id="(.+?)" \/>/ )
              {
              $logindata->set_id($1);
              print_output("LOGIN", LOGGED_IN);
              }
         elsif( $read[0] =~ /<ENTER id="(.+?)" \/>/ )
              {
              $roomid{$1} = 1;
              print_output("ENTER", ENTER_ROOM_ID) if $logindata->get_room2() eq "main";
              }
         elsif( $read[0] =~ /<UINFO name="(.*?)" id="(\d{1,3})" \/>/ )
              {
              print_output("ROOM", UINFO) if $logindata->get_room2() eq "main";
              }
         elsif( $read[0] eq "<ROOM>" ) ### Sent when you enter the room
              {
              ### ?
              #$option{room} = 1;
              #my $room2 = $logindata->get_room2();
              #print_output("ROOM", ROOM);
              }
         elsif( $read[0] eq "<ROOM />" ) {} ### Sent when you exit the room
         elsif( $read[0] =~ /<ROOM c="(.+?)" n="(.+?)" \/>/ ) ### There is a necessity for this one?
              {
              my $room = $logindata->get_room2();
              print_output("ROOM", ROOM_USER) if $option{roominfo} or $room eq "main" and $1 != 0;
              }
         elsif( $read[0] eq "</ROOM>" ) {} ### Sent when sending the room user list
         elsif( $read[0] =~ /<COUNT>/ )
              {
              #print_output("ROOM", "Rooms:\n");
              while( $read[0] !~ /<\/COUNT>/ )
                   {
                   print_output("ROOM", ROOM_USER) if $read[0] =~ /<ROOM c="(.+?)" n="(.+?)" \/>/;
                   shift(@read);
                   }
              }
         elsif( $read[0] =~ /<\/COUNT>/  ) {} ### In main
         #elsif( $read[0] =~ /<COUNT \/>/ ) {} ### Is this necessary?
         elsif( $read[0] =~ /<COUNT c="(.+?)" n="(.+?)"\s?\/?>/ )
              {
              ### Text corruption before encode triggers warnings
              no warnings;
              print_output("ROOM", ROOM_USER) if $option{roominfo};
              $eventdata{room}    = $2;
              $eventdata{persons} = $1;
              
              my $title  = TITLE_ROOM;
              $title    .= " [TRIP off]" if !$option{savetrip};
              $title     = encode("cp932", $title);
              $window->Text($title);
              push_event(24) if $ENABLE_GRAPHIC_INTERFACE;
              }
         elsif( $read[0] =~ m/<(\w{4,5})\s r="(.*?)"\s name="(.*?)"\s(.+?)stat="(.*?)"\s g="(.*?)"\s
                              type="(.*?)"\s b="(.*?)"\s y="(.*?)"\s x="(.*?)"\s scl="(.*?)"\s\/>/x )
              {
              my($enteruser, $name, $idtripihash, $character, $status, $r, $g, $b, $x, $y, $scl) =
                ($1, $3, $4, $7, $5, $2, $6, $8, $10, $9, $11);
              my $id    = $idtripihash =~ /id="(\d{1,3})"/  ? $1 : "";
              my $trip  = $idtripihash =~ /trip="(.{10})"/  ? $1 : "";
              my $ihash = $idtripihash =~ /ihash="(.{10})"/ ? $1 : "";
              
              $userdata->set_data($name, $id, $character, $status, $trip, $ihash, $r, $g, $b, $x, $y, $scl);
              print_data($enteruser, $id);
              }    
         elsif( $read[0] =~ /<SET stat="(.*?)" id="(.+?)" \/>/ )
              {
              ### Issues:
              ### - Wide character in print at 1122 with $status (24/11)
              local($status, $id) = ($1, $2);
              local $name        = $userdata->get_name($id);
              local $trip        = $userdata->get_trip($id);
              local $ihash       = $userdata->get_ihash($id);
              local $hexrgb      = $userdata->get_hex_rgb($id);
              $trip            = $trip ne "" ? " $trip " : " ";
              
              $userdata->set_status($status, $id);
              print_output("CHANGE", "USERCOLOR", $hexrgb, CHANGE_STAT) if !$option{mute} and !$mute{$id};
              push_event(24) if $ENABLE_GRAPHIC_INTERFACE;
              }
         elsif( $read[0] =~ /<SET x="(.*?)" scl="(.*?)" id="(\d{1,3})" y="(.*?)" \/>/ )
              {
              ### -100 isn't numeric
              no warnings;
              local($x, $scl, $id, $y) = ($1, $2, $3, $4);
              local $name              = $userdata->get_name($id);
              local $trip              = $userdata->get_trip($id);
              local $ihash             = $userdata->get_ihash($id);
              my $loginid              = $logindata->get_id();
              my $hexrgb               = $userdata->get_hex_rgb($id);
              $trip                    = $trip ? " $trip " : " ";
              
              ### Check if x, y or scl have changed
              if( $userdata->get_x($id) != $x )
                {
                $userdata->set_x($x, $id);
                print_output("CHANGE", "USERCOLOR", $hexrgb, SET_X) if !$option{mute} and !$mute{$id};
                }
              if( $userdata->get_y($id) != $y )
                {
                $userdata->set_y($y, $id);
                print_output("CHANGE", "USERCOLOR", $hexrgb, SET_Y) if !$option{mute} and !$mute{$id};
                }
              if( $userdata->get_scl($id) != $scl )
                {
                $userdata->set_scl($scl, $id);
                $scl = $scl == 100 ? LEFT : RIGHT;
                print_output("CHANGE", "USERCOLOR", $hexrgb, SET_SCL) if !$option{mute} and !$mute{$id};
                }
              
              ### Send event to SDL queue
              push_event(27, $id) if $ENABLE_GRAPHIC_INTERFACE;
              
              ### Stalk or antistalk
              if( $option{stalk} and !$option{nomove} and $userdata->get_stalk($id) )
                {
                my $line = "x$x"."y$y"."scl$scl";
                send_x_y_scl($line);
                }
              if( $option{antistalk} and $userdata->get_antistalk($id) )
                {
                if( $userdata->get_x($id) - $x < 40 and $userdata->get_x($id) - $x > -40 )
                  { $userdata->set_x(680-$x+40, $loginid); }
                if( $userdata->get_y($id) - $y < 40 and $userdata->get_y($id) - $y > -40 )
                  { $userdata->set_y(320-$y+240, $loginid); }
                send_x_y_scl();
                }
              }
         elsif( $read[0] =~ /<IG ihash="(.{10})" stat="(.+)" id="(\d{1,3})" \/>/ )
              {
              my($ignoreihash, $stat, $id) = ($1, $2, $3);
              my($ignorename, $ignoreid)   = $userdata->get_data_by_ihash($ignoreihash);
              my $name                     = $userdata->get_name($id);
              my $ihash                    = $userdata->get_ihash($id);
              my $hexrgb                   = $userdata->get_hex_rgb($id);
              my $ignorehexrgb             = $userdata->get_hex_rgb($ignoreid);
              my $ignore                   = $stat eq "on" ? IGNORE : NO_IGNORE;
              
              $userdata->set_ignore($ignoreihash, $stat, $id);
              print_output("IGNORE", "USERCOLOR", $hexrgb, $name, $ihash, $id, $ignore,
                           $ignorehexrgb, $ignorename, $ignoreihash, $ignoreid);
              
              if( ($option{antiignore} and $userdata->get_antiignore($id)) or $option{antiignoreall} )
                { login(); }
              }
         elsif( $read[0] =~ /<RSET cmd="go" param="(.+)" id="(\d{1,3})" \/>/ )
              {
              my $hexrgb = $userdata->get_hex_rgb($2);
              print_output("RSET", "USERCOLOR", $hexrgb, SAITAMA);
              }
         elsif( $read[0] =~ /^<SET cmd="ev"/ )
              {
              ### <SET cmd="ev" id="\d{1,3}" />
              ### <SET cmd="ev" pre="0|1" param="0|1" id="\d{1,3}" />
              ### <SET cmd="ev" set="start|wait" param="start|wait" id="\id{1,3}" />
              #if( !$option{mute} and !$mute{$id} ) { print_output("NOTIFICATION", $read[0]) };
              }
         elsif( $read[0] eq "<EXIT />" )
              {
              print_output("EXIT", EXIT_ROOM);
              %roomid = ();
              }
         elsif( $read[0] =~ /<EXIT id="(.+?)" \/>/ )
              {
              local $id   = $1;
              my $loginid = $logindata->get_id();
              
              if( $id != $loginid )
                {
                ### Double comprobation with $hexrgb
                local $name   = $userdata->get_name($id)    || "";
                local $trip   = $userdata->get_trip($id)    || "";
                local $ihash  = $userdata->get_ihash($id)   || "";
                my    $hexrgb = $userdata->get_hex_rgb($id) || "#000000";
                $trip = $trip =~ /^.{10}$/ ? " $trip " : " ";
                print_output("EXIT", "USERCOLOR", $hexrgb, EXIT_ROOM_ID);
                }
              else { print_output("EXIT", "\n"); }
              
              delete $roomid{$id};
              push_event(26, $id) if $ENABLE_GRAPHIC_INTERFACE;
              }
         elsif( $read[0] =~ /<COM cmt="(.+?)".+?id="(.+?)".+?\/>/ ) ### There are three comment patterns
              {
              #<COM cmt"(.+?)" id="(.+?)" cnt="(.+?)" \/>
              #<COM cmt="(.+?)" cnt="(.+?)" id="(.+?)" \/>
              #<COM cmt="(.+?)" id="(.+?)" \/>
              my($comment, $id) = ($1, $2);
              my $name    = $userdata->get_name($id);
              my $trip    = $userdata->get_trip($id);
              my $ihash   = $userdata->get_ihash($id);
              my $hexrgb  = $userdata->get_hex_rgb($id);
              
              ### Form hour
              my($second, $minute, $hour) = localtime(time());
              $trip     = $trip ? " $trip " : " ";
              $second   = $second =~ /^\d$/ ? "0$second" : $second;
              $minute   = $minute =~ /^\d$/ ? "0$minute" : $minute;
              $hour     = $hour   =~ /^\d$/ ? "0$hour"   : $hour;
              my $date  = "[$hour:$minute:$second]";
              my $line  = "$date $name$trip$ihash ($id): $comment";
              
              ### Print comment
              if( !$mute{"com$id"} ) {
                  print_output("COMMENT", "USERCOLOR", $hexrgb, $date, $name, $trip, $ihash, $id, "$comment\n");
              }
              
              ### Stalk if the id is the same
              if ( $option{stalk} and $userdata->get_stalk($id) )
                 {
                 $comment = encode("utf8", $comment);
                 $writesocketqueue->enqueue("<COM cmt=\"$comment\" />");
                 }
                 
              ### Search for the comment for triggers and show a popup if matches
              if( $option{popup} )
                {
                chomp($line);
                chomp(@popuptrigger);
                $line = substr($line, 11);
                $line = encode("cp932", $line);
                
                if   ($option{popupall})
                     {
                     $notifyicon->Change("-balloon_tip", $line);
                     $notifyicon->ShowBalloon();
                     }
                else {
                     foreach my $trigger (@popuptrigger)
                       {
                       next if $comment !~ /$trigger/i;
                       $notifyicon->Change("-balloon_tip", $line);
                       $notifyicon->ShowBalloon();
                       }
                     }
                }
              }
         elsif( $read[0] eq "Connection timeout.." )
              {
              print_output("NOTIFICATION", TIMEOUT);
              login();
              }
         elsif( $read[0] =~ /^<R|^<USER/ ) ### For fixing broken signals
              {
              my $line = shift(@read) . $read[0];
              
              $line = $line.">" if $line !~ />$/;
              if   ( $line =~ /<ROOM c="(.+?)" n="(.+?)" \/>/ )
                   { print_output("ROOM", ROOM_USER) if $1 != 0; }
              elsif( $line =~ m/<(\w{4,5})\s r="(.*?)"\s name="(.*?)"\s(.+?)stat="(.*?)"\s g="(.*?)"\s
                                type="(.*?)"\s b="(.*?)"\s y="(.*?)"\s x="(.*?)"\s scl="(.*?)"\s \/>/x )
                   {
                   my($enteruser, $name, $idtripihash, $character, $status, $r, $g, $b, $x, $y, $scl) =
                     ($1, $3, $4, $7, $5, $2, $6, $8, $10, $9, $11);
                   my $id    = $idtripihash =~ /id="(\d{1,3})"/  ? $1 : "";
                   my $trip  = $idtripihash =~ /trip="(.{10})"/  ? $1 : "";
                   my $ihash = $idtripihash =~ /ihash="(.{10})"/ ? $1 : "";
                   $userdata->set_data($name, $id, $character, $status, $trip, $ihash, $r, $g, $b, $x, $y, $scl);
                   print_data($enteruser, $id);
                   }
              else { print_output("NOTIFICATION", "$line\n"); }
              }
         else { print_output("NOTIFICATION", "$read[0]\n"); }
         shift(@read);
         }
    }

### Stores command line arguments into $argument
###
### Takes:
### - @ARGV
### Returns:
### - Nothing
###
### Issues:
### - Nothing
###
sub get_argument
    {
    while( @ARGV )
         {
         if( $ARGV[0] =~ m/(-proxy|-timeout|-ip|-port|-debug|-change|-skip|-savetrip|-name|
                            -character|-status|-trip|-x|-y|-scl|-attrib)/x )
           {
           shift(@ARGV);
           $1 eq "-proxy"     ? $argument{proxy}     = $ARGV[0] :
           $1 eq "-timeout"   ? $argument{timeout}   = $ARGV[0] :
           $1 eq "-ip"        ? $argument{address}   = $ARGV[0] :
           $1 eq "-port"      ? $argument{port}      = $ARGV[0] :
           $1 eq "-debug"     ? $argument{debug}     = $ARGV[0] :
           $1 eq "-change"    ? $argument{change}    = $ARGV[0] :
           $1 eq "-skip"      ? $argument{skip}      = $ARGV[0] :
           $1 eq "-savetrip"  ? $argument{savetrip}  = $ARGV[0] :
           $1 eq "-name"      ? $argument{name}      = $ARGV[0] :
           $1 eq "-character" ? $argument{character} = $ARGV[0] :
           $1 eq "-status"    ? $argument{status}    = $ARGV[0] :
           $1 eq "-trip"      ? $argument{trip}      = $ARGV[0] :
           $1 eq "-x"         ? $argument{x}         = $ARGV[0] :
           $1 eq "-y"         ? $argument{y}         = $ARGV[0] :
           $1 eq "-scl"       ? $argument{scl}       = $ARGV[0] :
           $1 eq "-attrib"    ? $argument{attrib}    = $ARGV[0] : undef;
           }
         elsif( $ARGV[0] eq "-rgb" )
              {
              shift(@ARGV); $argument{r} = $ARGV[0];
              shift(@ARGV); $argument{g} = $ARGV[0];
              shift(@ARGV); $argument{b} = $ARGV[0];
              }
         elsif( $ARGV[0] eq "-room" )
              {
              shift(@ARGV);
              ($argument{room1}, $argument{port}) =
                  $ARGV[0] eq "iriguchi"     ? ("MONA8094",    9095) :
                  $ARGV[0] eq "atochi"       ? ("ANIKI8088",   9083) :
                  $ARGV[0] eq "ooheya"       ? ("MONABIG8093", 9093) :
                  $ARGV[0] eq "chibichato"   ? ("ANIMAL8098",  9090) :
                  $ARGV[0] eq "moa"          ? ("MOA8088",     9092) :
                  $ARGV[0] eq "chiikibetsu"  ? ("AREA8089",    9095) :
                  $ARGV[0] eq "wadaibetsu"   ? ("ROOM8089",    9090) :
                  $ARGV[0] eq "tateyokoheya" ? ("MOXY8097",    9093) :
                  $ARGV[0] eq "cool"         ? ("COOL8099",    9090) :
                  $ARGV[0] eq "kanpu"        ? ("kanpu8000",   9094) :
                  $ARGV[0] eq "monafb"       ? ("MOFB8000",    9090) : (undef, undef);
              shift(@ARGV) if $argument{room1};
              $argument{room2} = $ARGV[0];
              }
         else { die "Command not recognized: $ARGV[0].\n"; }
         shift(@ARGV);
         }
    }
    

### Push an event into the SDL event queue
sub push_event
    {
    if( $ENABLE_GRAPHIC_INTERFACE == 1 )
      {
      my($usercode, $id) = @_;
      $eventdata{id}     = $id if $id;
      $event->user_code($usercode);
      SDL::Events::push_event($event);
      }
    }

### Redraws the screen
###
### Issues:
### - Redraw the entire screen every time is horribly inefficient
###
sub draw_screen
    {
    my($event, $window) = @_;
    my($room, $persons) = ($eventdata{room}, $eventdata{persons});
    my $text = SDLx::Text->new(
      font => "C:\\Windows\\Fonts\\msgothic.ttc",
      h_align => "center",
      color   => [0, 0, 0, 0],
      size    => 14 );
    
    $window->draw_rect([0, 0, $window->w(), $window->h()], [255, 255, 255, 0]);
    $text->write_xy($window, 540, 20, "room $room persons $persons");
    foreach my $id (keys %roomdata)
            {
            my($name, $character, $status, $trip, $ihash, $r, $g, $b, $x, $y, $scl) = $userdata->get_data($id);
            ($x, $y) = ($roomdata{$id}->x(), 275);
            $roomdata{$id}->draw($window);
            $text->write_xy( $window, $x + $roomdata{$id}->w() / 2, $y - 20, $name )   if $name;
            $text->write_xy( $window, $x + $roomdata{$id}->w() / 2, $y, $ihash  )      if $ihash;
            $text->write_xy( $window, $x + $roomdata{$id}->w() / 2, $y + 20, $status ) if $status;
            }
    $window->update();
    }

### Handles SDL events
###
### Handles:
###
### - user_code 24: Calls draw_screen() function
### - user_code 25: Creates a character sprite, for some reason it crashes a lot
### - user_code 26: Deletes a user or all from the room
### - user_code 27: Changes x, y, and scl of an user and redraws the screen
### - user_code 30: ?
###
### Takes:
### - object ref: Event handle
### - object ref: Window handle
### Returns:
### - Nothing
###
### Issues:
### - Mouse click area is too wide and do not match the character
### - Y not implemented yet, so for the time being let's stuck to y = 135
### - Scl not implemented either
### - Can't call method "x" on an undefined value at 906
###
sub event_handler
    {
    my($event, $window) = @_;
    #print "event type: ", $event->type(), "\n";
    if   ( $event->type() == SDL_QUIT    ) { $window->stop(); }
    elsif( $event->type() == SDL_KEYDOWN ) { print $event->key_sym(), "\n"; }
    elsif( $event->type() == SDL_MOUSEBUTTONUP )
         {
         $eventdata{movecharacter} = 0;
         my $id   = $logindata->get_id();
         my $line = "x".$roomdata{$id}->x();
         $writesocketqueue->enqueue("SETXYSCL", $line);
         }
    elsif( $eventdata{movecharacter} or ($event->type() == SDL_MOUSEBUTTONDOWN and
           $event->button_button() == SDL_BUTTON_LEFT) )
         {
         my $id = $logindata->get_id();
         #my $pixel = $roomdata{$id}->surface->get_pixel($event->button_x() + $event->button_y() * $window->w());
         #my($r, $g, $b, $a) = SDL::Video::get_RGBA($roomdata{$id}->surface->format(), $pixel);
         #die "pixel: ", $r[0][0]," ", $r[0][1], " ", $r[0][2], " ", $a[0][3], "\n";
         if( $event->button_x() > $roomdata{$id}->x() and $event->button_x() < $roomdata{$id}->x() + 128 and
             $event->button_y() > $roomdata{$id}->y() and $event->button_y() < $roomdata{$id}->y() + 128 )
           { $eventdata{movecharacter} = 1; }        
         if( $eventdata{movecharacter} == 1 )
           {
           $roomdata{$id}->x($event->button_x());
           draw_screen($event, $window);
           }
         }
    elsif( $event->user_code() == 24 )
         { draw_screen($event, $window); }
    elsif( $event->user_code() == 25 )
         {
         my $id        = $eventdata{id};
         my $character = "character//" . $userdata->get_character($id) . ".png";
         my($x, $y)    = $userdata->get_x_y_scl($id);
         while( !$roomdata{$id} )
              {
              $roomdata{$id} = SDLx::Sprite->new(
                width  => 128,
                height => 128 );
              }
         if( -e $character ) { $roomdata{$id}->load($character) or warn "Couldn't load $character\n"; }
         $x = $x ? $x : int(rand(400)); ### If x is null, x is equal to a random value between 0 and 400
         $roomdata{$id}->x($x);
         $roomdata{$id}->y(135);
         #$roomdata{$id}->y($y - 140);
         draw_screen($event, $window);
         $eventsemaphore->up();
         }
    elsif( $event->user_code() == 26 )
         { $eventdata{id} eq "all" ? %roomdata = () : delete $roomdata{$eventdata{id}}; }
    elsif( $event->user_code() == 27 )
         {
         my $id = $eventdata{id};
         my($x, $y) = $userdata->get_x_y_scl($id);
         $roomdata{$id}->x($x);
         $roomdata{$id}->y(135);
         #$roomdata{$id}->y($y - 140);
         #if( $eventdata{flip} == 1 ) { $roomdata{$id}->flip(); $eventdata{flip} = 0;}
         draw_screen($event, $window);
         }
    #elsif( $event->user_code() == 30 )
    #     {
    #    my $x = $window->x();
    #    my $y = $window->y();
    #    print "x: $x, y: $y\n";
    #    }
    }

### Creates a SDL window, this function is only called to create a thread
###
### %roomdata: Local variable used to store sprites in the current room
sub sdl_window {
    my %roomdata;
    my $window = SDLx::App->new(
        width  => 620,
        height => 320,
        name   => "Monachat"
    );
    $window->update();
    $window->add_event_handler(\&event_handler);
    $window->run();
}



#-------------------------------------------------------------------------------------------------------------------



share(%argument);          ### Command line arguments
share(%option);            ### Options of things too small to own their own variables
share(%socketdata);        ### The default ip and port address
share(%proxy);             ### Proxy options
share(%roomid);            ### Users in the current room
share(%eventdata);         ### Shared global variable for the SDL event loop
share(%mute);              ### Users muted (?)
share(@proxyaddr);         ### List of ip addresses retrieved by get_proxy_list()
share(@proxyport);         ### List of ip ports retrieved by get_proxy_list()
share(@inputline);         ### Previous comments
share(@popuptrigger);      ### List of strings that trigger an allarm
share($inputcounter);      ### Counter for @inputline, though there is no need for this to be shared

get_argument();

### Get config file
open(CONFIG, "<:encoding($ENCODING)", "config.txt") or die "Couldn't open config file: $!\n";
for my $line (<CONFIG>)
     {
     chomp($line);
     if( $line =~ /^(.+) = (.+)$/ )
       {
       my($option, $parameter) = ($1, $2);
       $parameter = (!$parameter or $parameter eq "\"\"") ? undef : $parameter;
       if   ( $option eq "trigger" ) { @popuptrigger = split(/ : /, $parameter); }
       else { $config{$option} = $parameter; }
       }
     }
close(CONFIG);

### Create the main Win32::GUI window
###
### Issues:
### - Scroll in $outputfield not working initially, starts working once it's scrolled manually once
$window = Win32::GUI::Window->new(
    -name   => "Window",
    -title  => "Monachat",
    -height => 320,
    -width  => 620
);
if( $config{popup} ) {
    $taskbaricon = Win32::GUI::Icon->new("GUIPERL.ICO");
    $notifyicon  = $window->AddNotifyIcon(
        -icon            => $taskbaricon,
        -name            => "NotifyIcon",
        -tip             => "Monachat",
        -balloon         => 1,
        -balloon_timeout => 4
    );
}
$inputfield = $window->AddTextfield(
    -name        => "Inputfield",
    -height      => 30,
    -width       => 598,
    -left        => 2,
    -top         => 240,
    -multiline   => 0,
    -autohscroll => 1
);
$outputfield = $window->AddRichEdit(
    -name        => "Outputfield",
    -height      => 220,
    -width       => 598,
    -left        => 2,
    -top         => 10,
    -multiline   => 1,
    -readonly    => 1,
    -vscroll     => 1,
    #-class       => "RichEdit20A", ### Japanese characters appear too small
    -autovscroll => 1
);

### Set gui options
$inputfield->SetLimitText(50);                             ### Set inputfield limit to 50
$inputfield->SetFocus();                                   ### Set focus on inputfield on startup
$outputfield->SetCharFormat( -name => "MS Shell Dlg" );    ### Set font to MS Shell Dlg
$outputfield->SetBkgndColor($config{backgroundcolor});     ### Set background color

### Enable URL clicking
$outputfield->SetTextMode(1, 1);
$eventmask = $outputfield->GetEventMask();
$outputfield->SetEventMask($eventmask | ENM_LINK);
$outputfield->Hook(EN_LINK, \&Outputfield_URL);
$outputfield->AutoURLDetect();

$window->Center();
$window->Show();


### $logindata only stores initial login data
$logindata = Userdata->new_login_data(
    $argument{name}      || $config{name},
    $argument{character} || $config{character},
    $argument{status}    || $config{status},
    $argument{trip}      || $config{trip},
    $argument{r}         || $config{r},
    $argument{g}         || $config{g},
    $argument{b}         || $config{b},
    $argument{x}         || $config{x},
    $argument{y}         || $config{y},
    $argument{scl}       || $config{scl},
    $argument{room1}     || $config{room1},
    $argument{room2}     || $config{room2},
    $argument{attrib}    || $config{attrib}
) or die "Couldn't create logindata.\n";

### $userdata stores all user data, including own
$userdata =  Userdata->new_user_data() or die "Couldn't create userdata.\n";

%socketdata = (
    address => $argument{address} || $config{address} || "153.122.46.192",
    port    => $argument{port}    || $config{port}    || 9095
);
%proxy = (
    on      => $argument{proxy}      || $config{proxy}   || 0,
    timeout => $argument{timeout}    || $config{timeout} || 1,
    debug   => $argument{debug}      || $config{debug}   || 0,
    change  => $argument{change}     || $config{change}  || 0,
    skip    => $argument{skip}       || 0,
    version => $config{socksversion} || 4
);
%option = (
    mute     => $config{mute}       || 0,
    popup    => $config{popup}      || 0,
    roominfo => $config{roominfo}   || 0,
    savetrip => $argument{savetrip} || $config{savetrip} || "no",
    readonly => 1,
    debug    => 0
);
  
$proxy{on}        = $proxy{on}        eq "yes" ? 1 : 0; #
$proxy{debug}     = $proxy{debug}     eq "yes" ? 1 : 0; #
$option{savetrip} = $option{savetrip} eq "yes" ? 1 : 0; # 

### $pingsemaphore:    Used to restart the ping thread
### $eventsemaphore:   Used to prevent %eventdata being accessed before SDL event handler uses them
### $writesocketqueue: Queues all the socket write requests
### $tripqueue:        Queues all the trip store requests
$pingsemaphore    = Thread::Semaphore->new();
$eventsemaphore   = Thread::Semaphore->new();
$writesocketqueue = Thread::Queue->new();
$tripqueue        = Thread::Queue->new() if $option{savetrip};
 
if( $ENABLE_GRAPHIC_INTERFACE == 1 )
  {
  $event = SDL::Event->new();
  $sdlwindowthread = threads->create(\&sdl_window);
  }

threads->create(\&trip_store) if $option{savetrip};
$pingthread        = threads->create(\&ping);
$readsocketthread  = threads->create(\&read_socket);

### Hooks WM_MOVE to Window_Move()
$window->Hook(3, \&Window_Move);
Win32::GUI->Dialog();
