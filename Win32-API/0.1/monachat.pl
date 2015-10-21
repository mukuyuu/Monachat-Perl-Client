use IO::Socket;
use Socket;
use threads;
use threads::shared qw(share);
use Encode /encode decode/;
use Win32::GUI;
use Win32::GUI::Constants;
use IO::Select;
use IO::Socket::Socks;
use LWP::UserAgent;
use Userdata;

sub Window_Terminate { return -1; }
sub SearchWindow_Terminate
    {
    $searchwindow->Hide();
    $searchoutputfield->SelectAll();
    $searchoutputfield->ReplaceSel( "" );
    }

sub Inputfield_KeyDown
    {
    shift;
    my($key) = shift;
    if( $key == 13 )
      {
      my($readtext) = $inputfield->Text();
	  if( $readtext )
	    {
        if ( $readtext =~ /^\// )
	       { command_list($readtext); }
        else
	       {
	       $readtext = decode("cp932", $readtext) or die "Couldn't decode: $!\n";
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
    if   ( $command =~ /\/login/ )
	     { login(); }
    elsif( $command =~ /\/relogin\s*(.*)/ )
	     {
	     if   ( $1 =~ /room/ )
	          { enter_room(); }
	     else { login("relogin"); }
	     }
    elsif( $command =~ /\/disconnect\s*(\d*)/ )
	     {
	     if( $select->can_write() )
	       { print $remote "<EXIT />\0"; print $remote "<NOP />\0"; print $remote "<NOP />\0"; }
	     if   ( $1 ) { login("relogin"); }
	     else {
		      $pingthread->kill("KILL");
			  $pingthread->detach();
			  $readsocketthread->kill("KILL");
			  $readsocketthread->detach();
			  }
	     }
    elsif( $command =~ /\/name (.+)/ )
	     {
	     my($name) = $1;
	     my($id) = $logindata->get_id();
	     $userdata->set_name($name, $id);
	     enter_room("reenter");
	     }
    elsif( $command =~ /\/character (.+)/ )
	     {
	     my($character) = $1;
	     my($id) = $logindata->get_id();
	     $userdata->set_character($character, $id);
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
	     $logindata->set_r($r);
         $logindata->set_g($g);
         $logindata->set_b($b);
	     enter_room("enterroom");
	     }
    elsif( $command =~ /\/x (.+)/ )
	     { send_x_y_scl("x$1"); }
    elsif( $command =~ /\/y (.+)/ )
	     { send_x_y_scl("y$1"); }
    elsif( $command =~ /\/move (x\d+)|move (y\d+)|move (x\d+) (y\d+)|move (y\d+) (x\d+)/ )
	     {
         my($x, $y, $line);
	     if( $1 =~ /x(.+)/ or $2 =~ /x(.+)/ ) { $line .= "x$1"; }
	     if( $1 =~ /y(.+)/ or $2 =~ /y(.+)/ ) { $line .= "y$1"; }
         send_x_y_scl($line);
	     }
    elsif( $command =~ /\/scl/ )
	     {
         my($id) = $logindata->get_id();
         my($scl) = $userdata->get_scl($id);
         if   ( $scl ==  100 ) { $scl = -100; }
         elsif( $scl == -100 ) { $scl =  100; }
         send_x_y_scl("scl$scl");
	     }
    elsif( $command =~ /\/attrib/ )
	     {
	     $userdata->set_attrib($id);
	     enter_room("reenter");
	     }
    elsif( $command =~ /\/ignore (\d{1,3})/ )
	     {
		 my($id) = $1;
	     my($ihash) = $userdata->get_ihash($id);
	     if( $select->can_write() )
	       { print $remote "<IG ihash=\"$ihash\" />\0"; }
	     }
    elsif( $command =~ /\/search\s*(.*)/ )
	     {
	     $logindata{currentroom} = $logindata{room2};
	     $logindata{room2} = "main";
	     if   ( $1 =~ /user (.+)/ )
              { search("user", $1); }
	     if   ( $1 =~ /all/ )
              { search("all"); }
         else { search("rooms"); }
	     enter_room("reenter");
	     }
    elsif( $command =~ /\/stalk (.+)/ )
	     {
	     if   ( $1 =~ /on/  ) { $option{stalk} = 1; printoutput("Stalk on\n"); }
	     elsif( $1 =~ /off/ ) { $option{stalk} = 0; printoutput("Stalk off\n"); }
	     elsif( $1 =~ /(\d{1,3})/ )
	          {
			  if( $option{stalk} == 0 ) { $option{stalk} = 1; }
			  my($id) = $1;
	          $userdata->set_stalk($id);
	          if   ( $1 =~ /nomove/ )
	               { $option{nomove} = 1; }
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
		 if   ( $1 =~ /on/  ) { $option{antistalk} = 1; }
		 elsif( $1 =~ /off/ ) { $option{antistalk} = 0; }
	     elsif( $1 =~ /(\d{1,3})/ )
	          {
		      if( $option{antistalk} == 0 ) { $option{antistalk} = 1; }
		      my($id) = $1;
		      $userdata->set_antistalk($id);
	          }
	     }
    elsif( $command =~ /\/copy (.+)/ )
	     {
         my($copyid) = $1;
         my($id) = $logindata->get_id();
	     $userdata->set_name($userdata->get_name($copyid), $id);
	     $userdata->set_status($userdata->get_status($copyid), $id);
	     $userdata->set_character($userdata->get_character($copyid), $id);
	     $userdata->set_r($userdata->get_r($copyid), $id);
	     $userdata->set_g($userdata->get_g($copyid), $id);
	     $userdata->set_b($userdata->get_b($copyid), $id);
	     $userdata->set_x($userdata->get_x($copyid), $id);
	     $userdata->set_y($userdata->get_y($copyid), $id);
	     $userdata->set_scl($userdata->get_scl($copyid), $id);
	     enter_room("reenter");
	     }
    elsif( $command =~ /\/default/ )
	     {
		 my($id) = $logindata->get_id();
	     $userdata->set_name($logindata->get_name(), $id);
	     $userdata->set_status($logindata->get_status(), $id);
		 $userdata->set_character($logindata->get_character(), $id);
		 $userdata->set_trip($logindata->get_trip()||"", $id);
		 $userdata->set_r($logindata->get_r(), $id);
		 $userdata->set_g($logindata->get_g(), $id);
		 $userdata->set_b($logindata->get_b(), $id);
		 $userdata->set_x($logindata->get_x(), $id);
		 $userdata->set_y($logindata->get_y(), $id);
		 $userdata->set_scl($logindata->get_scl(), $id);
		 $option{stalk}  = 0;
		 $option{nomove} = 0;
		 enter_room("reenter");
		 }
	elsif( $command =~ /\/invisible/ )
		 {
         my($id) = $logindata->get_id();
		 $userdata->set_name(undef, $id);
		 $userdata->set_status(undef, $id);
		 $userdata->set_character(undef, $id);
		 $userdata->set_trip(undef, $id);
		 $userdata->set_r(undef, $id);
		 $userdata->set_g(undef, $id);
		 $userdata->set_b(undef, $id);
		 $userdata->set_x(undef, $id);
		 $userdata->set_y(undef, $id);
         $userdata->set_scl(undef, $id);
		 enter_room("reenter");
		 }
    elsif( $command =~ /\/proxy\s*(.*)/ )
		 {
	     if   ( $1 =~ /on/ )
	          {
	          $proxy{on} = 1;
	          print_output("Proxy on\n");
              }
	     elsif( $1 =~ /off/ )
	          {
	          $proxy{on} = 0;
	          print_output("Proxy off\n");
              }
	     elsif( $1 =~ /timeout\s*(\d\.*\d*)/ )
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
	          my($keys);
              undef $userdata;
              $userdata = Userdata->new_user_data();
	          }
		 }
    elsif( $command =~ /\/newinstance\s*(.*)/ )
		 {
		 if ( $1 =~ /here\s*(.*)\s*(.*)/ )
	        {
	        my($newinstancecounter) = $1||1;
	        my($second) = $2||2;
	        for( my($counter) = 0; $counter < $newinstancecounter; $counter++ )
	           {
	           system("perl monachat.pl -proxy -timeout 1 -room $logindata->getroom2()");
	           sleep($second);
	           }
	        }
	     else { system("start perl monachat.pl -proxy -timeout 1"); }
	     }
    elsif( $command =~ /\/antiignore\s*(\d*)/ )
	     {
		 if   ( $1 =~ /on/  ) { $option{antiignoreon} = 1; }
		 elsif( $1 =~ /off/ ) { $option{antiignoreon} = 0; }
		 elsif( $1 =~ /(\d{1,3})/ )
		      {
		      my($id) = $1;
		      $userdata->set_antiignore($id);
	          $option{antiignoreon} = 1;
	          if   ( $userdata->get_antiignore($id) == 0 ) { $userdata->set_antiignore(1, $id); }
	          elsif( $userdata->get_antiignore($id) == 1 ) { $userdata->set_antiignore(0, $id); }
	          }
	     elsif( $1 =~ /all/ )
	          {
	          if   ( $option{antiignoreall} == 0 ) { $option{antiignoreall} = 1; }
	          elsif( $option{antiignoreall} == 1 ) { $option{antiignoreall} = 0; }
	          }
	     }
    }


sub print_output
    {
    my($text) = shift;
    $text = encode("cp932", $text);
	$outputfield->Append("$text");
    }

sub login
    {
    my($option) = shift;
    if ( $option eq "relogin" )
       {
	   $pingthread->kill("KILL");
	   if( !$pingthread->is_detached() )
	     { $pingthread->detach(); }
	   $readsocketthread->kill("KILL");
	   if( !$readsocketthread->is_detached() )
	     { $readsocketthread->detach(); }
       }
   if  ( $proxy{on} == 1 )
       {
       while()
            {
            if( !@proxyaddr[0] ) { get_proxy_list(); }
            $remote = IO::Socket::Socks->new( ProxyAddr   => @proxyaddr[0],
	                                          ProxyPort   => @proxyport[0],
	                                          ConnectAddr => $socketdata{address}||"153.122.46.192",
	                                          ConnectPort => $socketdata{port}||"9095",
	                                          SocksDebug  => $proxy{debug}||1,
	                                          Timeout     => $proxy{timeout}||2 )
            or warn "$SOCKS_ERROR\n" && shift @proxyaddr && shift @proxyport && redo;
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
	  $readsocketthread = threads->create(\&readsocket);
	  $pingthread       = threads->create(\&ping);
	  }
    }

sub enter_room
    {
    my($option) = shift;
	my($id) = $logindata->get_id();
    if   ( $option eq "reenter" )
         {
         if( $select->can_write() )
	       { print $remote "<EXIT no=\"$id\" \/>\0"; }
         }
	if   ( $option eq "firsttime" )
	     {
		 if( $select->can_write() )
		   {
		   if   ( $logindata{room2} eq "main" )
	            { print $remote "<ENTER room=\"", $logindata->get_room(), "\" name=\"", $logindata->get_name(), "\" attrib=\"", $logindata->get_attrib(), "\" />\0"; }
           else { print $remote "<ENTER room=\"", $logindata->get_room(), "/", $logindata->get_room2(), "\" umax=\"0\" type=\"", $logindata->get_character(), "\" name=\"", $logindata->get_name(), "\" x=\"", $logindata->get_x(), "\" y=\"", $logindata->get_y(), "\" r=\"", $logindata->get_r(), "\" g=\"", $logindata->get_g(), "\" b=\"", $logindata->get_b(), "\" scl=\"", $logindata->get_scl(), "\" status=\"", $logindata->get_status(), "\" />\0"; }
		   }
		 }
	else {
         if( $select->can_write() )
           {
           if   ( $logindata{room2} eq "main" )
	            { print $remote "<ENTER room=\"", $logindata->get_room(), "\" name=\"", $userdata->get_name($id), "\" attrib=\"", $userdata->get_attrib($id), "\" />\0"; }
           else { print $remote "<ENTER room=\"", $logindata->get_room(), "/", $logindata->get_room2(), "\" umax=\"0\" type=\"", $userdata->get_character($id), "\" name=\"", $userdata->get_name($id), "\" x=\"", $userdata->get_x($id), "\" y=\"", $userdata->get_y($id), "\" r=\"", $userdata->get_r($id), "\" g=\"", $userdata->get_g($id), "\" b=\"", $userdata->get_b($id), "\" scl=\"", $userdata->get_scl($id), "\" status=\"", $userdata->get_status($id), "\" />\0"; }
           }
		 }
    }

sub send_x_y_scl
    {
	my($line) = shift;
	my($x, $y, $scl);
	my($id) = $logindata->get_id();
	if( $line =~ /x(\d+)/   ) { $x = $1; }
	if( $line =~ /y(\d+)/   ) { $y = $1; }
	if( $line =~ /scl(-?\d+)/ ) { $scl = $1; }
	$x   = $x||$userdata->get_x($id);
	$y   = $y||$userdata->get_y($id);
	$scl = $scl||$userdata->get_scl($id);
    if( $select->can_write() )
      { print $remote "<SET x=\"$x\" scl=\"$scl\" y=\"$y\" />\0"; }
    }

sub get_proxy_list
    {
	$useragent = LWP::UserAgent->new();
	$useragent->agent("getproxylist");
	$useragent->show_progress(1);
    $proxylist = $useragent->get("http://www.socks-proxy.net");
	$proxylist = $proxylist->content();
    my($counter) = 0;
    while( $proxylist =~ /<td>(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})<\/td><td>(\d{4,5})<\/td><td>(US|GB|CA|AU|JP)<\/td><td>(.+?)<\/td>/g )
         {
	     @proxyaddr[$counter] = "$1";
	     @proxyport[$counter] = "$2";
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
	        if( $counter == 100 )
	          {
	          if( $select->can_write() )
	            { print $remote "<NOP />\0"; }
	          }
	        }
	     }
    }

sub read_socket
    {
    while()
	     {
		 local $SIG{"KILL"} = sub{ die; };
	     if( $select->can_read(0.2) )
	       {
	       sysread($remote, $read, 20000);
	       $read = decode("utf8",  $read) or warn "Couldn't decode: $!" and select(undef, undef, undef, 0.5);
	       #$read = encode("cp932", $read) or warn "Couldn't encode: $!" and select(undef, undef, undef, 0.5);
	       @read = split(/>/, $read);
	       for( my ($counter) = 0; @read[$counter + 1]; $counter++ )
	          {
	          if( !( @read[$counter] =~ /\+connect|Connection timeout\.\.>/ ) )
	            { @read[$counter] = @read[$counter] . ">"; }
	          }
	       print_read(@read);
	       }
	     else { print $counter++, "\n"; }
	     }
    }

sub save_and_print_user_data
    {  
    my($mode, $id, $name, $character, $status, $trip, $ihash, $r, $g, $b, $x, $y, $scl) = @_;
    $userdata->set_name($name, $id);
    $userdata->set_id($id);
    $userdata->set_character($character, $id);
    $userdata->set_status($status, $id);
    $userdata->set_trip($trip, $id);
    $userdata->set_ihash($ihash, $id);
    $userdata->set_r($r, $id);
    $userdata->set_g($g, $id);
    $userdata->set_b($b, $id);
    $userdata->set_x($x, $id);
    $userdata->set_y($y, $id);
    $userdata->set_scl($scl, $id);
    if   ( $option{stalk} == 1 )
	     {
	     if( $userdata->get_stalk($userdata->get_ihash($id)) )
	       { $userdata->set_stalk($id); }
	     }
    if   ( $option{antistalk} == 1 )
	     {
	     if( $userdata->get_antistalk($userdata->get_ihash($id)) )
	       { $userdata->set_antistalk($id); }
	     }
    if   ( $userdata->get_scl($id) ==  "100" ) { $scl = "right"; }
    elsif( $userdata->get_scl($id) == "-100" ) { $scl = "left";  }
    if   ( $userdata->get_trip($id) =~ /trip="(.+?)"/ )
	     {
	     $userdata->set_trip($1, $id);
	     print_output("$name $trip $ihash ($id) $status $character x$x $scl");
         }
    else { print_output("$name $ihash ($id) $status $character x$x $scl"); }
    if   ( $mode eq "ENTER" )
    	 { print_output(" has logged in\n"); }
    elsif( $mode eq "USER" )
    	 { print_output("\n"); }
	}

sub print_read
    {
    my(@read) = @_;
    while( @read )
	     {
	     if   ( @read[0] =~ /\+connect id=(\d{1,3})/ )
	          {}
	     elsif( @read[0] =~ /<CONNECT id="(.+?)" \/>/ )
	          {
              my($id) = $1;
	          $logindata->set_id($id);
	          print_output("Logged in, id=$id\n\n");
              }
	     elsif( @read[0] =~ /<ROOM>/ )
	          {}
	     #    { $outputfield->Append( "Users in this room:\n" ); }
	     elsif( @read[0] =~ /<ROOM \/>/ )
	          {}
	     elsif( @read[0] =~ /<(\w{4,5}) r="(\d{1,3}?)" name="(.*?)" id="(\d{1,3})"(.+?)ihash="(.{10})".+\w{4,6}="(.*?)" g="(\d{1,3}?)" type="(.*?)" b="(\d{1,3}?)" y="(.*?)" x="(.*?)" scl="(.+?)" \/>/ )
	          { save_and_print_user_data($1, $4, $3, $7, $9, $5, $6, $2, $8, $10, $12, $11, $13); }
	     elsif( @read[0] =~ /<USER ihash="(.+?)" name="(.*?)" id="(.+?)" \/>/ )
	          { print_output("User $2 $1 ($3) has logged in\n"); }
	     elsif( @read[0] =~ /<ENTER id="(.+?)" \/>/ )
	          { print_output("User with id $1 entered this room\n"); }
	     elsif( @read[0] =~ /<UINFO name="(.*?)" id="(\d{1,3})" \/>/ )
	          {
	          if( $logindata->get_room2() eq "main" )
	            { print_output("$1 id=$2\n"); }
	          }
         elsif( @read[0] =~ /<SET stat="(.*?)" id="(.+?)" \/>/ )
	          {
			  my($status, $id) = ($1, $2);
			  my($name) = $userdata->get_name($id);
			  $userdata->set_status($status, $id);
			  print_output("$name changed his status to $status");
	          }
	     elsif( @read[0] =~ /<SET x="(.*?)" scl="(.+?)" id="(.+?)" y="(.*?)" \/>/ )
	          {
	          my($x, $scl, $id, $y) = ($1, $2, $3, $4);
              my($name) = $userdata->get_name($id);
	          if( $userdata->get_x($id) != $x )
	            {
	            $userdata->set_x($x, $id);
                my($x) = $userdata->get_x($id);
	            print_output("$name moved to x $x\n");
                }
	          if( $userdata->get_y($id) != $y )
	            {
	            $userdata->set_y($4, $id);
                my($y) = $userdata->get_y($id);
	            print_output("$name moved to y $y\n");
                }
	          if( $userdata->get_scl($id) != $scl )
	            {
	            $userdata->set_scl($scl, $id);
	            if   ( $userdata->get_scl($id) ==  100 ) { $scl = "right"; }
	            elsif( $userdata->get_scl($id) == -100 ) { $scl =  "left"; }
	            print_output("$name moved to $scl\n");
                }
	          if( $option{stalk} == 1 && $option{nomove} == 0 && $userdata->get_stalk($3) )
	            {
	            $userdata->set_x($1, $id);
	            $userdata->set_y($4, $id);
	            $userdata->set_scl($2, $id);
                send_x_y_scl();
	            }
	          if( $option{antistalk} == 1 && $userdata->get_antistalk($3) )
                {
	            if( $userdata->get_x($id) - $1 < 40 && $userdata->get_x($id) - $1 > -40 )
	              { $userdata->set_x(680-$1+40); }
	            if( $userdata->get_y($id) - $4 < 40 && $userdata->get_y($id) - $4 > -40 )
	              { $userdata->set_y(320-$4+240); }
                send_x_y_scl();
	            }
	          }
	     elsif( @read[0] =~ /<IG (ihash=".{10}") (id=".+?") \/>|<IG (ihash=".{10}") (stat=".+?") (id=".+?") \/>/ )
	          {
	          my($name, $id, $stat, $trip, $ihash, $ignore, $ignoredname, $ignoredihash, $antiignoreid);
	          {
	          if ( $1 =~ /ihash="(.+?)"/ )
	             {
	             ($ihash, $ignoredname, $ignoredid, $ignoredihash) =
	             ("$1", "name$trip{$1}", "id$trip{$1}", "ihash$trip{$1}");
	             }
	          }
	          {
	          if ( $2 =~ /id="(.+?)"/ or $3 =~ /id="(.+?)"/ )
	             {
	             ($name, $id, $trip, $ihash, $ignore, $antiignoreid) =
	             ("name$1", "id$1", "trip$1", "ihash$1", "$1ignore$ihash", "antiignore$1");
	             }
	          }
	          {
	          if ( $2 =~ /stat="(.+?)"/ )
	             { $stat = $1; }
	          }
	          if ( ($stat eq "on" or $usersdata{$ignore} == undef) and $stat ne "off" )
	             {
	             $usersdata{$ignore} = 1;
	             $outputfield->Append( "$usersdata{$name} $usersdata{$ihash} ($usersdata{$id}) ignored " );
	             $outputfield->Append( "$usersdata{$ignoredname} $usersdata{$ignoredihash} ($usersdata{$ignoredid})\n" );
	             }
	          elsif( $stat eq "off" or $usersdata{$ignore} == 1 )
	               {
	               $usersdata{$ignore} = undef;
	               $outputfield->Append( "$usersdata{$name} $usersdata{$ihash} ($usersdata{$id}) stopped ignoring " );
	               $outputfield->Append( "$usersdata{$ignoredname} $usersdata{$ignoredihash} ($usersdata{$ignoredid})\n" );
	               }
	          if   ( $ignore{antiignoreon} == 1 )
	               {
	               if   ( $ignore{antiignoreall} == 1 ) { login("relogin"); }
	               elsif( $ignore{$antiignoreid} == 1 ) { login("relogin"); }
	               }
	          }
	     elsif( @read[0] =~ /<EXIT \/>/ )
	          { print_output("You exited the room\n" ); }
	     elsif( @read[0] =~ /<EXIT id="(.+?)" \/>/ )
	          {
              my($id)    = $1;
              my($name)  = $userdata->get_name($id);
              my($ihash) = $userdata->get_ihash($id);
	          print_output("$name $ihash ($id) exited this room\n");
	          }
	     elsif( @read[0] =~ /<COUNT>/ )
	          {
	          #print_output("Rooms:\n");
	          while( !( @read[0] =~ /<\/COUNT>/ ) )
	               {
	               shift @read;
	               if( @read[0] =~ /<ROOM c="(.+?)" n="(.+?)" \/>/ and $logindata->get_room2() eq "main" )
	                 { print_output("room $2 persons $1\n"); }
	               }
	          }
	     elsif( @read[0] =~ /<ROOM c="(.+?)" n="(.+?)" \/>/ )
	          {
	          if( $1 != "0" )
	            { print_output("room $2 persons $1\n"); }
	          }
	     elsif( @read[0] =~ /<\/ROOM>/ )
	          {}
	     elsif( @read[0] =~ /<\/COUNT>/ )
	          {}
	     elsif( @read[0] =~ /<COUNT \/>/ )
	          {}
	     elsif( @read[0] =~ /<COUNT c="(.+?)" n="(.+?)" \/>/ )
	          { print_output("room $2 persons $1\n"); }
	     elsif( @read[0] =~ /<COM cmt="(.+?)" (.+?) \/>/ )
	          {
              #<COM cmt"(.+?)" id="(.+?)" cnt="(.+?)" \/>
              #<COM cmt="(.+?)" cnt="(.+?)" id="(.+?)" \/>
              #<COM cmt="(.+?)" id="(.+?)" \/>
              my($comment) = $1;
              my($id);
              if( $2 =~ /id="(.+)"/ ) { $id = $1; }
              my($name)  = $userdata->get_name($id);
              my($trip)  = $userdata->get_trip($id);
              my($ihash) = $userdata->get_ihash($id);
              my($id)    = $userdata->get_id($id);
	          if   ( $userdata->get_trip($id) )
	               { print_output("$name $trip $ihash ($id): $comment\n"); }
	          else { print_output("$name $ihash ($id): $comment\n"); }
	          if ( $option{stalk} == 1 )
	             {
	             if( $userdata->get_stalk($id) )
	               {
	               $comment = decode("cp932", $comment);
	               $comment = encode("utf8",  $comment);
	               if( $select->can_write() )
	                 { print $remote "<COM cmt=\"$comment\" />\0"; }
	               }
	             }
	          }
	     elsif( @read[0] =~ /Connection timeout\.\./ )
	          {
	          print_output("Connection timeout..\n");
	          login();
	          }
	     elsif( @read[0] =~ /^<R|^<USER/ )
	          {
	          my($line) = (shift @read) . @read[0];
	          if   ( $line !~ />$/ )
	               { $line = $line . ">"; }
	          if   ( $line =~ /<ROOM c="(.+?)" n="(.+?)" \/>/ )
	               {
	               if( $1 != 0 )
	                 { print_output("room $2 persons $1\n"); }
	               }
	          elsif( $line =~ /<(\w{4,5}) r="(\d{1,3})" name="(.*?)" id="(\d{1,3})"(.+?)ihash="(.{10})" \w{4,6}="(.*?)" g="(\d{1,3})" type="(.*?)" b="(\d{1,3})" y="(.*?)" x="(.*?)" scl="(.+?)" \/>/ )
	               { save_and_print_user_data($1, $4, $3, $9, $7, $5, $6, $2, $8, $10, $12, $11, $13); }
	          else { print_output("$line\n"); }
	          }
         else { print_output("$read[0]\n"); }
	     shift @read;
	     }
	}

$window      = Win32::GUI::Window->new( -name => "Window", -title => "Monachat", -height => 320, -width => 620 );
#$tab        = $window->AddTabStrip( -name => "Tab", -height => 320, -width => 620, -left => 0, -top => 0 );
#$tab1       = $tab->InsertItem( -text => 1 );
$inputfield  = $window->AddTextfield  ( -name => "Inputfield", -height => 30, -width => 598, -left => 2,
                                        -top => 240, -multiline => 1, -autohscroll => 1 );
$outputfield = $window->AddTextfield  ( -height => 220, -width => 598, -left => 2, -top => 10, -multiline => 1,
                                        -readonly => 1, -vscroll => 1, -autovscroll => 1 );
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
    while( @ARGV[0] )
         {
         if   ( @ARGV[0] eq ("-proxy" or "-p") )
              { $argument{proxyon} = 1; }
         elsif( @ARGV[0] eq ("-timeout" or "-t") )
              { shift(@ARGV); $argument{proxytimeout} = @ARGV[0]; }
         elsif( @ARGV[0] eq "-debug" )
	          { $argument{proxydebug} = 1; }
		 elsif( @ARGV[0] eq "-skip" )
		      {
			  if  ( @ARGV[1] =~ /\d/ )
			      { $argument{proxyskip} = shift; }
			  else{ $argument{proxyskip} = 1; }
			  }
         elsif( @ARGV[0] eq "-ip" )
	          { shift(@ARGV); $argument{socketaddress} = @ARGV[0]; }
         elsif( @ARGV[0] eq "-port" )
	          { shift(@ARGV); $argument{socketport} = @ARGV[0]; }
         elsif( @ARGV[0] eq "-name" )
	          { shift(@ARGV); $argument{name} = @ARGV[0]; }
         elsif( @ARGV[0] eq "-character" )
	          { shift(@ARGV); $argument{character} = @ARGV[0]; }
         elsif( @ARGV[0] eq "-status" )
	          { shift(@ARGV); $argument{status} = @ARGV[0]; }
         elsif( @ARGV[0] eq "-rgb" )
	          {
	          shift(@ARGV); $argument{r} = @ARGV[0];
	          shift(@ARGV); $argument{g} = @ARGV[0];
	          shift(@ARGV); $argument{b} = @ARGV[0];
	          }
         elsif( @ARGV[0] eq "-x" )
	          { shift(@ARGV); $argument{xposition} = @ARGV[0]; }
         elsif( @ARGV[0] eq "-y" )
	          { shift(@ARGV); $argument{yposition} = @ARGV[0]; }
         elsif( @ARGV[0] eq "-scl" )
	          { shift(@ARGV); $argument{scl} = @ARGV[0]; }
         elsif( @ARGV[0] eq "-attrib" )
	          { shift(@ARGV); $argument{attrib} = @ARGV[0]; }
         elsif( @ARGV[0] eq ("-room" or "-r") )
              {
	          shift(@ARGV);
              if   ( @ARGV[0] eq "iriguchi" )
                   { $argument{room1} = "MONA8094";    $argument{socketport} = 9095; shift(@ARGV); }
              elsif( @ARGV[0] eq "atochi" )
                   { $argument{room1} = "ANIKI8088";   $argument{socketport} = 9083; shift(@ARGV); }
              elsif( @ARGV[0] eq "ooheya" )
                   { $argument{room1} = "MONABIG8093"; $argument{socketport} = 9093; shift(@ARGV); }
              elsif( @ARGV[0] eq "chibichato" )
                   { $argument{room1} = "ANIMAL8098";  $argument{socketport} = 9090; shift(@ARGV); }
              elsif( @ARGV[0] eq "moa" )
                   { $argument{room1} = "MOA8088";     $argument{socketport} = 9092; shift(@ARGV); }
              elsif( @ARGV[0] eq "chiikibetsu" )
                   { $argument{room1} = "AREA8089";    $argument{socketport} = 9095; shift(@ARGV); }
              elsif( @ARGV[0] eq "wadaibetsu" )
                   { $argument{room1} = "ROOM8089";    $argument{socketport} = 9090; shift(@ARGV); }
              elsif( @ARGV[0] eq "tateyokoheya" )
                   { $argument{room1} = "MOXY8097";    $argument{socketport} = 9093; shift(@ARGV); }
              elsif( @ARGV[0] eq "cool" )
                   { $argument{room1} = "COOL8099";    $argument{socketport} = 9090; shift(@ARGV); }
              elsif( @ARGV[0] eq "kanpu" )
                   { $argument{room1} = "kanpu8000";   $argument{socketport} = 9094; shift(@ARGV); }
              elsif( @ARGV[0] eq "monafb" )
                   { $argument{room1} = "MOFB8000";    $argument{socketport} = 9090; shift(@ARGV); }
              $argument{room2} = @ARGV[0];
              }
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

$pingthread       = threads->create(\&ping);
$readsocketthread = threads->create(\&read_socket);

Win32::GUI->Dialog();
