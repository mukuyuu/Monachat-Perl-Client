use warnings;
use diagnostics;
use IO::Socket;
use Socket;
use threads;
use threads::shared qw(share);
use Thread::Semaphore;
use Encode qw(encode decode);
use Win32::GUI;
use Win32::GUI::Constants;
use IO::Select;
use IO::Socket::Socks;
use LWP::UserAgent;
use Userdata;

open(LOG, ">", "log.txt") or die "Couldnt write warning.txt: $!";
$SIG{__WARN__} = sub { print LOG "Warning: @_"; print @_; };
$SIG{__DIE__}  = sub { print LOG "Error: @_"; print @_; };

sub Window_Terminate { return -1; }
#sub SearchWindow_Terminate
#    {
#    $searchwindow->Hide();
#    $searchoutputfield->SelectAll();
#    $searchoutputfield->ReplaceSel( "" );
#    }

sub Inputfield_KeyDown
    {
    shift;
    my($key) = shift;
    if( $key == 13 )
      {
      my($readtext) = $inputfield->Text();
	  if( $readtext )
	    {
		$readtext = decode("cp932", $readtext) or die "Couldn't encode: $!\n";
        if ( $readtext =~ /^\// )
	       { command_list($readtext); }
        else
	       {
	       $readtext = encode("utf8",  $readtext) or die "Couldn't encode: $!\n";
	       if( $select->can_write() )
	         { print $remote "<COM cmt=\"$readtext\" />\0"; }
	       }
        $inputfield->SelectAll();
        $inputfield->ReplaceSel("");
		}
      }
   }

sub command_list
    {
    my($command) = shift;
	my($loginid) = $logindata->get_id();
    if   ( $command =~ /\/login/ )
	     { login(); }
    elsif( $command =~ /\/relogin\s*(.*)/ )
	     {
		 if( $1 =~ /skip (\d+)/ ) { $proxy{skip} = $1;}
	     login("relogin");
	     }
	elsif( $command =~ /\/reenter/ )
	     { enter_room("reenter"); }
    elsif( $command =~ /\/disconnect\s*(\d*)/ )
	     {
	     if ( $select->can_write() )
	        { print $remote "<EXIT />\0", "<NOP />\0", "<NOP />\0"; }
		 $pingthread->kill("KILL");
		 $readsocketthread->kill("KILL");
		 print_output("Disconnected from server.\n");
	     }
    elsif( $command =~ /\/name (.+)/ )
	     {
		 my($name) = $1;
	     $userdata->set_name($name, $loginid);
	     enter_room("reenter");
	     }
    elsif( $command =~ /\/character (.+)/ )
	     {
	     my($character) = $1;
	     $userdata->set_character($character, $loginid);
	     enter_room("reenter");
	     }
    elsif( $command =~ /\/stat (.+)/ )
	     { print $remote "<SET stat=\"$1\" />\0"; }
    elsif( $command =~ /\/room (.+)/ )
	     {
	     my($room) = $1;
	     $logindata->set_room2($room);
	     enter_room("reenter");
	     }
    elsif( $command =~ /\/rgb (\d{1,3}) (\d{1,3}) (\d{1,3})/ )
	     {
	     my($r, $g, $b) = ($1, $2, $3);
	     $userdata->set_r($r, $loginid);
         $userdata->set_g($g, $loginid);
         $userdata->set_b($b, $loginid);
	     enter_room("reenter");
	     }
    elsif( $command =~ /\/x (.+)/ )
	     { send_x_y_scl("x$1"); }
    elsif( $command =~ /\/y (.+)/ )
	     { send_x_y_scl("y$1"); }
    elsif( $command =~ /\/move (.+)/ )
	     {
         my($line);
	     if( $1 =~ /(x.+)/ ) { $line .= $1; }
	     if( $1 =~ /(y.+)/ ) { $line .= $1; }
         send_x_y_scl($line);
	     }
    elsif( $command =~ /\/scl/ )
	     {
         my($scl) = $userdata->get_scl($loginid);
		 $scl = $scl == 100 ? "-100" : 100;
         send_x_y_scl("scl$scl");
	     }
    elsif( $command =~ /\/attrib/ )
	     {
	     $userdata->set_attrib($loginid);
	     enter_room("reenter");
	     }
    elsif( $command =~ /\/ignore (\d{1,3})/ )
	     {
		 my($id) = $1;
	     my($ihash) = $userdata->get_ihash($id);
	     if( $select->can_write() )
	       { print $remote "<IG ihash=\"$ihash\" />\0"; }
	     }
    elsif( $command =~ /\/search (.+)/ )
	     {
		 if   ( $1 =~ /print/ )     { $option{searchprint} = 1; }
		 if   ( $1 =~ /main/ )      { $option{searchmain}  = 1; }
	     elsif( $1 =~ /user (.+)/ ) { $option{searchuser}  = $1; }
	     elsif( $1 =~ /all/ )       { $option{searchall}   = 1; }
		 search();
	     }
    elsif( $command =~ /\/stalk (.+)/ )
	     {
		 my($search) = $1;
	     if   ( $search =~ /(on|off)/  )
		      {
			  $option{stalk} = $1 =~ /on/ ? 1 : 0;
			  print_output("Stalk $1.\n");
			  }
	     elsif( $search =~ /(\d{1,3})/ )
	          {
			  $option{stalk} = 1;
			  my($id) = $1;
	          $userdata->set_stalk($id);
	          if   ( $1 =~ /nomove/ )
	               { $option{nomove} = $option{nomove} ? 0 : 1; }
	          else {
	               $option{nomove} = 0;
	               $userdata->set_x($userdata->get_x($id));
	               $userdata->set_y($userdata->get_y($id));
	               $userdata->set_scl($userdata->get_scl($id));
                   send_x_y_scl();
	               }
	         }
	     }
    elsif( $command =~ /\/antistalk (.+)/ )
	     {
		 my($search) = $1;
		 if   ( $search =~ /(on|off)/  )
		      {
			  $option{antistalk} = $1 =~ /on/ ? 1 : 0;
			  print_output("Antistalk $1.");
			  }
	     elsif( $search =~ /(\d{1,3})/ )
	          {
		      $option{antistalk} = 1;
		      my($id) = $1;
		      $userdata->set_antistalk($id);
	          }
	     }
    elsif( $command =~ /\/copy (.+)/ )
	     {
         my($id) = $1;
	     $userdata->set_name($userdata->get_name($id), $loginid);
	     $userdata->set_status($userdata->get_status($id), $loginid);
	     $userdata->set_character($userdata->get_character($id), $loginid);
	     $userdata->set_r($userdata->get_r($id), $loginid);
	     $userdata->set_g($userdata->get_g($id), $loginid);
	     $userdata->set_b($userdata->get_b($id), $loginid);
	     $userdata->set_x($userdata->get_x($id), $loginid);
	     $userdata->set_y($userdata->get_y($id), $loginid);
	     $userdata->set_scl($userdata->get_scl($id), $loginid);
	     my($name)      = $userdata->get_name($loginid);
		 my($status)    = $userdata->get_status($loginid);
		 my($character) = $userdata->get_character($loginid);
		 enter_room("reenter");
	     }
    elsif( $command =~ /\/default/ )
	     {
	     $userdata->set_name($logindata->get_name(), $loginid);
	     $userdata->set_status($logindata->get_status(), $loginid);
		 $userdata->set_character($logindata->get_character(), $loginid);
		 $userdata->set_trip($logindata->get_trip()||"", $loginid);
		 $userdata->set_r($logindata->get_r(), $loginid);
		 $userdata->set_g($logindata->get_g(), $loginid);
		 $userdata->set_b($logindata->get_b(), $loginid);
		 $userdata->set_x($logindata->get_x(), $loginid);
		 $userdata->set_y($logindata->get_y(), $loginid);
		 $userdata->set_scl($logindata->get_scl(), $loginid);
		 $option{stalk}  = 0;
		 $option{nomove} = 0;
		 enter_room("reenter");
		 }
	elsif( $command =~ /\/invisible/ )
		 {
		 $userdata->set_name(undef, $loginid);
		 $userdata->set_status(undef, $loginid);
		 $userdata->set_character(undef, $loginid);
		 $userdata->set_trip(undef, $loginid);
		 $userdata->set_r(undef, $loginid);
		 $userdata->set_g(undef, $loginid);
		 $userdata->set_b(undef, $loginid);
		 $userdata->set_x(undef, $loginid);
		 $userdata->set_y(undef, $loginid);
         $userdata->set_scl(undef, $loginid);
		 enter_room("reenter");
		 }
    elsif( $command =~ /\/proxy\s*(.*)/ )
		 {
	     if   ( $1 =~ /(on|off)/ )
	          {
			  $proxy{on} = $1 =~ /on/ ? 1 : 0;
			  print_output("Proxy $1\n");
			  }
	     elsif( $1 =~ /timeout (\d\.*\d*)/ )
	          { $proxy{timeout} = $1; }
		 login("relogin");
	     }
    elsif( $command =~ /\/clear (.+)/ )
		 {
		 if   ( $1 =~ /screen/ )
	          {
	          $outputfield->SelectAll();
			  $outputfield->ReplaceSel("");
	          }
		 elsif( $1 =~ /userdata/ )
	          {
              undef $userdata;
              $userdata = Userdata->new_user_data();
	          }
		 }
    elsif( $command =~ /\/newinstance\s*(.*)/ )
		 {
		 if ( $1 =~ /here\s*(.*)\s*(.*)/ )
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
    elsif( $command =~ /\/antiignore\s*(\d*)/ )
	     {
		 if   ( $1 =~ /(on|off)/ )
		      {
			  $option{antiignoreon} = $1 =~ /on/ ? 1 : 0;
			  print_output("Antiignore $1");
			  }
		 elsif( $1 =~ /(\d{1,3})/ )
		      {
		      my($id) = $1;
		      $userdata->set_antiignore($id);
	          $option{antiignoreon} = 1;
			  my($on) = $userdata->get_antiignore($id) ? 0 : 1;
			  $userdata->set_antiignore($on, $id);
	          }
	     elsif( $1 =~ /all/ )
	          { $option{antiignoreall} = $option{antiignoreall} ? 0 : 1; }
	     }
    }


sub print_output
    {
    my($text) = shift;
    $text = encode("cp932", $text);
	$outputfield->Select("-1", "-1");
	$outputfield->ReplaceSel("$text");
    }

sub login
    {
    my($option) = shift;
    if ( $option eq "relogin" )
       {
	   $pingthread->kill("KILL");
	   $readsocketthread->kill("KILL");
       }
   if  ( $proxy{on} == 1 )
       {
       while()
            {
            if( !@proxyaddr ) { get_proxy_list(); }
            $remote = IO::Socket::Socks->new( ProxyAddr   => $proxyaddr[0],
	                                          ProxyPort   => $proxyport[0],
	                                          ConnectAddr => $socketdata{address}||"153.122.46.192",
	                                          ConnectPort => $socketdata{port}||"9095",
	                                          SocksDebug  => $proxy{debug}||1,
	                                          Timeout     => $proxy{timeout}||2 )
            or warn "$SOCKS_ERROR\n" and shift(@proxyaddr) and shift(@proxyport) and redo;
            if( $proxy{skip} > 0 ) { shift(@proxyaddr); shift(@proxyport); $proxy{skip}--; redo; }
			last;
            }
       }
    else
       {
       $remote = IO::Socket::INET->new( PeerAddr => $socketdata{address}||"153.122.46.192",
	                                    PeerPort => $socketdata{port}||"9095",
	                                    Proto => "tcp" )
	                                    or die "Couldn't connect: $!";
       }
    $select = IO::Select->new( $remote );
    if( $select->can_write() )
	  { print $remote "MojaChat\0"; }
	if  ( $option eq "firsttime" )
	    { enter_room("firsttime"); }
	else{ enter_room(); }
    if( $option eq "relogin" )
	  {
	  $readsocketthread = threads->create(\&read_socket);
	  $pingthread       = threads->create(\&ping);
	  }
    }

sub enter_room
    {
    my($option) = shift;
	my($id) = $logindata->get_id();
	my($room) = $logindata->get_room();
	my($room2) = $logindata->get_room2() eq "main" ? undef : "/" . $logindata->get_room2();
	my($name, $status, $character, $trip, $ihash, $r, $g, $b, $x, $y, $scl, $attrib) =
	$option eq "firsttime" ? $logindata->get_data() : $userdata->get_data($id);
	if   ( $option eq "reenter" and $select->can_write() )
	     { print $remote "<EXIT no=\"$id\" \/>\0" }
	if   ( $logindata->get_room2() eq "main" and $select->can_write() )
	     { print $remote "<ENTER room=\"$room\" name=\"$name\" attrib=\"$attrib\" />\0"; }
    elsif( $select->can_write() )
	     { print $remote "<ENTER room=\"$room$room2\" umax=\"0\" type=\"$character\" name=\"$name\" x=\"$x\" ",
	                     "y=\"$y\" r=\"$r\" g=\"$g\" b=\"$b\" scl=\"$scl\" status=\"$status\" />\0"; }
    }

sub send_x_y_scl
    {
	my($line) = shift;
	my($id) = $logindata->get_id();
	my($x) = $line =~ /x(\d+)/ ? $1 : $userdata->get_x($id);
	my($y) = $line =~ /y(\d+)/ ? $1 : $userdata->get_y($id);
	my($scl) = $line =~ /scl(-?\d+)/ ? $1 : $userdata->get_scl($id);
    if( $select->can_write() )
      { print $remote "<SET x=\"$x\" scl=\"$scl\" y=\"$y\" />\0"; }
    }

sub search
    {
	my(%roomdata);
	my($read, $counter);
	my($currentroom) = $logindata->get_room2();
	$logindata->set_room2("main");
	$semaphore->down();
	enter_room("reenter");
	if( $select->can_read() )
      {
	  sleep(4);
      sysread($remote, $read, 20000);
	  $read = decode("utf8", $read);
      while( $read =~ /<ROOM c="(.+?)" n="(.+?)" \/>/g )
           {
           my($room, $number) = ($2, $1);
           if( $number != 0 )
             { $roomdata{$room} = $number; }
           }
      }
	print "$read\n";
	print %roomdata, "\n", keys %roomdata, "\n";

    if( $option{searchall} )
      {
      foreach my $key ( sort( keys %roomdata ) )
              {
              $logindata->set_room2($key);
              if( $select->can_read() )
                { enter_room("reenter"); }
              sleep(1);
              sysread($remote, $read, 20000);
              $read = decode("utf8", $read);
              print_output("\n$read\n");
              while( $read =~ m/<(\w{4,5})\s r="(\d{1,3})"\s name="(.*?)"\s id="(\d{1,3})"(.+?)ihash="(.{10})"\s
			                    \w{4,6}="(.*?)"\s g="(\d{1,3})"\s type="(.*?)"\s b="(\d{1,3})"\s y="(.*?)"\s
								x="(.*?)"\s scl="(.+?)"\s \/>/xg )
                   {
                   my($name, $trip, $ihash) = ($3, $5, $6);
                   save_and_print_user_data($1, $4, $3, $4, $7, $9, $5, $6, $2, $8, $10, $11, $12, $13);
                   $trip = $trip =~ /trip="(.+?)"/ ? " $1 " : " ";
				   $roomdata{$key} = !$roomdata{$key} ? "$name$trip$ihash" : ", $name$trip$ihash";
	               }
	          }
	  }
    $logindata->set_room2($currentroom);
    enter_room("reenter");
    
	my($roomswithusers) = scalar keys %roomdata;
    if  ( $option{searchprint} )
        { print $remote "<COM cmt=\"There are $roomswithusers rooms with people:\" />\0"; }
    else{ print_output("There are $roomswithusers rooms with people:\n"); }
    foreach my $key ( sort( keys %roomdata ) )
            {
            if ( $option{searchprint} )
               {
               #$key = encode("utf8", $key);
               #$roomdata{$key} = encode("utf8", $roomdata{$key});
               print $remote "<COM cmt=\"room $key: $roomdata{$key}\" />\0";
               if( ++$counter < $roomswithusers ) { sleep(1); }
               }
            else
               {
               print_output("room $key: $roomdata{$key}");
               if   ( ++$counter < $roomswithusers )
                    { print_output(", "); }
               else { print_output("\n"); }
               }
            }
	$semaphore->up();
    $option{searchall}   = 0;
    $option{searchprint} = 0;
	}

sub get_proxy_list
    {
	my($useragent) = LWP::UserAgent->new();
	$useragent->agent("getproxylist");
	$useragent->show_progress(1);
    my($proxylist) = $useragent->get("http://www.socks-proxy.net");
	$proxylist = $proxylist->content();
    my($counter) = 0;
    while( $proxylist =~ m/<td>(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})<\/td><td>(\d{4,5})<\/td>
	                       <td>(US|GB|CA|AU|JP)<\/td><td>(.+?)<\/td>/xg )
         {
	     $proxyaddr[$counter] = $1;
	     $proxyport[$counter] = $2;
	     $counter++;
	     }
    }

sub ping
    {
    while()
	     {
		 local $SIG{"KILL"} = sub{ die; };
	     for( my($counter) = 0; $counter <= 100; $counter++ )
	        {
	        select(undef, undef, undef, 0.2);
	        if( $counter == 100 and $select->can_write() )
	          { print $remote "<NOP />\0"; }
	        }
	     }
    }

sub read_socket
    {
	my($read, $second, $minute);
	my($starttime) = time();
    while()
	     {
		 local $SIG{"KILL"} = sub{
								 $minute = $second > 60 ? substr($second / 60, 0, 1) : 0;
								 $second = $second > 60 ? $second % 60 : $second;
								 die "Stayed up for $minute m $second s.\n";
								 };
		 $semaphore->down();
	     if( $select->can_read(0.2) )
	       {
	       sysread($remote, $read, 20000);
	       $read = decode("utf8",  $read) or warn "Couldn't decode: $!" and select(undef, undef, undef, 0.5);
	       my(@read) = $read =~ /(<.+?>)|^\+connect$|^Connection timeout\.\.$/g;
	       print_read(@read);
	       }
	     else {
		      if( time() != $starttime )
			    { $second += time() - $starttime; $starttime = time(); print "$second\n"; }
			  }
	     $semaphore->up();
		 }
    }

sub save_and_print_user_data
    {  
    my($enteruser, $id, $name, $character, $status, $trip, $ihash, $r, $g, $b, $x, $y, $scl) = @_;
    $userdata->set_name($name, $id);
    $userdata->set_id($id);
    $userdata->set_character($character, $id);
    $userdata->set_status($status, $id);
    $trip = $trip =~ /(.{10})/ ? $1 : undef;
	$userdata->set_trip($trip, $id);
    $userdata->set_ihash($ihash, $id);
    $userdata->set_r($r, $id);
    $userdata->set_g($g, $id);
    $userdata->set_b($b, $id);
    $userdata->set_x($x, $id);
    $userdata->set_y($y, $id);
    $userdata->set_scl($scl, $id);
    if ( $option{stalk} and $userdata->get_stalk($userdata->get_ihash($id)) )
	   { $userdata->set_stalk($id); }
    if ( $option{antistalk} and $userdata->get_antistalk($userdata->get_ihash($id)) )
	   { $userdata->set_antistalk($id); }
    $scl = $scl == 100 ? "right" : "left";
	$trip = $trip ? " $trip " : " ";
	$enteruser = ($enteruser =~ /(ENTER|USER)/ and $1 =~ /ENTER/) ? " has logged in\n" : "\n";
    print_output("$name $ihash$trip($id) $status $character x$x $scl$enteruser");
	}

sub print_read
    {
    my(@read) = @_;
    while( @read )
	     {
	     if   ( $read[0] =~ /\+connect id=(\d{1,3})/ )
	          {}
	     elsif( $read[0] =~ /<CONNECT id="(.+?)" \/>/ )
	          {
              my($id) = $1;
	          $logindata->set_id($id);
	          print_output("Logged in, id=$id\n\n");
              }
	     elsif( $read[0] =~ /<ROOM>/ )
	          {} # { print_output( "Users in this room:\n" ); }
	     elsif( $read[0] =~ /<ROOM \/>/ )
	          {}
	     elsif( $read[0] =~ m/<(\w{4,5})\s r="(\d{1,3}?)"\s name="(.*?)"\s id="(\d{1,3})"(.+?)ihash="(.{10})".+
		                      \w{4,6}="(.*?)"\s g="(\d{1,3}?)"\s type="(.*?)"\s b="(\d{1,3}?)"\s y="(.*?)"\s
							  x="(.*?)"\s scl="(.+?)"\s\/>/x )
	          { save_and_print_user_data($1, $4, $3, $9, $7, $5, $6, $2, $8, $10, $12, $11, $13); }
	     elsif( $read[0] =~ /<USER ihash="(.+?)" name="(.*?)" id="(.+?)" \/>/ )
	          { print_output("User $2 $1 ($3) has logged in\n"); }
	     elsif( $read[0] =~ /<ENTER id="(.+?)" \/>/ )
	          { print_output("User with id $1 entered this room\n"); }
	     elsif( $read[0] =~ /<UINFO name="(.*?)" id="(\d{1,3})" \/>/ )
	          {
	          if( $logindata->get_room2() eq "main" )
	            { print_output("$1 id=$2\n"); }
	          }
         elsif( $read[0] =~ /<SET stat="(.*?)" id="(.+?)" \/>/ )
	          {
			  my($status, $id) = ($1, $2);
			  my($name) = $userdata->get_name($id);
			  $userdata->set_status($status, $id);
			  print_output("$name changed his status to $status\n");
	          }
	     elsif( $read[0] =~ /<SET x="(.*?)" scl="(.+?)" id="(.+?)" y="(.*?)" \/>/ )
	          {
	          my($x, $scl, $id, $y) = ($1, $2, $3, $4);
              my($name) = $userdata->get_name($id);
			  my($loginid) = $logindata->get_id();
	          if( $userdata->get_x($id) != $x )
	            {
	            $userdata->set_x($x, $id);
	            print_output("$name moved to x $x\n");
                }
	          if( $userdata->get_y($id) != $y )
	            {
	            $userdata->set_y($y, $id);
	            print_output("$name moved to y $y\n");
                }
	          if( $userdata->get_scl($id) != $scl )
	            {
	            $userdata->set_scl($scl, $id);
				$scl = $scl == 100 ? "right" : "left";
	            print_output("$name moved to $scl\n");
                }
	          if( $option{stalk} and !$option{nomove} and $userdata->get_stalk($id) )
	            {
	            $userdata->set_x($x, $loginid);
	            $userdata->set_y($y, $loginid);
	            $userdata->set_scl($scl, $loginid);
                send_x_y_scl();
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
	     elsif( $read[0] =~ /<(IG ihash=".{10}".+id="\d{1,3}") \/>/ )
	          {
			  my($search) = $1;
			  my($ignoredihash) = $search =~ /ihash="(.{10})"/;
			  my($id)           = $search =~ /id="(\d{1,3})"/;
			  my($stat)         = $search =~ /stat="(on|off)"/;
			  $userdata->set_ignore($ignoredihash, $id, $stat);
			  my($ignore) = $userdata->get_ignore($ignoredihash, $id) ? "ignored" : "stopped ignoring";
			  my($name)   = $userdata->get_name($id);
			  my($ihash)  = $userdata->get_ihash($id);
			  my($ignoredname, $ignoredid) = $userdata->get_data_by_ihash($ignoredihash);
	          print_output("$name $ihash ($id) $ignore $ignoredname $ignoredihash ($ignoredid)\n");
	          if   ( $option{antiignore} and ($option{antiignoreall} or $userdata->get_antiignore($id)) )
			       { login("relogin"); }
	          }
	     elsif( $read[0] =~ /<EXIT \/>/ )
	          { print_output("You exited the room\n" ); }
	     elsif( $read[0] =~ /<EXIT id="(.+?)" \/>/ )
	          {
              my($id)    = $1;
              my($name)  = $userdata->get_name($id);
              my($ihash) = $userdata->get_ihash($id);
	          print_output("$name $ihash ($id) exited this room\n");
	          }
	     elsif( $read[0] =~ /<COUNT>/ )
	          {
	          #print_output("Rooms:\n");
	          while( !( $read[0] =~ /<\/COUNT>/ ) )
	               {
	               shift(@read);
	               if( $read[0] =~ /<ROOM c="(.+?)" n="(.+?)" \/>/ )
	                 { print_output("room $2 persons $1\n"); }
	               }
	          }
	     elsif( $read[0] =~ /<ROOM c="(.+?)" n="(.+?)" \/>/ )
	          {
	          if( $1 != "0" )
	            { print_output("room $2 persons $1\n"); }
	          }
	     elsif( $read[0] =~ /<\/ROOM>/ )
	          {}
	     elsif( $read[0] =~ /<\/COUNT>/ )
	          {}
	     elsif( $read[0] =~ /<COUNT \/>/ )
	          {}
	     elsif( $read[0] =~ /<COUNT c="(.+?)" n="(.+?)"\s?\/?>/ )
	          { print_output("room $2 persons $1\n"); }
	     elsif( $read[0] =~ /<COM cmt="(.+?)" (.+?) \/>/ )
	          {
              #<COM cmt"(.+?)" id="(.+?)" cnt="(.+?)" \/>
              #<COM cmt="(.+?)" cnt="(.+?)" id="(.+?)" \/>
              #<COM cmt="(.+?)" id="(.+?)" \/>
              my($comment) = $1;
              my($id)    = $2 =~ /id="(.+)"/;
              my($name)  = $userdata->get_name($id);
              my($trip)  = $userdata->get_trip($id);
              my($ihash) = $userdata->get_ihash($id);
	          $trip = $trip ? " $trip " : " ";
	          print_output("$name $ihash$trip($id): $comment\n");
	          
			  if ( $option{stalk} and $userdata->get_stalk($id) )
	             {
	             $comment = encode("cp932", $comment);
	             if( $select->can_write() )
	               { print $remote "<COM cmt=\"$comment\" />\0"; }
	             }
	          }
	     elsif( $read[0] =~ /Connection timeout\.\./ )
	          {
	          print_output("Connection timeout..\n");
	          login();
	          }
	     elsif( $read[0] =~ /^<R|^<USER/ )
	          {
	          my($line) = shift(@read) . $read[0];
	          if   ( $line !~ />$/ )
	               { $line = $line . ">"; }
	          if   ( $line =~ /<ROOM c="(.+?)" n="(.+?)" \/>/ )
	               {
	               if( $1 != 0 )
	                 { print_output("room $2 persons $1\n"); }
	               }
	          elsif( $line =~ m/<(\w{4,5})\s r="(\d{1,3})"\s name="(.*?)"\s id="(\d{1,3})"(.+?)ihash="(.{10})"\s
			                   \w{4,6}="(.*?)"\s g="(\d{1,3})"\s type="(.*?)"\s b="(\d{1,3})"\s y="(.*?)"\s
							   x="(.*?)"\s scl="(.+?)"\s \/>/x )
	               { save_and_print_user_data($1, $4, $3, $9, $7, $5, $6, $2, $8, $10, $12, $11, $13); }
	          else { print_output("$line\n"); }
	          }
         else { print_output("$read[0]\n"); }
	     shift(@read);
	     }
	}

$window      = Win32::GUI::Window->new( -name => "Window", -title => "Monachat", -height => 320, -width => 620 );
#$tab        = $window->AddTabStrip( -name => "Tab", -height => 320, -width => 620, -left => 0, -top => 0 );
#$tab1       = $tab->InsertItem( -text => 1 );
$inputfield  = $window->AddTextfield  ( -name => "Inputfield", -height => 30, -width => 598, -left => 2,
                                        -top => 240, -multiline => 0, -autohscroll => 1 );
$outputfield = $window->AddRichEdit   ( -height => 220, -width => 598, -left => 2, -top => 10, -multiline => 1,
                                        -readonly => 1, -vscroll => 1, -autovscroll => 1 );
$inputfield->SetLimitText(50);
$outputfield->SetCharFormat( -name => "MS Shell Dlg" );
$outputfield->GetAutoURLDetect();
$inputfield->SetFocus();
#$tab  = $window->AddTabStrip( -name => "Tab", -height => 320, -width => 620, -left => 0, -top => 0 );
#$tab1 = $tab->InsertItem( -text => 1 );
#$tab2 = $tab->InsertItem( -text => 2 );
#$tab3 = $tab->InsertItem( -text => 3 );
#$searchwindow      = Win32::GUI::Window->new    ( -name => "SearchWindow", -title => "Search Results",
#                                                  -height => 220, -width => 270 );
#$searchoutputfield = $searchwindow->AddTextfield( -height => 120, -width => 220, -left => 20, -top => 20,
#                                                  -multiline => 1, -vscroll => 1 );
#$searchprint       = $searchwindow->AddButton   ( -name => "SearchPrintButton", -text => "Print", -height => 30,
#                                                  -width => 60, -left => 50, -top => 150 );
#$searchupdate      = $searchwindow->AddButton   ( -name => "SearchUpdateButton", -text => "Update", -height => 30,
#                                                  -width => 60, -left => 150, -top => 150 );
$window->Center();
$window->Show();

sub get_argument
    {
    while( @ARGV )
         {
         if   ( $ARGV[0] eq ("-proxy" or "-p") )
              { $argument{proxyon} = 1; }
         elsif( $ARGV[0] eq ("-timeout" or "-t") )
              { shift(@ARGV); $argument{proxytimeout} = $ARGV[0]; }
         elsif( $ARGV[0] eq "-debug" )
	          { $argument{proxydebug} = 1; }
		 elsif( $ARGV[0] eq "-skip" )
		      { shift(@ARGV); $argument{proxyskip} = $ARGV[0] =~ /(\d+)/ ? $1 : 1; }
         elsif( $ARGV[0] eq "-ip" )
	          { shift(@ARGV); $argument{socketaddress} = $ARGV[0]; }
         elsif( $ARGV[0] eq "-port" )
	          { shift(@ARGV); $argument{socketport} = $ARGV[0]; }
         elsif( $ARGV[0] eq "-name" )
	          { shift(@ARGV); $argument{name} = $ARGV[0]; }
         elsif( $ARGV[0] eq "-character" )
	          { shift(@ARGV); $argument{character} = $ARGV[0]; }
         elsif( $ARGV[0] eq "-status" )
	          { shift(@ARGV); $argument{status} = $ARGV[0]; }
         elsif( $ARGV[0] eq "-rgb" )
	          {
	          shift(@ARGV); $argument{r} = $ARGV[0];
	          shift(@ARGV); $argument{g} = $ARGV[0];
	          shift(@ARGV); $argument{b} = $ARGV[0];
	          }
         elsif( $ARGV[0] eq "-x" )
	          { shift(@ARGV); $argument{xposition} = $ARGV[0]; }
         elsif( $ARGV[0] eq "-y" )
	          { shift(@ARGV); $argument{yposition} = $ARGV[0]; }
         elsif( $ARGV[0] eq "-scl" )
	          { shift(@ARGV); $argument{scl} = $ARGV[0]; }
         elsif( $ARGV[0] eq "-attrib" )
	          { shift(@ARGV); $argument{attrib} = $ARGV[0]; }
         elsif( $ARGV[0] eq ("-room" or "-r") )
              {
	          shift(@ARGV);
              if   ( $ARGV[0] eq "iriguchi" )
                   { $argument{room1} = "MONA8094";    $argument{socketport} = 9095; shift(@ARGV); }
              elsif( $ARGV[0] eq "atochi" )
                   { $argument{room1} = "ANIKI8088";   $argument{socketport} = 9083; shift(@ARGV); }
              elsif( $ARGV[0] eq "ooheya" )
                   { $argument{room1} = "MONABIG8093"; $argument{socketport} = 9093; shift(@ARGV); }
              elsif( $ARGV[0] eq "chibichato" )
                   { $argument{room1} = "ANIMAL8098";  $argument{socketport} = 9090; shift(@ARGV); }
              elsif( $ARGV[0] eq "moa" )
                   { $argument{room1} = "MOA8088";     $argument{socketport} = 9092; shift(@ARGV); }
              elsif( $ARGV[0] eq "chiikibetsu" )
                   { $argument{room1} = "AREA8089";    $argument{socketport} = 9095; shift(@ARGV); }
              elsif( $ARGV[0] eq "wadaibetsu" )
                   { $argument{room1} = "ROOM8089";    $argument{socketport} = 9090; shift(@ARGV); }
              elsif( $ARGV[0] eq "tateyokoheya" )
                   { $argument{room1} = "MOXY8097";    $argument{socketport} = 9093; shift(@ARGV); }
              elsif( $ARGV[0] eq "cool" )
                   { $argument{room1} = "COOL8099";    $argument{socketport} = 9090; shift(@ARGV); }
              elsif( $ARGV[0] eq "kanpu" )
                   { $argument{room1} = "kanpu8000";   $argument{socketport} = 9094; shift(@ARGV); }
              elsif( $ARGV[0] eq "monafb" )
                   { $argument{room1} = "MOFB8000";    $argument{socketport} = 9090; shift(@ARGV); }
              $argument{room2} = $ARGV[0];
              }
		 else { die "Command not recognized.\n"; }
         shift(@ARGV);
         }
     }

share(%argument);
share(%option);
share(%socketdata);
share(%proxy);
share(@proxyaddr);
share(@proxyport);

get_argument();

$logindata   =  Userdata->new_login_data(
                $argument{name}||"American man...",
                $argument{character}||"chotto1",
                $argument{status}||"normal",
	            $argument{r}||100,
	            $argument{g}||100,
	            $argument{b}||100,
                $argument{xposition}||381,
                $argument{yposition}||275,
                $argument{scl}||100,
                $argument{room1}||"MONA8094",
                $argument{room2}||"main",
	            $argument{attrib}||"no" );
$userdata    = Userdata->new_user_data();
%socketdata  = ( address => $argument{socketaddress}||"153.122.46.192",
                 port    => $argument{socketport}||9095 );
%proxy       = ( on           => $argument{proxyon}||0,
	             timeout      => $argument{proxytimeout}||2,
	             debug        => $argument{proxydebug}||1,
                 skip         => $argument{proxyskip}||0 );
login("firsttime");

$semaphore = Thread::Semaphore->new();

$pingthread       = threads->create(\&ping);
$readsocketthread = threads->create(\&read_socket);

Win32::GUI->Dialog();
