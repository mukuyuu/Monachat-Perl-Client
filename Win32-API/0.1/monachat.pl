use IO::Socket;
use Socket;
use threads;
use threads::shared;
use Encode /encode decode/;
use Win32::GUI;
use Win32::GUI::Constants;
use IO::Select;
use IO::Socket::Socks;
use LWP::UserAgent;
use Userdata;
use Search;

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
      if ( $readtext =~ /^\// )
	     { command_list($readtext); }
      else
	     {
	     if( $encrypt{on} == 1 )
	       {
	       if( $encrypt{reverse} == 1 )
	         { $readtext = reverse($readtext); }
	       }
	     #$outputfield->Append("$readtext\n");
	     #$readtext = decode("cp932", $readtext) or die "Couldn't decode: $!\n";
	     #$readtext = encode("utf8",  $readtext) or die "Couldn't encode: $!\n";
	     #$outputfield->Append("<COM cmt=\"$readtext\" />\n");
	     if( $select->can_write() )
	       { print $remote "<COM cmt=\"$readtext\" />\0"; }
	     }
      $inputfield->SelectAll();
      $inputfield->ReplaceSel("");
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
	     {
	     my($status) = $1;
	     my($id) = $logindata->get_id();
	     $userdata->set_status($status, $id);
	     print $remote "<SET stat=\"", $userdata->get_status($id), "\" />\0";
	     }
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
	     {
	     my($x) = $1;
         my($id) = $logindata->get_id();
         $userdata->set_x($x, $id);
         send_x_y_scl();
	     }
    elsif( $command =~ /\/y (.+)/ )
	     {
	     my($y) = $1;
         my($id) = $logindata->get_id();
         $userdata->set_y($y, $id);
         send_x_y_scl();
	     }
    elsif( $command =~ /\/move (x.+)|move (y.+)|move (x.+) (y.+)|move (y.+) (x.+)/ )
	     {
         my($x, $y);
	     if( $1 =~ /x(.+)/ or $2 =~ /x(.+)/ ) { $x = $1; $userdata->set_x($x, $id); }
	     if( $1 =~ /y(.+)/ or $2 =~ /y(.+)/ ) { $y = $1; $userdata->set_y($y, $id); }
         send_x_y_scl();
	     }
    elsif( $command =~ /\/scl/ )
	     {
         my($id) = $logindata->get_id();
         my($scl) = $userdata->get_scl($id);
         if   ( $scl ==  100 ) { $scl = -100; }
         elsif( $scl == -100 ) { $scl =  100; }
	     $userdata->set_scl($scl, $id);
         send_x_y_scl();
	     }
    elsif( $command =~ /\/attrib/ )
	     {
	     $userdata->set_attrib($id);
	     enter_room("reenter");
	     }
    elsif( $command =~ /\/ignore (\d{1,3})/ )
	     {
	     my($ihash) = "ihash$1";
	     if( $select->can_write() )
	       { print $remote "<IG ihash=\"$userdata{$ihash}\" />\0"; }
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
	     if   ( $stalk{on} == 0 ) { $stalk{on} = 1; printoutput("stalk on\n"); }
	     elsif( $stalk{on} == 1 ) { $stalk{on} = 0; printoutput("stalk off\n"); }
	     if   ( $1 =~ /(\d{1,3})/ )
	          {
	          my($ihash) = "ihash$1";
	          $stalk{id}    = $1;
	          $stalk{ihash} = $usersdata{$ihash};
	          if   ( $1 =~ /nomove/ )
	               { $stalk{nomove} = 1; }
	          else {
	               $stalk{nomove} = 0;
	               my($x, $y, $scl) = ("x$1", "y$1", "scl$1");
	               $logindata{xposition} = $userdata{$x};
	               $logindata{yposition} = $userdata{$y};
	               $logindata{scl}       = $userdata{$scl};
                   send_x_y_scl();
	               }
	         }
	     }
    elsif( $command =~ /\/antistalk (.+)/ )
	     {
	     my($ihash) = "ihash$1";
	     if   ( $stalk{antistalkon} == 0 ) { $stalk{antistalkon} = 1; }
	     elsif( $stalk{antistalkon} == 1 ) { $stalk{antistalkon} = 0; }
	     if( $1 =~ /(\d{1,3})/ )
	       {
	       $stalk{antistalkid} = $1;
	       $stalk{antistalkihash} = $usersdata{$ihash};
	       }
	     }
    elsif( $command =~ /\/copy (.+)/ )
	     {
         my($id) = $1;
         my($loginid) = $logindata->get_id();
	     $userdata->set_name($userdata->get_name($id));
	     $userdata->set_status($userdata->get_status($id));
	     $userdata->set_character($userdata->get_character($id));
	     $userdata->set_r($userdata->get_r($id));
	     $userdata->set_g($userdata->get_g($id));
	     $userdata->set_b($userdata->get_b($id));
	     $userdata->set_x($userdata->get_x($id));
	     $userdata->set_y($userdata->get_y($id));
	     $userdata->set_scl($userdata->get_scl($id));
	     enter_room("reenter");
	     }
    elsif( $command =~ /\/default/ )
	     {
	     $userdata->set_name($logindata->get_name());
	     $userdata->set_status($logindata->get_status());
		 $userdata->set_character($logindata->get_character());
		 $userdata->set_trip($logindata->get_trip()||"");
		 $userdata->set_r($logindata->get_r());
		 $userdata->set_g($logindata->get_g());
		 $userdata->set_b($logindata->get_b());
		 $userdata->set_x($logindata->get_x());
		 $userdata->set_y($logindata->get_y());
		 $userdata->set_scl($logindata->get_scl());
		 $stalk{on}            = 0;
		 $stalk{nomove}        = 0;
		 $encrypt{on}          = 0;
		 $encrypt{reverse}     = 0;
		 enter_room("reenter");
		 }
    elsif( $command =~ /\/encrypt\s*(.*)/ )
		 {
		 if   ( $encrypt{on} == 0 ) { $encrypt{on} = 1; }
		 elsif( $encrypt{on} == 1 ) { $encrypt{on} = 0; }
		 if( $1 =~ /reverse/ )
		   { $encrypt{reverse} = 1; }
		 }
    elsif( $command =~ /\/proxy\s*(.*)/ )
		 {
		 if   ( !$1 or $1 =~ /(on|off)/ )
	          {
	          if   ( $proxy{on} == 0  and $1 !~ /off/ )
	               {
	               $proxy{on} = 1;
	               print_output("proxy on\n");
                   }
	          elsif( $proxy{on} == 1 and $1 !~ /on/ )
	               {
	               $proxy{on} = 0;
	               print_output("proxy off\n");
                   }
	          login("relogin");
	          }
	     elsif( $1 =~ /timeout\s*(\d\.*\d*)/ )
	          { $proxy{timeout} = $1; }
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
              $userdata = Userdata->new();
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
	      else { system("perl monachat.pl -proxy -timeout 1"); }
	      }
    elsif( $command =~ /\/invisible/ )
		 {
         my($id) = $logindata->get_id();
		 $userdata->set_name(undef, $id);
		 $userdata->set_character(undef, $id);
		 $userdata->set_status(undef, $id);
		 $userdata->set_trip(undef, $id);
		 $userdata->set_x(undef, $id);
		 $userdata->set_y(undef, $id);
         $userdata->set_scl(undef, $id);
		 enter_room("reenter");
		 }
    elsif( $command =~ /\/antiignore\s*(\d*)/ )
	     {
	     my($antiignoreid) = "$1antiignore";
	     $ignore{antiignoreon} = 1;
		 if   ( $1 =~ /(\d{1,3})/ )
	          {
	          if   ( $ignore{$antiignoreid} == 0 ) { $ignore{$antiignoreid} = 1; }
	          elsif( $ignore{$antiignoreid} == 1 ) { $ignore{$antiignoreid} = 0; }
	          }
	     elsif( $1 =~ /all/ )
	          {
	          if   ( $ignore{antiignoreall} == 0 ) { $ignore{antiignoreall} = 1; }
	          elsif( $ignore{antiignoreall} == 1 ) { $ignore{antiignoreall} = 0; }
	          }
	     else {
	          if   ( $ignore{antiignoreon} == 0 ) { $ignore{antiignoreon} = 1; }
	          elsif( $ignore{antiignoreon} == 1 ) { $ignore{antiignoreon} = 0; }
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
    my($id) = $logindata->get_id();
    if( $select->can_write() )
      { print $remote "<SET x=\"", $userdata->get_x($id), "\" scl=\"", $userdata->get_scl($id), "\" y=\"", $userdata->get_y($id), "\" />\0"; }
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
    $trip{$trip}  = $id;
    $trip{$ihash} = $id;
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
    if   ( $stalk{on} == 1 )
	     {
	     if( $stalk{ihash} == $userdata->get_ihash($id) )
	       { $stalk{id} = $userdata->get_id($id); }
	     }
    if   ( $stalk{antistalkon} == 1 )
	     {
	     if( $stalk{antistalkihash} == $userdata->get_ihash($id) )
	       { $stalk{antistalkid} = $userdata->get_id($id); }
	     }
    if   ( $userdata->get_scl($id) ==  "100" ) { $scl = "right"; }
    elsif( $userdata->get_scl($id) == "-100" ) { $scl = "left";  }
    if   ( $userdata->get_trip($id) =~ /trip="(.+?)"/ )
	     {
	     $userdata->settrip($1, $id);
	     print_output("$name $trip $ihash ($id) $status $character x$x $scl");
         }
    else {
	     print_output("$name $ihash ($id) $status $character x$x $scl");
         }
    if   ( $mode eq "enter" )
    	 { print_output(" has logged in\n"); }
    elsif( $mode eq "user" )
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
              my($id) = $logindata->get_id($id);
	          print_output("Logged in, id=$id\n\n");
              }
	     elsif( @read[0] =~ /<ROOM>/ )
	          {}
	     #    { $outputfield->Append( "Users in this room:\n" ); }
	     elsif( @read[0] =~ /<ROOM \/>/ )
	          {}
	     elsif( @read[0] =~ /<\w{4,5} r="(\d{1,3}?)" name="(.*?)" id="(\d{1,3})"(.+?)ihash="(.{10})".+\w{4,6}="(.*?)" g="(\d{1,3}?)" type="(.*?)" b="(\d{1,3}?)" y="(.*?)" x="(.*?)" scl="(.+?)" \/>/ )
	          {
	          #my($option) = $1;
	          #if   ( $option =~ /USER/  )  { $option = "user";  }
	          #elsif( $option =~ /ENTER/ )  { $option = "enter"; }
	          #$outputfield->Append("$1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13\n");
	          #saveandprintuserdata("$option", $4, $3, $4, $7, $9, $5, $6, $2, $8, $10, $11, $12, $13);
	          save_and_print_user_data("enter", $3, $2, $6, $8, $4, $5, $1, $7, $9, $11, $10, $12);
	          }
	     elsif( @read[0] =~ /<USER ihash="(.+?)" name="(.*?)" id="(.+?)" \/>/ )
	          { print_output("User $2 $1 ($3) has logged in\n"); }
	     elsif( @read[0] =~ /<ENTER id="(.+?)" \/>/ )
	          { print_output("User with id $1 entered this room\n"); }
	     elsif( @read[0] =~ /<UINFO name="(.*?)" id="(\d{1,3})" \/>/ )
	          {
	          if( $logindata{room2} eq "main" )
	            { $outputfield->Append( "$1 id=$2\n" ); }
	          }
         elsif( @read[0] =~ /<SET stat="(.*?)" id="(.+?)" \/>/ )
	          {
	          if( $logindata->get_room2() eq "main" )
	            { print_output("$1 id=$2\n"); }
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
	          if( $stalk{on} == 1 && $stalk{nomove} == 0 && $stalk{id} == $3 )
	            {
	            $userdata->set_x($1, $id);
	            $userdata->set_y($4, $id);
	            $userdata->set_scl($2, $id);
                send_x_y_scl();
	            }
	          if( $stalk{antistalkon} == 1 && $stalk{antistalkid} == $3 )
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
	            { die; print_output("room $2 persons $1\n"); }
	          }
	     elsif( @read[0] =~ /<\/ROOM>/ )
	          {}
	     elsif( @read[0] =~ /<\/COUNT>/ )
	          {}
	     elsif( @read[0] =~ /<COUNT \/>/ )
	          {}
	     elsif( @read[0] =~ /<COUNT c="(.+?)" n="(.+?)" \/>/ )
	          { $outputfield->Append( "room $2 persons $1\n" ); }
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
	          if ( $stalk{on} == 1 )
	             {
	             if( $stalk{id} == $id )
	               {
	               my($line) = $comment;
	               $line = decode("cp932", $line);
	               $line = encode("utf8",  $line);
	               if( $select->can_write() )
	                 { print $remote "<COM cmt=\"$line\" />\0"; }
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
	          elsif( $line =~ /<\w{4,5} r="(\d{1,3})" name="(.*?)" id="(\d{1,3})"(.+?)ihash="(.{10})" \w{4,6}="(.*?)" g="(\d{1,3})" type="(.*?)" b="(\d{1,3})" y="(.*?)" x="(.*?)" scl="(.+?)" \/>/ )
	               { save_and_print_user_data("enter", $3, $2, $8, $6, $4, $5, $1, $7, $9, $11, $10, $12); }
	          else { print_output("$line\n"); }
	          }
         else { print_output("$read[0]\n"); }
	     shift @read;
	     }
	}

$window      = Win32::GUI::Window->new( -name => "Window", -title => "Monachat", -height => 320, -width => 620 );
#$tab        = $window->AddTabStrip( -name => "Tab", -height => 320, -width => 620, -left => 0, -top => 0 );
#$tab1       = $tab->InsertItem( -text => 1 );
$inputfield  = $window->AddTextfield  ( -name => "Inputfield", -height => 30, -width => 420, -left => 100,
                                        -top => 240 );
$outputfield = $window->AddTextfield  ( -height => 180, -width => 520, -left => 50, -top => 40, -multiline => 1,
                                        -vscroll => 1, -autovscroll => 1 );
#$tab  = $window->AddTabStrip( -name => "Tab", -height => 320, -width => 620, -left => 0, -top => 0 );
#$tab1 = $tab->InsertItem( -text => 1 );
#$tab2 = $tab->InsertItem( -text => 2 );
#$tab3 = $tab->InsertItem( -text => 3 );
$searchwindow      = Win32::GUI::Window->new    ( -name => "SearchWindow", -title => "Search Results",
                                                  -height => 220, -width => 270 );
$searchoutputfield = $searchwindow->AddTextfield( -height => 120, -width => 220, -left => 20, -top => 20,
                                                  -multiline => 1, -vscroll => 1 );
$searchprint       = $searchwindow->AddButton   ( -name => "SearchPrintButton", -text => "Print", -height => 30,
                                                  -width => 60, -left => 50, -top => 150 );
$searchupdate      = $searchwindow->AddButton   ( -name => "SearchUpdateButton", -text => "Update", -height => 30,
                                                  -width => 60, -left => 150, -top => 150 );
$window->Center();
$window->Show();

sub get_argument
    {
    while( @ARGV[0] )
         {
         if   ( @ARGV[0] eq ("-proxy" or "-p") )
              { $proxy{on} = 1; }
         elsif( @ARGV[0] eq ("-timeout" or "-t") )
              { shift(@ARGV); $proxy{timeout} = @ARGV[0]; }
         elsif( @ARGV[0] eq "-debug" )
	          { $proxy{debug} = 1; }
		 elsif( @ARGV[0] eq "-skip" )
		      {
			  if  ( @ARGV[1] =~ /\d/ )
			      { $proxy{skip} = shift; }
			  else{ $proxy{skip} = 1; }
			  }
         elsif( @ARGV[0] eq "-ip" )
	          { shift(@ARGV); $socketdata{address} = @ARGV[0]; }
         elsif( @ARGV[0] eq "-port" )
	          { shift(@ARGV); $socketdata{port} = @ARGV[0]; }
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
	          shift;
              if   ( @ARGV[0] eq "iriguchi" )
                   { $argument{room1} = "MONA8094";    $socketdata{port} = 9095; shift(@ARGV); }
              elsif( @ARGV[0] eq "atochi" )
                   { $argument{room1} = "ANIKI8088";   $socketdata{port} = 9083; shift(@ARGV); }
              elsif( @ARGV[0] eq "ooheya" )
                   { $argument{room1} = "MONABIG8093"; $socketdata{port} = 9093; shift(@ARGV); }
              elsif( @ARGV[0] eq "chibichato" )
                   { $argument{room1} = "ANIMAL8098";  $socketdata{port} = 9090; shift(@ARGV); }
              elsif( @ARGV[0] eq "moa" )
                   { $argument{room1} = "MOA8088";     $socketdata{port} = 9092; shift(@ARGV); }
              elsif( @ARGV[0] eq "chiikibetsu" )
                   { $argument{room1} = "AREA8089";    $socketdata{port} = 9095; shift(@ARGV); }
              elsif( @ARGV[0] eq "wadaibetsu" )
                   { $argument{room1} = "ROOM8089";    $socketdata{port} = 9090; shift(@ARGV); }
              elsif( @ARGV[0] eq "tateyokoheya" )
                   { $argument{room1} = "MOXY8097";    $socketdata{port} = 9093; shift(@ARGV); }
              elsif( @ARGV[0] eq "cool" )
                   { $argument{room1} = "COOL8099";    $socketdata{port} = 9090; shift(@ARGV); }
              elsif( @ARGV[0] eq "kanpu" )
                   { $argument{room1} = "kanpu8000";   $socketdata{port} = 9094; shift(@ARGV); }
              elsif( @ARGV[0] eq "monafb" )
                   { $argument{room1} = "MOFB8000";    $socketdata{port} = 9090; shift(@ARGV); }
              $argument{room2} = @ARGV[0];
              }
         shift(@ARGV);
         }
     }

my(%argument)   :shared;
my(%encrypt)    :shared;
my(%socketdata) :shared;
my(%trip)       :shared;
my(@proxyaddr)  :shared;
my(@proxyport)  :shared;

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
$userdata   = Userdata->new_user_data();
my(%stalk)      :shared  = ( on => 0, id => 0, ihash => 0 );
my(%ignore)     :shared  = ( antiignoreon => 0, antiignoreall => 0 );
my(%socketdata) :shared  = ( address => $socketdata{address}||"153.122.46.192",
                             port    => $socketdata{port}||9095 );
my(%proxy)      :shared  = ( on           => $proxy{on}||0,
	                         timeout      => $proxy{timeout}||2,
	                         debug        => $proxy{debug}||1 );
login("firsttime");

$pingthread       = threads->create(\&ping);
$readsocketthread = threads->create(\&read_socket);

Win32::GUI->Dialog();
