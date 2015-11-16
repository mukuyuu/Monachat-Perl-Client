use strict;
no strict "vars"; ### Because of continous global variable errors
use warnings;
use diagnostics;
use Socket;
use IO::Socket;
use IO::Socket::Socks;
use IO::Select;
use threads;
use threads::shared qw(share);
use Thread::Semaphore;
use Thread::Queue;
use Encode qw(encode decode);
use Win32::GUI;
use Win32::GUI::Constants;
#use Win32::Sound;
use LWP::UserAgent;
#use Imager;
use Userdata;

open(CONFIG, "<", "config.txt") or die "Couldn't open config.txt.";
for my $line (<CONFIG>)
    {
	if( $line =~ /^graphicinterface = (\d)$/ )
	  { $ENABLE_GRAPHIC_INTERFACE = $1; last; }
	}
close(CONFIG);

if( $ENABLE_GRAPHIC_INTERFACE ) ### Doesn't work, modules are loaded at compile time
  {
  use SDL;
  use SDL::Surface;
  use SDL::Video;
  use SDL::Color;
  use SDL::Event;
  use SDL::Events;
  use SDLx::App;
  use SDLx::Rect;
  use SDLx::Sprite;
  use SDLx::Text;
  }

### Write the date everytime the program is executed
open(LOG, ">", "log.txt") or die "Couldn't open log.txt: $!";
(undef, undef, undef, $DAY, $MONTH, $YEAR) = localtime(time());
$YEAR = substr($YEAR, 1);
print LOG "[$DAY/$MONTH/$YEAR]\n";
close(LOG);

### So that errors are written in log.txt
$SIG{__WARN__} = sub { my($second, $minute, $hour) = localtime(time());
                       open(LOG, ">>", "log.txt");
					   print LOG "[$hour:$minute:$second] Warning: @_";
                       print "Warning: ", @_;
					   close(LOG); };
$SIG{__DIE__}  = sub { my($second, $minute, $hour) = localtime(time());
                       open(LOG, ">>", "log.txt");
					   print LOG "[$hour:$minute:$second] Error: @_";
                       print "Error: ", @_;
					   close(LOG); };

### The event loop in Win32::GUI is ended when -1 is returned
sub Window_Terminate { return -1; }

sub Window_Minimize
    {
	$window->Disable();
	$window->Hide();
	}

### Window move event, returns window position as an array with [up, down, left right]
sub Window_Move
    {
	my($window) = shift;
    my(@position) = $window->GetWindowRect();
	print "$position[0], $position[1], $position[2], $position[3]\n";
    };

sub NotifyIcon_Click
    {
	$window->Enable();
	$window->Show();
	}

### So that inputfield never loses focus
sub Inputfield_LostFocus { $inputfield->SetFocus(); }

### If enter(13) is pressed send the text and erases inputfield
### If up(38) is pressed loop between previous comments upside
### If down(40) is pressed loop between previous comments downside
### Issues:
### - Annoying sound when pressing enter
### - When looping between @inputline elements upside cursor position isn't in the last position
### - Also you can't move between $inputfield positions with left and right
### - /change doesn't work
sub Inputfield_KeyDown
    {
    shift;
    my($key) = shift;
    if( $key == 13 )
      {
      my($text) = $inputfield->Text();
	  if( $text )
	    {
		chomp($text);
		if( $inputline[9] ) { pop(@inputline); }
		unshift(@inputline, $text);
		
		$text = decode("cp932", $text) or die "Couldn't encode: $!\n";
        if( $text =~ /^\// )
	      { command_handler($text); }
        else {
		     #if( $text =~ /a/ ) { push_event(30); }
	         $text = encode("utf8", $text) or die "Couldn't encode: $!\n";
	         $writesocketqueue->enqueue("<COM cmt=\"$text\" />");
	         }
        $inputfield->SelectAll();
        $inputfield->ReplaceSel("");
		}
     }
   elsif( $key == 38 )
        {
		#$inputfield->ScrollCaret();
		my($text) = $inputfield->Text() || "";
		$text = decode("utf8", $text);
		if( $inputfield == 0 ) { unshift(@inputline, $text); }
		if( $inputline[$inputcounter + 1] )
		  {
		  $inputcounter++;
		  $inputfield->SelectAll();
		  $inputfield->ReplaceSel($inputline[$inputcounter]);
		  }
		}
   elsif( $key == 40 )
        {
		if( $inputline[$inputcounter - 1] )
		  {
		  $inputcounter--;
		  $inputfield->SelectAll();
		  $inputfield->ReplaceSel($inputline[$inputcounter]);
		  }
		}
   }
### Handles $inputfield input
### Issues:
### - Trip search in /addname not yet implemented
### - Antistalk not well implemented
sub command_handler
    {
    my($command) = shift;
	my($loginid) = $logindata->get_id();
    if( $command eq "/login" )
	  { $readsocketthread->kill("STOP"); }
    elsif( $command =~ /\/relogin\s*(.*)/ )
	     {
		 if( $1 =~ /skip (\d+)/ ) { $proxy{skip} = $1; }
	     $readsocketthread->kill("STOP");
	     }
	elsif( $command eq "/reenter" )
	     { $writesocketqueue->enqueue("REENTER"); }
    elsif( $command =~ /\/disconnect\s*(\d*)/ )
	     {
	     $writesocketqueue->enqueue("<EXIT />", "<NOP />", "<NOP />");
		 $readsocketthread->kill("KILL");
	     }
    elsif( $command =~ /\/name (.+)/ )
	     {
		 my($name) = $1;
		 if( length($name) <= 20 )
		   {
	       $userdata->set_name($name, $loginid);
	       $writesocketqueue->enqueue("REENTER");
		   }
		 else { print_output("ERROR", "Name is too large.\n"); }
	     }
    elsif( $command =~ /\/character (.+)/ )
	     {
	     my($character) = $1;
	     $userdata->set_character($character, $loginid);
	     $writesocketqueue->enqueue("REENTER");
	     }
    elsif( $command =~ /\/stat (.+)/ )
	     {
		 my($status) = $1;
		 if( length($status) <= 20 )
		   { $writesocketqueue->enqueue("<SET stat=\"$status\" />"); }
		 else { print_output("ERROR", "Status is too large.\n"); }
		 }
	elsif( $command =~ /\/trip (.+)/ )
	     {
		 my($trip) = $1;
		 if( $trip eq " " or $trip eq "" or !$trip) { $logindata->set_trip(""); }
		 else { $logindata->set_trip($trip); }
		 $writesocketqueue->enqueue("REENTER");
		 }
    elsif( $command =~ /\/room (.+)/ )
	     {
	     my($room) = $1;
	     $logindata->set_room2($room);
	     $writesocketqueue->enqueue("REENTER");
	     }
    elsif( $command =~ /\/rgb (\d{1,3}|x) (\d{1,3}|x) (\d{1,3}|x)/ )
	     {
		 my($r) = $1 eq "x" ? $userdata->get_r($loginid) : $1;
		 my($g) = $2 eq "x" ? $userdata->get_g($loginid) : $2;
		 my($b) = $3 eq "x" ? $userdata->get_b($loginid) : $3;
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
         my($scl) = $userdata->get_scl($loginid) == 100 ? "-100" : 100;
         $writesocketqueue->enqueue("SETXYSCL", "scl$scl");
	     }
    elsif( $command eq "/attrib" )
	     {
	     my($attrib) = $userdata->set_attrib($loginid) eq "on" ? "off" : "on";
	     $writesocketqueue->enqueue("REENTER");
	     }
    elsif( $command =~ /\/ignore (\d{1,3})/ )
	     {
		 my($id)      = $1;
	     my($ihash)   = $userdata->get_ihash($id);
		 my($status)  = $userdata->get_ignore($ihash, $id) ? "off" : "on";
	     $writesocketqueue->enqueue("<IG ihash=\"$ihash\" stat=\"$status\" />");
	     }
    elsif( $command =~ /\/search (.+)/ )
	     {
		 if   ( $1 eq "print" ) { $option{searchprint} = 1; }
		 if   ( $1 eq "main"  ) { $writesocketqueue->enqueue("SEARCHMAIN"); }
	     elsif( $1 eq "all"   ) { $writesocketqueue->enqueue("SEARCHALL"); }
	     elsif( $1 =~ /user (.+)/ )
		      {
			  $option{searchuser} = $1;
			  $writesocketqueue->enqueue("SEARCHALL");
			  }
	     }
    elsif( $command =~ /\/stalk (.+)/ )
	     {
	     if( $1 eq "on" or $1 eq "off"  )
		   {
		   $option{stalk} = $1 eq "on" ? 1 : 0;
		   print_output("NOTIFICATION", "Stalk $1.\n");
		   }
	     elsif( $1 eq "nomove" )
	          { $option{nomove} = $option{nomove} ? 0 : 1; }
	     elsif( $1 =~ /(\d{1,3})/ )
	          {
			  my($id)          = $1;
			  my($x, $y, $scl) = $userdata->get_x_y_scl($id);
	          my($line)        = "x$x"."y$y"."scl$scl";
			  $option{stalk}   = 1;
	          $userdata->set_stalk($id);
              $writesocketqueue->enqueue("SETXYSCL", "$line");
			  print_output("NOTIFICATION", "Stalk id $id.\n");
	          }
	     }
    elsif( $command =~ /\/antistalk (.+)/ )
	     {
		 if   ( $1 eq "on" or $1 eq "off"  )
		      {
			  $option{antistalk} = $1 eq "on" ? 1 : 0;
			  print_output("NOTIFICATION", "Antistalk $1.\n");
			  }
	     elsif( $1 =~ /(\d{1,3})/ )
	          {
		      my($id) = $1;
		      $option{antistalk} = 1;
		      $userdata->set_antistalk($id);
			  print_output("NOTIFICATION", "Antistalk id $id.\n");
	          }
	     }
    elsif( $command =~ /\/copy (.+)/ )
	     {
         my($id) = $1;
	     $userdata->copy($id, $loginid);
		 $writesocketqueue->enqueue("REENTER");
	     }
    elsif( $command eq "/default" )
	     {
	     $userdata->default($logindata);
		 $option{stalk}  = 0;
		 $option{nomove} = 0;
		 $option{antiignore} = 0;
		 $option{antiignoreall} = 0;
		 $writesocketqueue->enqueue("REENTER");
		 }
	elsif( $command eq "/invisible" )
		 {
		 $userdata->invisible($loginid);
		 $writesocketqueue->enqueue("REENTER");
		 }
    elsif( $command =~ /\/proxy\s*(.*)/ )
		 {
	     if( $1 eq "on" or $1 eq "off" )
	       {
		   $proxy{on} = $1 eq "on" ? 1 : 0;
		   print_output("NOTIFICATION", "Proxy $1\n");
		   }
	     elsif( $1 =~ /timeout (\d\.*\d*)/ ) { $proxy{timeout} = $1; }
		 elsif( $1 =~ /change (.+?)/ )
		      {
			  $proxy{change} =
			    $1 eq "on"  ? 1 :
				$1 eq "off" ? 0 : $proxy{change};
			  }
		 $readsocketthread->kill("STOP");
	     }
    elsif( $command =~ /\/clear (.+)/ )
		 {
		 if( $1 eq "screen" )
	       {
	       $outputfield->SelectAll();
		   $outputfield->ReplaceSel("");
	       }
		 elsif( $1 eq "userdata" )
	          {
              undef $userdata;
              $userdata = Userdata->new_user_data();
			  enter_room("reenter");
	          }
		 }
    elsif( $command =~ /\/new\s*(.*)/ )
		 {
		 ### It would be better if a instance skipped the ip other instances are currently using
		 my($search) = $1;
		 if( $search =~ /skip (\d+)/ ) { $proxy{skip} = $1; }
		 if( $search =~ /here\s*(.*)/ )
	       {
	       my($newinstancecounter) = $1||1;
		   my($room) = $logindata->get_room2();
	       for( my($counter) = 0; $counter < $newinstancecounter; $counter++ )
	          {
	          system("start perl monachat.pl -proxy -room $room");
	          sleep(2);
	          }
	       }
	     else { system("start perl monachat.pl -proxy"); }
	     }
    elsif( $command =~ /\/antiignore (.+)/ )
	     {
		 if( $1 eq "on" or $1 eq "off" )
		   {
		   $option{antiignore} = $1 eq "on" ? 1 : 0;
		   if( $1 eq "off" ) { $option{antiignoreall} = 0; }
		   print_output("NOTIFICATION", "Antiignore $1.\n");
		   }
		 elsif( $1 =~ /(\d{1,3})/ )
		      {
		      my($id) = $1;
	          $option{antiignore} = 1;
			  $userdata->set_antiignore($id);
			  print_output("NOTIFICATION", "Antiignore id $id.\n");
	          }
	     elsif( $1 =~ /all/ )
	          { $option{antiignoreall} = $option{antiignoreall} ? 0 : 1; }
	     }
	elsif( $command =~ /\/mute (.+)/ )
	     {
		 $option{mute} =
		   $1 eq "on"  ? 1 :
		   $1 eq "off" ? 0 : $option{mute};
		 if( $1 eq "on" or $1 eq "off" ) { print_output("NOTIFICATION", "Mute $1.\n"); }
		 elsif( $1 =~ /^(\d{1,3}$)/ )
		      {
			  $mute{$1} = $mute{$1} ? 0 : 1;
			  $mute{$1} ?
			  print_output("NOTIFICATION", "id $1 has been mutted.\n") :
			  print_output("NOTIFICATION", "id $1 has been unmutted.\n") ;
			  }
		 }
	elsif( $command =~ /\/roominfo (.+)/ )
	     {
		 $option{roominfo} =
		   $1 eq "on"  ? 1 :
		   $1 eq "off" ? 0 : $option{roominfo};
		 if( $1 eq "on" or $1 eq "off" ) { print_output("NOTIFICATION", "Room information $1.\n"); }
		 }
	elsif( $command eq "/shutup" )
	     { $writesocketqueue->enqueue("SHUTUP"); }
	elsif( $command =~ /\/popup (.+)/ )
	     {
		 if( $1 eq "on" or $1 eq "off" )
		   {
		   $option{popup} = $1 eq "on" ? 1 : 0;
		   print_output("NOTIFICATION", "Popup $1.\n");
		   }
		 else {
		      $option{popup} = 1;
			  push(@popuptrigger, $1);
			  }
		 }
	elsif( $command eq "/open" )
	     { $sdlwindowthread = threads->create(\&sdl_window); }
	elsif( $command eq "/close" )
	     {
		 if( $ENABLE_GRAPHIC_INTERFACE )
		   {
		   $event->type(SDL_QUIT);
		   SDL::Events::push_event($event);
		   }
		 }
	elsif( $command =~ /\/debug (.+)/ )
	     {
		 $option{debug} =
		   $1 eq "on"  ? 1 :
		   $1 eq "off" ? 0 : $option{debug};
		 if( $option{debug} ) { print_output("NOTIFICATION", "Debug on.\n"); }
		 else { print_output("NOTIFICATION", "Debug off.\n"); }
		 }
	elsif( $command =~ /\/backgroundcolor (.+)/ )
	     { $outputfield->SetBkgndColor($1); }
	elsif( $command =~ /\/getname (.{1,10})/ )
	     {
		 my($match);
		 my($search) = $1;
		 my($trip)   = $search =~ /^(\d{1,3})$/ ? $userdata->get_ihash($1) : $search||"";
		 if( $trip =~ /.{10}/ )
		   {
		   open(TRIP, "<", "trip.txt") or print_output("ERROR", "Couldn't open trip.txt.\n") and last;
		   for my $line (<TRIP>)
		       {
			   if( $line =~ /^\Q$trip\E/ )
			     {
				 chomp($line);
				 $line = decode("utf8", $line);
			     print_output("SEARCH", "$line\n");
			     $match = 1;
			     last;
			     }
			   }
		   if( !$match ) { print_output("ERROR", "Trip $trip not found.\n"); }
		   close(TRIP);
		   }
		 else { print_output("ERROR", "Trip with id $trip doesn't exist\n"); }
		 }
	elsif( $command =~ /\/addname (\d{1,3}) (.+)/ )
	     {
		 my($trip) = $userdata->get_ihash($1);
		 my($name) = $2;
		 #my($trip) = $trip =~ /^(\d{1,3})$/ ? $userdata->get_ihash($1) : $trip;
         $tripqueue->enqueue($trip, $name);		 
		 }
	elsif( $command eq "/getroom" )
	     { foreach my $id (keys %roomid) { print_data("USER", $id); } }
	elsif( $command =~ /\/save\s*(.*)/  )
	     {
		 my($name) = $1 ? $1 : $logindata->get_room2();
		 my($text) = $outputfield->Text();
		 my($second, $minute, $hour, $day, $month, $year) = localtime(time());
		 my($filename) = "[$day-$month-$year ".$second."s".$minute."m".$hour."h"."] $name.txt";
		 if( !-e "/LOG" ) { system("mkdir LOG"); }
		 open(CHATLOG, ">", "LOG/$filename") or print_output("ERROR", "Couldn't save log: $!\n");
		 print CHATLOG $text;
		 close(CHATLOG);
		 if( -e "LOG/$filename" ) { print_output("NOTIFICATION", "Log saved as $filename\n"); }
		 }
	elsif( $command eq "/exit" ) { die; }
	else { print_output("ERROR", "Command $command not recognized.\n"); }
    }

sub print_list
    {
	my(@arguments) = @_;
	while(@arguments)
	     {
		 my($color) = shift(@arguments)||"#000000";
		 my($text)  = shift(@arguments)||"";
		 $text = encode("cp932", $text);
		 $outputfield->Select("-1", "-1");
		 $outputfield->SetCharFormat(-color => $color);
		 $outputfield->ReplaceSel($text);
		 }
	}

### Prints output to $outputfield
### Maybe encodings cause errors to japanese users?
sub print_output
    {
	my($option) = shift;
	my($usercolor);
	my($line) = "-" x 191;
	if( $_[0] eq "USERCOLOR" )
	  {
	  shift;
	  $usercolor = shift;
	  if( $usercolor eq "#FFFFFF" or $usercolor eq "#646464" ) { $usercolor = "#000000"; }
	  }
	if( $option eq "USERDATA" )
	  {
	  my($name, $trip, $ihash, $id, $status, $character, $x, $scl, $option) = @_;
	  if( $option =~ /has logged in/ and $id != $logindata->get_id() ) { print_list( "#000000", "--> "); }
	  print_list(
	    $usercolor||"#000000", "$name",
		$usercolor||"#000000", "$trip$ihash",
		$usercolor||"#000000", " ($id)",
		$usercolor||"#000000", " $status",
		$usercolor||"#000000", " $character",
		$usercolor||"#000000", " x$x $scl",
		$usercolor||"#000000", "$option" );
	  if( $option =~ /has logged in/ and $id == $logindata->get_id() ) { print_list( "#0000FF", "$line\n\n"); }
	  }
	elsif( $option eq "COMMENT" )
	     {
	     my($date, $name, $trip, $ihash, $id, $comment) = @_;
	     print_list(
	       "#000000", $date,
		   $usercolor||"#000000", " $name",
		   $usercolor||"#000000", "$trip$ihash",
		   $usercolor||"#000000", " ($id)",
		   "#000000", ": $comment" );
	     }
	elsif( $option eq "IGNORE" )
	     {
		 my($name, $ihash, $id, $ignore, $ignorecolor, $ignorename, $ignoreihash, $ignoreid) = @_;
		 if( $ignorecolor eq "#FFFFFF" or $ignorecolor eq "#646464" ) { $ignorecolor = "#000000"; }
		 print_list(
		   $usercolor||"#000000", $name,
		   $usercolor||"#000000", " $ihash",
		   $usercolor||"#000000", " ($id)",
		   "#000000", " $ignore",
		   $ignorecolor||"#000000", " $ignorename",
		   $ignorecolor||"#000000", " $ignoreihash",
		   $ignorecolor||"#000000", " ($ignoreid)\n" );
		 }
	elsif( $option eq "LOGIN" )
	     {
		 my($text) = shift;
		 my($space) = " " x 80;
		 chomp($text);
		 print_list(
		   "#000000", "$line\n",
		   "#000000", "$space$text",
		   "#000000", "$line\n" );
		 }
	elsif( $option eq "ROOM" )
	     {
		 my($text) = shift;
		 my($space) = $text =~ /^ROOM/ ? " " x 86 : " " x 80;
		 chomp($text);
		 print_list(
		   "#0000FF", "$line\n",
		   "#0000FF", "$space$text\n",
		   "#0000FF", "$line\n" );
		 }
	elsif( $option eq "EXIT" )
	     {
		 my($text) = shift;
		 if( $text ne "\n" )
		   {
		   print_list(
		     "#000000", "<-- ",
		     $usercolor||"#000000", $text );
		   }
		 }
	elsif( $option eq "SEARCH" )
	     {
		 my($text) = shift;
		 chomp($text);
		 print_list(
		   "#FFFF00", "$line\n",
		   "#FFFF00", "$text\n",
		   "#FFFF00", "$line\n" );
		 }
	else {
	     my($text) = shift;
	     my($color) =
		   $option eq "NOTIFICATION" ? "#0000FF" :
		   $option eq "ENTER"        ? $usercolor||"#000000" :
		   $option eq "CHANGE"       ? $usercolor||"#000000" :
		   $option eq "RSET"         ? $usercolor||"#000000" :
		   $option eq "EXIT"         ? $usercolor||"#000000" :
		   $option eq "ERROR"        ? "#FF0000" : "#000000";
		 $text = encode("cp932", $text);
		 $outputfield->Select("-1", "-1");
		 $outputfield->SetCharFormat(-color => $color);
		 $outputfield->ReplaceSel($text);
		 }
    }

### Login function, this function is never called from the main thread
### Login with proxies take too long, for some reason the connection is more unnestable than before?
### Issues:
### - Hangs up a lot when logging with a proxy, too slow
### - ^A bit better, but frequently relogs with the same proxy (14/11)
### - Use of initialized value $option in string eq at 340, 353, 356
sub login
    {
    my($option) = shift||"";
	$pingsemaphore->down();
	$pingthread->kill("STOP");
    
	if( $proxy{on} )
      {
	  my($previousaddress);
      while()
           {
           if( !@proxyaddr ) { get_proxy_list(); }
           $remote = IO::Socket::Socks->new(
			 ProxyAddr    => $proxyaddr[0],
	         ProxyPort    => $proxyport[0],
	         ConnectAddr  => $socketdata{address},
	         ConnectPort  => $socketdata{port},
	         SocksDebug   => $proxy{debug},
	         Timeout      => $proxy{timeout},
			 SocksVersion => $proxy{version} )
           or warn "$SOCKS_ERROR\n" and shift(@proxyaddr) and shift(@proxyport) and redo;
           if( $proxy{skip} > 0 or $proxy{change} )
		     { shift(@proxyaddr); shift(@proxyport); $proxy{skip}--; redo; }
		   last;
           }
      }
    else {
         $remote = IO::Socket::INET->new(
		   PeerAddr => $socketdata{address},
	       PeerPort => $socketdata{port},
	       Proto    => "tcp" )
	       or die "Couldn't connect: $!";
         }
    $select = IO::Select->new($remote);
	
	print $remote "MojaChat\0";
	$option eq "firsttime" ? enter_room("firsttime") : enter_room();
	$pingsemaphore->up();
    }

### Send monachat a signal to enter a room, if $option eq "reenter" a exit signal is sent first,
### this signal is only not send the first time
### Issues:
### - Frequent infinite loop when declaring variables
### - ^Change doesn't work (16/11)
### - Trip doesn't change until relogin (16/11)
### - Use of initialized value $attrib at line 359 (?)
### - Use of initialized value ALL at 360 (?)
### - Wide character in print at line 573 (14/11)
### - Wide character in print at line 668 (16/11) when changing to a room with hiragana
sub enter_room
    {
    my($option) = shift||"";
	my($id)     = $logindata->get_id();
	my($room)   = $logindata->get_room2() eq "main" ?
	              $logindata->get_room() :
	              $logindata->get_room()."/".$logindata->get_room2();
	my($attrib) = $logindata->get_attrib();
	my($name, $character, $status, $trip, $ihash, $r, $g, $b, $x, $y, $scl) =
	  $option eq "firsttime" ? $logindata->get_data() : $userdata->get_data($id);
	### For the time being
	if( !$name ) { ($name, $character, $status, $trip, $ihash, $r, $g, $b, $x, $y, $scl) = ("") x 11; }
	my($trip) = $logindata->get_trip();
	$option{room} = 1;
	%roomid = ();
	if( $ENABLE_GRAPHIC_INTERFACE ) { push_event(26, "all"); }
	
	if( $option eq "reenter" ) { print $remote "<EXIT no=\"$id\" \/>\0"; }
	if( $logindata->get_room2() eq "main" )
	  { print $remote "<ENTER room=\"$room\" name=\"$name\" attrib=\"$attrib\" />\0"; }
    else {
	     if( $trip eq "" )
		   {
		   print $remote
		     "<ENTER room=\"$room\" umax=\"0\" type=\"$character\" name=\"$name\" x=\"$x\" ",
		     "y=\"$y\" r=\"$r\" g=\"$g\" b=\"$b\" scl=\"$scl\" stat=\"$status\" />\0";
		   }
	     else {
		      print $remote
		        "<ENTER room=\"$room\" umax=\"0\" type=\"$character\" name=\"$name\" trip=\"$trip\" ",
		        "x=\"$x\" y=\"$y\" r=\"$r\" g=\"$g\" b=\"$b\" scl=\"$scl\" stat=\"$status\" />\0";
			  }
		 }
    }

### Send x, y and scl(direction) signal to the server, calls to this function are in the format "x$x y$y scl$scl"
sub send_x_y_scl
    {
	my($line) = shift;
	my($id) = $logindata->get_id();
	my($x)   = $line =~ /x\s?(\d+)/     ? $1 : $userdata->get_x($id);
	my($y)   = $line =~ /y\s?(\d+)/     ? $1 : $userdata->get_y($id);
	my($scl) = $line =~ /scl\s?(-?\d+)/ ? $1 : $userdata->get_scl($id);
    print $remote "<SET x=\"$x\" scl=\"$scl\" y=\"$y\" />\0";
    }

### Search function, first searches the main room and stores room with users, then if $option{SEARCHALL} is
### true searches those rooms, if $option{USER $user} is on then stops if that user is found
### Issues:
### - Not sure if ping problem while looping between all rooms is fixed
### - Search print probably doesn't work
sub search
    {
	my($option) = shift||"";
	my($read, $counter);
	my($currentroom) = $logindata->get_room2();
	my(%roomdata);
	
	$logindata->set_room2("main");
	enter_room("reenter");
	if( $select->can_read() )
      {
	  sleep(2); ### With proxy, it's probably different without proxy
	  sysread($remote, $read, 20000);
	  $read = decode("utf8", $read);
      while( $read =~ /<ROOM c="(.+?)" n="(.+?)" \/>/g )
           {
           my($room, $number) = ($2, $1);
           if( $number != 0 ) { $roomdata{$room} = $number; }
           }
      }

    if( $option eq "SEARCHALL" )
      {
      foreach my $key ( sort( keys %roomdata ) )
              {
              $logindata->set_room2($key);
			  enter_room("reenter");
			  ### Checks for ping
              if( $select->can_read() )
			    {
				for( my($counter); $writesocketqueue->peek($counter); $counter++ )
				   {
				   if( $writesocketqueue->peek($counter) eq "<NOP />" )
				     {
					 $writesocketqueue->extract($counter);
					 print $remote "<NOP />\0";
					 }
				   }
                sleep(1);
                sysread($remote, $read, 20000);
                $read = decode("utf8", $read);
				print_output("SEARCH", "Room $key:\n");
                while( $read =~ m/<(USER)\s r="(\d{1,3})"\s name="(.*?)"\s(.+?)stat="(.*?)"\s g="(\d{1,3})"\s
				                  type="(.*?)"\s b="(\d{1,3})"\s y="(.*?)"\s x="(.*?)"\s scl="(.+?)"\s \/>/xg )
                     {
			         my($enteruser, $name, $idtripihash, $character, $status, $r, $g, $b, $x, $y, $scl) =
			           ($1, $3, $4, $7, $5, $2, $6, $8, $10, $9, $11);
			         my($id)    = $idtripihash =~ /id="(\d{1,3})"/  ? $1 : "";
			         my($trip)  = $idtripihash =~ /trip="(.{10})"/  ? $1 : "";
			         my($ihash) = $idtripihash =~ /ihash="(.{10})"/ ? $1 : "";
			         $userdata->set_data($name, $id, $character, $status, $trip, $ihash, $r, $g, $b, $x, $y, $scl);
			         print_data($enteruser, $id);
			         if( $option{searchuser} and $option{searchuser} eq $name )
					   {
					   $option{end} = 1;
					   last;
					   }
	                 }
				}
			  if( $option{end} ) { last; }
	          }
	  if( $option{end} )
	    {
		my($line) = "User ".$option{searchuser}." found.\n";
		print_output("SEARCH", $line);
		enter_room("reenter");
		$option{searchuser} = undef;
		$option{end} = 0;
		}
	  else {
	       $logindata->set_room2($currentroom);
	       enter_room("reenter");
		   }
	  }
    else {
	     my($text);
	     $logindata->set_room2($currentroom);
         enter_room("reenter");
    
	     my($roomswithusers) = scalar keys %roomdata;
         if  ( $option{searchprint} )
             { print $remote "<COM cmt=\"There are $roomswithusers rooms with people:\" />\0"; }
         #else{ print_output("SEARCH", "There are $roomswithusers rooms with people:\n"); }
         else{ $text = "There are $roomswithusers rooms with people:\n\n"; }
		 foreach my $key ( sort( keys %roomdata ) )
                 {
                 if( $option{searchprint} )
                   {
				   my($line) = "room $key: $roomdata{$key}";
				   if( length($line) > 50 )
				     {
					 my(@line) = split(/.{50}/, $line);
					 for( my($counter); $line[$counter]; $counter++ )
					    { print $remote "<COM cmt=\"$line[$counter]\" />\0"; }
					 }
				   else { print $remote "<COM cmt=\"$line\" />\0"; }
                   if( ++$counter < $roomswithusers ) { sleep(1); }
                   }
                 else {
			          my($option) = ++$counter < $roomswithusers ? ", " : "";
                      $text .= "room $key: $roomdata{$key}$option";
					  #print_output("SEARCH", "room $key: $roomdata{$key}$option");
                      }
                 }
		 if( !$option{searchprint} ) { print_output("SEARCH", "$text\n") };
         $option{searchprint} = 0;
	     }
	}

### Gets proxy list, this site blocks the user agent from LWP::Simple::get()
sub get_proxy_list
    {
	my($useragent) = LWP::UserAgent->new();
	$useragent->agent("getproxylist");
	$useragent->show_progress(1);
    my($proxylist) = $useragent->get("http://www.socks-proxy.net");
	$proxylist     = $proxylist->content();
    @proxyaddr     = $proxylist =~ /<td>(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})<\/td><td>\d{4,5}<\/td>.+?Socks4/g;
    @proxyport     = $proxylist =~ /<td>\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}<\/td><td>(\d{4,5})<\/td>.+?Socks4/g;
	}

### Ping function, this function is only used as a separate thread
sub ping
    {
	my($counter);
    while()
	     {
		 local $SIG{"STOP"} = sub {
		   $pingsemaphore->down();
		   $counter = 0;
		   $pingsemaphore->up(); };
	     
		 for( $counter = 0; $counter <= 100; $counter++ )
	        {
	        select(undef, undef, undef, 0.2);
	        if( $counter >= 100 )
			  { $writesocketqueue->enqueue("<NOP />"); }
	        }
	     }
    }

### Stores all the names of an ihash
### 1. Copies trip.txt to @array 
### 2. Loops for all the lines searching for a line that starts which $ihash
### 3. If it's found, searches for $name in that line
### 4. If there is a match, that name is appended to the list
### 5. If there isn't a match, a new line is appended to the end of trip.txt
### 6. Copies @array to trip.txt
sub trip_store
    {
	### Wide character in print at 640
	no warnings;
	while( my($ihash) = $tripqueue->dequeue() )
	     {
		 my($name) = $tripqueue->dequeue();
	     if( !-e "trip.txt" )
		   {
		   open(TRIP, ">", "trip.txt") or die "Couldn't create trip.txt\n";
		   print TRIP "$ihash : $name";
		   }
		 else {
		      open(TRIP, "<:encoding(UTF-8)", "trip.txt") or print_output("ERROR", "Couldn't open trip.txt.\n")
			                                              and redo;
	          my(@trip) = <TRIP>;
			  if($trip[0] eq "" or $trip[0] eq " " or !$trip[0])
			    { print_output("ERROR", "Couldn't load trip.txt.\n"); }
	          close(TRIP);
	          foreach my $line ( keys @trip )
			          {
				      chomp($trip[$line]);
				      if( $trip[$line] =~ /^\Q$ihash\E/)
				        {
					    if( $trip[$line] !~ /\Q: $name\E/ ) { $trip[$line] .= " : $name"; }
					    last;
					    }
				      elsif( !$trip[$line + 1] ) { push(@trip, "$ihash : $name"); }
			          }
	          open(TRIP, ">", "trip.txt") or print_output("ERROR", "Couldn't open trip.txt.\n") and redo;
	          chomp(@trip);
			  if( $trip[0] eq "" or $trip[0] eq " " or !$trip[0] )
			  { print_output("ERROR", "Couldn't load trip.txt.\n"); redo; }
		      foreach my $line ( keys @trip )
		              {
				      if( $trip[$line + 1] ) { print TRIP "$trip[$line]\n"; }
				      else { print TRIP "$trip[$line]"; }
				      }
		      close(TRIP);
			  }
		 }
	}

### This is the main thread, login("firsttime") send login information from $logindata and not from $userdata,
### as there is no information stored in it yet, $starttime purpose is only to store time from the creation of
### the thread, this function tries to read from $writesocketqueue and send the argument to write_handler(),
### then try to read from socket with a timeout of 0.2s or so and send results to read_handler()
### Issues:
### - Uptime doesn't show correctly when relogging
sub read_socket
    {
	login("firsttime");
	my($read, $write);
	my($starttime) = time();
    while()
	     {
		 local $SIG{"KILL"} = sub {
		   $remote->close();
		   print_output("NOTIFICATION", "Disconnected from server.\n"); };
		 local $SIG{"STOP"} = sub {
		   my($second) = time() - $starttime;
		   my($minute) = $second / 60;
		   $second    %= 60;
		   $starttime  = time();
		   print_output("NOTIFICATION", "Disconnected from server, trying to relogin...\n");
		   print_output("NOTIFICATION", "Uptime: $minute m $second s.\n");
		   login(); };
		 
		 if( $write = $writesocketqueue->dequeue_nb() )
		   { write_handler($write); }
		 if( $select->can_read(0.2) )
	       {
		   sysread($remote, $read, 20000);
		   if( $read )
		     {
		     $read = decode("utf8", $read) or warn "Couldn't decode: $!";
	         my(@read) = $read =~ /(<.+?>|^\+connect$|^Connection timeout\.\.$)/g;
	         read_handler(@read);
			 }
		   else {
		        if( $! ) { print "Read doesn't exist: $!\n"; }
			    login();
			    }
		   }
		 }
    }

### Prints user login data and calls user_code 25 to create a sprite, then checks if that users ihash exists
### in stalk or antistalk and if so, the id is added
### Issues:
### - Argument "" isn't numeric at 528
sub print_data
    {
	my($enteruser, $id) = @_;
    my($name, $character, $status, $trip, $ihash, $r, $g, $b, $x, $y, $scl) = $userdata->get_data($id);
	if( $name ne $userdata->get_name($id) )
	  { ($name, $character, $status, $trip, $ihash, $r, $g, $b, $x, $y, $scl) = $userdata->get_data($id); }
	$userdata->set_hex_rgb($r, $g, $b, $id);
    $scl       = $scl eq "100" ? "right" : "left";
	$trip      = $trip eq "" ? " " : " $trip ";
	$enteruser = $enteruser eq "ENTER" ? " has logged in\n" : "\n";
    
	my($room) = $logindata->get_room2();
	if( $option{room} )
	  {
	  ### Issues:
	  ### - Change space indentation to print_output()
	  print_output("ROOM", "ROOM $room");
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
    
	if( !$name ) { $name = "null"; }
	$tripqueue->enqueue($ihash, $name);
	if( $option{stalk} and $userdata->get_stalk($userdata->get_ihash($id)) )
	  { $userdata->set_stalk($id); }
    if( $option{antistalk} and $userdata->get_antistalk($userdata->get_ihash($id)) )
	  { $userdata->set_antistalk($id); }
	}

### Handles information sent from read_socket()
sub write_handler
    {
	my($write) = shift;
	if   ( $write eq "REENTER"    )  { enter_room("reenter"); }
	elsif( $write eq "SETXYSCL"   )  { send_x_y_scl($writesocketqueue->dequeue()); }
	elsif( $write =~ /(^SEARCH.*)/ ) { search($1); }
	elsif( $write eq "SHUTUP" )
	     { for my $counter (1..9) { print $remote "<RSET cmd=\"go\" param=\"$counter\" />\0"; } }
	else {
	     if( $write !~ />$/ or $write eq "MojaChat" )
		   { $write .= $writesocketqueue->dequeue(); }
		 if( $select->can_write() )
		   {
		   chomp($write);
		   print $remote "$write\0";
		   }
		 }
	}

### Handles information send from read_socket()
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
sub read_handler
    {
    my(@read) = @_;
    while( @read )
	     {
		 if( $option{debug} ) { print_output("NOTIFICATION", $read[0]); }
	     if   ( $read[0] =~ /\+connect id=\d{1,3}/ ) {}
	     elsif( $read[0] =~ /<CONNECT id="(.+?)" \/>/ )
	          {
              my($id) = $1;
	          $logindata->set_id($id);
	          print_output("LOGIN", "Logged in, id=$id\n\n");
              }
		 elsif( $read[0] =~ /<ENTER id="(.+?)" \/>/ )
	          {
			  $roomid{$1} = 1;
			  print_output("ENTER", "User with id $1 entered this room\n");
			  }
	     elsif( $read[0] =~ /<UINFO name="(.*?)" id="(\d{1,3})" \/>/ )
	          {
	          if( $logindata->get_room2() eq "main" )                           
	            { print_output("ROOM", "$1 id=$2\n"); }                                 
	          }
	     elsif( $read[0] eq "<ROOM>" ) ### Sent when you enter the room
	          {
			  $option{room} = 0;
			  my($room2) = $logindata->get_room2();
			  print_output("ROOM", "ROOM $room2");
			  }
	     elsif( $read[0] eq "<ROOM />" ) {} ### Sent when you exit the room
	     elsif( $read[0] =~ /<ROOM c="(.+?)" n="(.+?)" \/>/ ) ### There is a necessity for this one?
	          {
			  if( ($option{roominfo} or $logindata->get_room2() eq "main") and $1 != "0" )
			      { print_output("ROOM", "room $2 persons $1\n"); }
			  }
	     elsif( $read[0] eq "</ROOM>" ){} ### Sent when sending the room user list
		 elsif( $read[0] =~ /<COUNT>/ )
	          {
	          #print_output("ROOM", "Rooms:\n");
	          while( $read[0] !~ /<\/COUNT>/ )
	               {
	               if( $read[0] =~ /<ROOM c="(.+?)" n="(.+?)" \/>/ )
				     { print_output("ROOM", "room $2 persons $1\n"); }
				   shift(@read);
	               }
	          }
	     elsif( $read[0] =~ /<\/COUNT>/  ) {} ### In main
	     #elsif( $read[0] =~ /<COUNT \/>/ ) {} ### Is this necessary?
	     elsif( $read[0] =~ /<COUNT c="(.+?)" n="(.+?)"\s?\/?>/ )
	          {
			  if( $option{roominfo} ) { print_output("ROOM", "room $2 persons $1\n"); }
			  $eventdata{room}    = $2;
			  $eventdata{persons} = $1;
			  $window->Text("Monachat [room: $2 persons: $1]");
			  if( $ENABLE_GRAPHIC_INTERFACE ) { push_event(24); }
			  }
	     elsif( $read[0] =~ m/<(\w{4,5})\s r="(.*?)"\s name="(.*?)"\s(.+?)stat="(.*?)"\s g="(.*?)"\s
		                      type="(.*?)"\s b="(.*?)"\s y="(.*?)"\s x="(.*?)"\s scl="(.*?)"\s\/>/x )
	          {
			  my($enteruser, $name, $idtripihash, $character, $status, $r, $g, $b, $x, $y, $scl) =
			    ($1, $3, $4, $7, $5, $2, $6, $8, $10, $9, $11);
			  my($id)    = $idtripihash =~ /id="(\d{1,3})"/  ? $1 : "";
			  my($trip)  = $idtripihash =~ /trip="(.{10})"/  ? $1 : "";
			  my($ihash) = $idtripihash =~ /ihash="(.{10})"/ ? $1 : "";
			  $userdata->set_data($name, $id, $character, $status, $trip, $ihash, $r, $g, $b, $x, $y, $scl);
			  print_data($enteruser, $id);
			  }    
         elsif( $read[0] =~ /<SET stat="(.*?)" id="(.+?)" \/>/ )
	          {
			  my($status, $id) = ($1, $2);
			  my($name)   = $userdata->get_name($id);
			  my($trip)   = $userdata->get_trip($id);
			  my($ihash)  = $userdata->get_ihash($id);
			  my($hexrgb) = $userdata->get_hex_rgb($id);
			  $trip = $trip ne "" ? " $trip " : " ";
			  $userdata->set_status($status, $id);
			  if(!$option{mute} and !$mute{$id} )
			    { print_output("CHANGE", "USERCOLOR", $hexrgb, "$name$trip$ihash changed his status to $status\n"); }
			  if( $ENABLE_GRAPHIC_INTERFACE ) { push_event(24); }
	          }
	     elsif( $read[0] =~ /<SET x="(.*?)" scl="(.*?)" id="(\d{1,3})" y="(.*?)" \/>/ )
	          {
			  {
			  ### -100 isn't numeric
			  no warnings;
	          my($x, $scl, $id, $y) = ($1, $2, $3, $4);
			  my($loginid)          = $logindata->get_id();
              my($name)             = $userdata->get_name($id);
			  my($hexrgb)           = $userdata->get_hex_rgb($id);
	          if( $userdata->get_x($id) != $x )
	            {
	            $userdata->set_x($x, $id);
	            if( !$option{mute} and !$mute{$id} )
				  { print_output("CHANGE", "USERCOLOR", $hexrgb, "$name moved to x $x\n"); }
                }
	          if( $userdata->get_y($id) != $y )
	            {
	            $userdata->set_y($y, $id);
	            if( !$option{mute} and !$mute{$id} )
				  { print_output("CHANGE", "USERCOLOR", $hexrgb, "$name moved to y $y\n"); }
                }
	          if( $userdata->get_scl($id) != $scl )
	            {
	            $userdata->set_scl($scl, $id);
				$scl = $scl == 100 ? "right" : "left";
	            if( !$option{mute} and !$mute{$id} )
				  { print_output("CHANGE", "USERCOLOR", $hexrgb, "$name moved to $scl\n"); }
				#$eventdata{flip} = 1;
                }
			  }
			  if( $ENABLE_GRAPHIC_INTERFACE ) { push_event(27, $id); }
			  
			  if( $option{stalk} and !$option{nomove} and $userdata->get_stalk($id) )
	            {
                my($line) = "x$x"."y$y"."scl$scl";
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
			  my($name, undef, undef, undef, $ihash) = $userdata->get_data($id);
			  my($ignorename, $ignoreid) = $userdata->get_data_by_ihash($ignoreihash);
			  $userdata->set_ignore($ignoreihash, $stat, $id);
			  my($ignore) = $userdata->get_ignore($ignoreihash, $id) ? "ignored" : "stopped ignoring";
			  my($hexrgb, $ignorehexrgb) = ($userdata->get_hex_rgb($id), $userdata->get_hex_rgb($ignoreid));
	          print_output("IGNORE", "USERCOLOR", $hexrgb, $name, $ihash, $id, $ignore,
			               $ignorehexrgb, $ignorename, $ignoreihash, $ignoreid);
	          
			  if( ($option{antiignore} and $userdata->get_antiignore($id)) or $option{antiignoreall} )
			    { login("notfirsttime"); }
	          }
		 elsif( $read[0] =~ /<RSET cmd="go" param="(.+)" id="(\d{1,3})" \/>/ )
		      {
			  my($hexrgb) = $userdata->get_hex_rgb($2);
			  print_output("RSET", "USERCOLOR", $hexrgb, "SAITAMA SAITAMA ($1) ($2)\n");
			  }
		 elsif( $read[0] =~ /^<SET cmd="ev"/ )
		      {
			  ### <SET cmd="ev" id="\d{1,3}" />
			  ### <SET cmd="ev" pre="0|1" param="0|1" id="\d{1,3}" />
			  ### <SET cmd="ev" set="start|wait" param="start|wait" id="\id{1,3}" />
			  if( !$option{mute} and !$mute{$id} ) { print_output("NOTIFICATION", $read[0]) };
			  }
	     elsif( $read[0] eq "<EXIT />" )
	          {
			  print_output("EXIT", "You exited the room\n" );
			  %roomid = ();
			  }
	     elsif( $read[0] =~ /<EXIT id="(.+?)" \/>/ )
	          {
              my($id)      = $1;
			  my($loginid) = $logindata->get_id();
			  if( $id != $loginid )
			    {
				### Double comprobation with $hexrgb
			    my($name)   = $userdata->get_name($id)    || "";
				my($ihash)  = $userdata->get_ihash($id)   || "";
			    my($hexrgb) = $userdata->get_hex_rgb($id) || "#000000";
	            print_output("EXIT", "USERCOLOR", $hexrgb, "$name $ihash ($id) exited this room\n");
				}
			  else { print_output("EXIT", "\n"); }
			  delete $roomid{$id};
			  if( $ENABLE_GRAPHIC_INTERFACE ) { push_event(26, $id); }
	          }
	     elsif( $read[0] =~ /<COM cmt="(.+?)" (.+?) \/>/ ) ### There are three comment patterns
	          {
              #<COM cmt"(.+?)" id="(.+?)" cnt="(.+?)" \/>
              #<COM cmt="(.+?)" cnt="(.+?)" id="(.+?)" \/>
              #<COM cmt="(.+?)" id="(.+?)" \/>
              my($comment) = $1;
              my($id)      = $2 =~ /id="(.+)"/;
			  my($name, undef, undef, $trip, $ihash) = $userdata->get_data($id);
			  my($usercolor) = $userdata->get_hex_rgb($id);
	          $trip = $trip ? " $trip " : " ";
			  my($second, $minute, $hour) = localtime(time());
			  $second = $second =~ /^\d$/ ? "0$second" : $second;
			  $minute = $minute =~ /^\d$/ ? "0$minute" : $minute;
			  $hour   = $hour   =~ /^\d$/ ? "0$hour"   : $hour;
			  my($date) = "[$hour:$minute:$second]";
			  my($line) = "$date $name$trip$ihash ($id): $comment";
	          print_output("COMMENT", "USERCOLOR", $usercolor, $date, $name, $trip, $ihash, $id, "$comment\n");
	          
			  if ( $option{stalk} and $userdata->get_stalk($id) )
	             {
	             $comment = encode("utf8", $comment);
	             $writesocketqueue->enqueue("<COM cmt=\"$comment\" />");
	             }
			  if( $option{popup} )
			    {
				chomp($line);
				$line = substr($line, 11);
				$line = encode("cp932", $line);
			  	foreach my $trigger (@popuptrigger)
			  	        {
						chomp($trigger);
			  			if( $comment =~ /$trigger/i )
			  			  {
						  $notifyicon->Change("-balloon_tip", $line);
						  $notifyicon->ShowBalloon();
						  }
			  			}
			  	}
	          }
	     elsif( $read[0] eq "Connection timeout.." )
	          {
	          print_output("NOTIFICATION", "Connection timeout...\n");
	          login("notfirsttime");
	          }
	     elsif( $read[0] =~ /^<R|^<USER/ ) ### For fixing broken signals
	          {
	          my($line) = shift(@read) . $read[0];
	          if   ( $line !~ />$/ )
	               { $line = $line . ">"; }
	          if   ( $line =~ /<ROOM c="(.+?)" n="(.+?)" \/>/ )
	               { if( $1 != 0 ) { print_output("ROOM", "room $2 persons $1\n"); } }
	          elsif( $line =~ m/<(\w{4,5})\s r="(.*?)"\s name="(.*?)"\s(.+?)stat="(.*?)"\s g="(.*?)"\s
			                    type="(.*?)"\s b="(.*?)"\s y="(.*?)"\s x="(.*?)"\s scl="(.*?)"\s \/>/x )
	               {
				   my($enteruser, $name, $idtripihash, $character, $status, $r, $g, $b, $x, $y, $scl) =
			         ($1, $3, $4, $7, $5, $2, $6, $8, $10, $9, $11);
			       my($id)    = $idtripihash =~ /id="(\d{1,3})"/  ? $1 : "";
			       my($trip)  = $idtripihash =~ /trip="(.{10})"/  ? $1 : "";
			       my($ihash) = $idtripihash =~ /ihash="(.{10})"/ ? $1 : "";
			       $userdata->set_data($name, $id, $character, $status, $trip, $ihash, $r, $g, $b, $x, $y, $scl);
			       print_data($enteruser, $id);
				   }
	          else { print_output("UNKNOWN", "$line\n"); }
	          }
         else { print_output("UNKNOWN", "$read[0]\n"); }
	     shift(@read);
	     }
	}

### Stores command line arguments into $argument
sub get_argument
    {
    while( @ARGV )
         {
		 if( $ARGV[0] =~ /(-proxy|-debug)/ )
		   {
		   $1 eq "-proxy" ? $argument{proxy} = 1 :
		   $1 eq "-debug" ? $argument{debug} = 1 : undef;
		   }
         elsif( $ARGV[0] =~ /(-timeout|-ip|-port|-change|-skip|-name|-character|-status|-trip|-x|-y|-scl|-attrib)/ )
		      {
		      shift(@ARGV);
		      $1 eq "-timeout"   ? $argument{timeout}   = $ARGV[0] :
		      $1 eq "-ip"        ? $argument{address}   = $ARGV[0] :
		      $1 eq "-port"      ? $argument{port}      = $ARGV[0] :
			  $1 eq "-change"    ? $argument{change}    = $ARGV[0] :
		      $1 eq "-skip"      ? $argument{skip}      = $ARGV[0] :
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
			  ($argument{room1}, $argument{socketport}) =
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
			  if( $argument{room1} ) { shift(@ARGV); }
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
	  if( $id ) { $eventdata{id} = $id; }
	  $event->user_code($usercode);
	  SDL::Events::push_event($event);
	  }
	}

### Redraws the screen
### Isues:
### - Redraw the entire screen every time is horribly inefficient
sub draw_screen
    {
	my($event, $window) = @_;
	my($room, $persons) = ($eventdata{room}, $eventdata{persons});
	my($text) = SDLx::Text->new(
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
		    if( $name )   { $text->write_xy( $window, $x + $roomdata{$id}->w() / 2, $y - 20, $name   ); }
		    if( $ihash )  { $text->write_xy( $window, $x + $roomdata{$id}->w() / 2, $y, $ihash  ); }
		    if( $status ) { $text->write_xy( $window, $x + $roomdata{$id}->w() / 2, $y + 20, $status ); }
			}
	$window->update();
	}

### Handles SDL events
### Issues:
### - Mouse click area is too wide and do not match the character
### - Y not implemented yet, so for the time being let's stuck to y = 135
### - Scl not implemented either
### - Can't call method "x" on an undefined value at 906
### user_code 24: Calls draw_screen() function
### user_code 25: Creates a character sprite, for some reason it crashes a lot
### user_code 26: Deletes a user or all from the room
### user_code 27: Changes x, y, and scl of an user and redraws the screen
### user_code 30: ?
sub event_handler
    {
	my($event, $window) = @_;
	#print "event type: ", $event->type(), "\n";
	if   ( $event->type() == SDL_QUIT    ) { $window->stop(); }
	elsif( $event->type() == SDL_KEYDOWN ) { print $event->key_sym(), "\n"; }
	elsif( $event->type() == SDL_MOUSEBUTTONUP )
	     {
		 $eventdata{movecharacter} = 0;
		 my($id)   = $logindata->get_id();
		 my($line) = "x".$roomdata{$id}->x();
		 $writesocketqueue->enqueue("SETXYSCL", $line);
		 }
	elsif( $eventdata{movecharacter} or ($event->type() == SDL_MOUSEBUTTONDOWN and
	       $event->button_button() == SDL_BUTTON_LEFT) )
	     {
		 my($id) = $logindata->get_id();
		 #my($pixel) = $roomdata{$id}->surface->get_pixel($event->button_x() + $event->button_y() * $window->w());
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
		 my($id)        = $eventdata{id};
		 my($character) = "character//" . $userdata->get_character($id) . ".png";
		 my($x, $y)     = $userdata->get_x_y_scl($id);
		 while( !$roomdata{$id} )
		      {
			  $roomdata{$id} = SDLx::Sprite->new(
		        width  => 128,
			    height => 128 );
			  }
		 if   ( -e $character )   { $roomdata{$id}->load($character) or warn "Couldn't load $character\n"; }
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
		 my($id) = $eventdata{id};
		 my($x, $y) = $userdata->get_x_y_scl($id);
		 $roomdata{$id}->x($x);
		 $roomdata{$id}->y(135);
		 #$roomdata{$id}->y($y - 140);
		 #if( $eventdata{flip} == 1 ) { $roomdata{$id}->flip(); $eventdata{flip} = 0;}
		 draw_screen($event, $window);
		 }
	#elsif( $event->user_code() == 30 )
	#     {
	#	 my($x) = $window->x();
	#	 my($y) = $window->y();
	#	 print "x: $x, y: $y\n";
	#	 }
	}

### Creates a SDL window, this function is only called to create a thread
### %roomdata: Local variable used to store sprites in the current room
sub sdl_window
    {
	my(%roomdata);
	my($window) = SDLx::App->new(
	  width  => 620,
	  height => 320,
	  name   => "Monachat" );
	$window->update();
	$window->add_event_handler(\&event_handler);
	$window->run();
	}

share(%argument);          ### Command line arguments
share(%option);            ### Options of things too small to own their own variables
share(%socketdata);        ### The default ip and port address
share(%proxy);             ### Proxy options
share(%roomid);
share(%eventdata);         ### Shared global variable for the SDL event loop
share(%mute);
share(@proxyaddr);         ### List of ip addresses retrieved by get_proxy_list()
share(@proxyport);         ### List of ip ports retrieved by get_proxy_list()
share(@inputline);
share(@popuptrigger);      ### List of strings that trigger an allarm
share($inputcounter);

get_argument();

### Get config file, profiles not currently implemented,
### maybe encode/decode messes with japanese windows
open(CONFIG, "<:encoding(cp932)", "config.txt") or die "Couldn't open config file: $!\n";
for my $line (<CONFIG>)
     {
	 chomp($line);
	 if( $line =~ /^(.+) = (.+)$/ )
	   {
	   my($option, $parameter) = ($1, $2);
	   $parameter = (!$parameter or $parameter eq "\"\"") ? undef : $parameter;
	   if( $option eq "trigger" ) { @popuptrigger = split(/ : /, $parameter); }
	   else { $config{$option} = $parameter; }
	   }
	 }
close(CONFIG);

### Creates the main Win32::GUI window
### Issues:
### - $outputfield->GetAutoURLDetect not working
### - ^Now works, but can't click on $outputfield (14/11)
### - Scroll in $outputfield not working initially, starts working once it's scrolled manually once
$window = Win32::GUI::Window->new(
  -name   => "Window",
  -title  => "Monachat",
  -height => 320,
  -width  => 620 );
if( $config{popup} )
  {
  $taskbaricon = Win32::GUI::Icon->new("GUIPERL.ICO");
  $notifyicon = $window->AddNotifyIcon(
    -icon            => $taskbaricon,
    -name            => "NotifyIcon",
    -tip             => "Monachat",
    -balloon         => 1,
    -balloon_timeout => 4 );
  }
$inputfield = $window->AddTextfield(
  -name        => "Inputfield",
  -height      => 30,
  -width       => 598,
  -left        => 2,
  -top         => 240,
  -multiline   => 0,
  -autohscroll => 1 );
$outputfield = $window->AddRichEdit(
  -height      => 220,
  -width       => 598,
  -left        => 2,
  -top         => 10,
  -multiline   => 1,
  -readonly    => 1,
  -vscroll     => 1,
  -autovscroll => 1 );
$inputfield->SetLimitText(50);
$outputfield->SetCharFormat( -name => "MS Shell Dlg" );
$outputfield->SetTextMode(1, 1);
$outputfield->AutoURLDetect();
$outputfield->SetBkgndColor($config{backgroundcolor});
$inputfield->SetFocus();
$window->Center();
$window->Show();

#$image = Imager->new();
#$image->read( file => "test.png" );
#$image->flip(dir=>"h");
#$image->write( file => $image );
#$scaledimage = $image->scaleX(pixels => 180)->scaleY(pixels => 180);
#$scaledimage->flood_fill(x => 90, y => 90, color => [255, 255, 0, 0]);
#$scaledimage->write( file => "test1.png" );
#$pixel = $scaledimage->getpixel( x => 90, y => 90 );
#die "pixel: $pixel\n";

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
  $argument{attrib}    || $config{attrib} )
  or die "Couldn't create logindata.\n";
### $userdata stores all user data, including own
$userdata =  Userdata->new_user_data() or die "Couldn't create userdata.\n";
%socketdata = (
  address => $argument{address} || $config{address} || "153.122.46.192",
  port    => $argument{port}    || $config{port}    || 9095 );
%proxy = (
  on      => $argument{proxy}      || $config{proxy}   || 0,
  timeout => $argument{timeout}    || $config{timeout} || 1,
  debug   => $argument{debug}      || $config{debug}   || 0,
  change  => $argument{change}     || $config{change}  || 0,
  skip    => $argument{skip}       || 0,
  version => $config{socksversion} || 4 );
%option = (
  mute     => $config{mute}     || 0,
  popup    => $config{popup}    || 0,
  roominfo => $config{roominfo} || 0,
  debug    => 0 );

### $pingsemaphore:    Used to restart the ping thread
### $eventsemaphore:   Used to prevent %eventdata being accessed before SDL event handler uses them
### $writesocketqueue: Queues all the socket write requests
### $tripqueue:        Queues all the trip store requests
$pingsemaphore    = Thread::Semaphore->new();
$eventsemaphore   = Thread::Semaphore->new();
$writesocketqueue = Thread::Queue->new();
$tripqueue        = Thread::Queue->new();
 
if( $ENABLE_GRAPHIC_INTERFACE == 1 )
  {
  $event = SDL::Event->new();
  $sdlwindowthread = threads->create(\&sdl_window);
  }

$pingthread        = threads->create(\&ping);
$tripstorethread   = threads->create(\&trip_store);
$readsocketthread  = threads->create(\&read_socket);

### Hooks WM_MOVE to Window_Move()
$window->Hook(3, \&Window_Move);
Win32::GUI->Dialog();
