use IO::Socket;
use Socket;
use threads;
use threads::shared qw/share/;
use Encode qw/encode decode/;
use Win32::GUI;
use Win32::GUI::Constants;
use IO::Select;
use IO::Socket::Socks;
use LWP::Simple /get/;

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
	 { commands($readtext); }
      else
	 {
	 if( $encrypt{on} == 1 )
	   {
	   if( $encrypt{reverse} == 1 )
	     { $readtext = reverse($readtext); }
	   }
	 #$outputfield->Append("$readtext\n");
	 $readtext = decode("cp932", $readtext) or die "Couldn't decode: $!\n";
	 $readtext = encode("utf8",  $readtext) or die "Couldn't encode: $!\n";
	 #$outputfield->Append("<COM cmt=\"$readtext\" />\n");
	 if( $select->can_write() )
	   { print $remote "<COM cmt=\"$readtext\" />\0"; }
	 }
      $inputfield->SelectAll();
      $inputfield->ReplaceSel( "" );
      }
   }

sub commands
    {
    my($command) = shift;
    if   ( $command =~ /\/login/ )
	 { login(); }
    elsif( $command =~ /\/relogin\s*(.*)/ )
	 {
	 if   ( $1 =~ /room/ )
	      { enterroom("reenter"); }
	 elsif( $1 =~ /proxy\s*(.*)/ )
	      {
	      shift @proxyaddr;
	      shift @proxyport;
	      if( $1 =~ /(\d\.*\d*)/ )
	        { $proxy{timeout} = $1; }
	      if( $1 =~ /getlist/ )
	        { getproxylist(); }
	      if( $1 !~ /ghost/ )
	        {
	        if( $select->can_write() )
	          { print $remote "<EXIT />\0"; print $remote "<NOP />\0"; print $remote "<NOP />\0"; }
	        }
	      login("relogin");
	      }
	else { login("relogin"); }
	}
   elsif( $command =~ /\/disconnect\s*(\d*)/ )
	{
	if( $select->can_write() )
	  { print $remote "<EXIT />\0"; print $remote "<NOP />\0"; print $remote "<NOP />\0"; }
	if   ( $1 )
	     { $endloop = 1; sleep($1); login(); }
	else { $endloop = 1; }
	}
   elsif( $command =~ /\/name (.+)/ )
	{
	my($name) = $1;
	$name = decode("cp932", $name);
	$name = encode("utf8", $name);
	$logindata{name} = $name;
	enterroom("reenter");
	}
   elsif( $command =~ /\/character (.+)/ )
	{
	$logindata{character} = $1;
	enterroom("reenter");
	}
   elsif( $command =~ /\/stat (.+)/ )
	{
	my($status) = $1;
	$status = decode("cp932", $status);
	$status = encode("utf8", $status);
	$logindata{stat} = $status;
	print $remote "<SET stat=\"$logindata{stat}\" />\0";
	}
   elsif( $command =~ /\/room (.+)/ )
	{
	my($room) = $1;
	$room = decode("cp932", $room);
	$room = encode("utf8", $room);
	$logindata{room2} = $room;
	enterroom("reenter");
	}
   elsif( $command =~ /\/rgb (\d{1,3}) (\d{1,3}) (\d{1,3})/ )
	{
	$logindata{r} = $1;
	$logindata{g} = $2;
	$logindata{b} = $3;
	enterroom("enterroom");
	}
   elsif( $command =~ /\/x (.+)/ )
	{
	$logindata{xposition} = $1;
	if( $select->can_write() )
	  { print $remote "<SET x=\"$logindata{xposition}\" scl=\"$logindata{scl}\" y=\"$logindata{yposition}\" />\0"; }
	}
   elsif( $command =~ /\/y (.+)/ )
	{
	$logindata{yposition} = $1;
	if( $select->can_write() )
	  { print $remote "<SET x=\"$logindata{xposition}\" scl=\"$logindata{scl}\" y=\"$logindata{yposition}\" />\0"; }
	}
   elsif( $command =~ /\/move (x.+)|move (y.+)|move (x.+) (y.+)|move (y.+) (x.+)/ )
	{
	if( $1 =~ /x(.+)/ or $2 =~ /x(.+)/ ) { $logindata{xposition} = $1; }
	if( $1 =~ /y(.+)/ or $2 =~ /y(.+)/ ) { $logindata{yposition} = $1; }
	if( $select->can_write() )
	  { print $remote "<SET x=\"$logindata{xposition}\" scl=\"$logindata{scl}\" y=\"$logindata{yposition}\" />\0"; }
	}
   elsif( $command =~ /\/scl/ )
	{
	if   ( $logindata{scl} ==  "100" ) { $logindata{scl} = "-100" }
	elsif( $logindata{scl} == "-100" ) { $logindata{scl} =  "100" }
	if( $select->can_write() )
	  { print $remote "<SET x=\"$logindata{xposition}\" scl=\"$logindata{scl}\" y=\"$logindata{yposition}\" />\0"; }
	}
   elsif( $command =~ /\/attrib/ )
	{
	if   ( $logindata{attrib} eq  "no" ) { $logindata{attrib} = "yes" }
	elsif( $logindata{attrib} eq "yes" ) { $logindata{attrib} =  "no" }
	if( $select->can_write() )
	  { print $remote "<EXIT no=\"$logindata{id}\" />\0"; }
	login();
	}
   elsif( $command =~ /\/ignore (\d{1,3})/ )
	{
	my($ihash) = "ihash$1";
	if( $select->can_write() )
	  { print $remote "<IG ihash=\"$usersdata{$ihash}\" />\0"; }
	}
   elsif( $command =~ /\/search\s*(.*)/ )
	{
	$search{on} = 1;
	$logindata{currentroom} = $logindata{room2};
	$logindata{room2} = "main";
	if( $1 =~ /print/ )
	  { $search{print} = 1; }
	if( $1 =~ /user (.+)/ )
	  { $search{user} = $1; }
	if( $1 =~ /users/ )
	  { $search{room2} = 1; }
	enterroom("reenter");
	}
   elsif( $command =~ /\/stalk (.+)/ )
	{
	if   ( $stalk{on} == 0 ) { $stalk{on} = 1; $outputfield->Append( "stalk on\n" );  }
	elsif( $stalk{on} == 1 ) { $stalk{on} = 0; $outputfield->Append( "stalk off\n" ); }
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
	          $logindata{xposition} = $usersdata{$x};
	          $logindata{yposition} = $usersdata{$y};
	          $logindata{scl}       = $usersdata{$scl};
	          if( $select->can_write() )
	            { print $remote "<SET x=\"$usersdata{$x}\" scl=\"$usersdata{$scl}\" y=\"$usersdata{$y}\" />\0"; }
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
	my($name, $stat, $type, $r, $g, $b, $x, $y, $scl) =
	  ("name$1", "status$1", "type$1", "r$1", "g$1", "b$1", "x$1", "y$1", "scl$1");
	my($copyname, $copystat);
	$copyname = decode( "cp932", $usersdata{$name} );
	$copyname = encode( "utf8",  $copyname );
	$copystat = decode( "cp932", $usersdata{$stat} );
	$copystat = encode( "utf8",  $copystat );
	$logindata{name}      = $copyname;
	$logindata{status}    = $copystat;
	$logindata{character} = $usersdata{$type};
	$logindata{r}         = $usersdata{$r};
	$logindata{g}         = $usersdata{$g};
	$logindata{b}         = $usersdata{$b};
	$logindata{xposition} = $usersdata{$x};
	$logindata{yposition} = $usersdata{$y};
	$logindata{scl}       = $usersdata{$scl};
	enterroom("reenter");
	}
   elsif( $command =~ /\/default/ )
	{
	$logindata{name}      = $default{name};
	$logindata{status}    = $default{status};
	$logindata{character} = $default{character};
	$logindata{trip}      = $default{$trip}||"";
	$logindata{r}         = $default{r};
	$logindata{g}         = $default{g};
	$logindata{b}         = $default{b};
	$logindata{xposition} = $default{xposition};
	$logindata{yposition} = $default{yposition};
	$logindata{scl}       = $default{scl};
	$search{on}           = 0;
	$stalk{on}            = 0;
	$stalk{nomove}        = 0;
	$encrypt{on}          = 0;
	$encrypt{reverse}     = 0;
	enterroom("reenter");
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
	          $outputfield->Append( "proxy on\n" );
	          }
	     elsif( $proxy{on} == 1 and $1 !~ /on/ )
	          {
	          $proxy{on} = 0;
	          $outputfield->Append( "proxy off\n" );
	          }
	     if   ( $select->can_write() )
	          { print $remote "<EXIT />\0"; print $remote "<NOP />\0"; print $remote "<NOP />\0"; }
	     login("relogin");
	     }
	elsif( $1 =~ /timeout\s*(\d\.*\d*)/ )
	     { $proxy{timeout} = $1; }
	elsif( $1 =~ /lock/ )
	     {
	     $outputfield->Append( "proxy locked\n" );
	     $proxy{lockaddr} = @proxyaddr[0];
	     $proxy{lockport} = @proxyport[0];
	     }
	elsif( $1 =~ /unlock/ )
	     {
	     $outputfield->Append( "proxy unlocked\n" );
	     $proxy{lockaddr} = undef;
	     $proxy{lockport} = undef;
	     }
	elsif( $1 =~ /save/ )
	     {
	     $outputfield->Append( "proxy saved\n" );
	     open( "PROXIES", '>', "proxies.txt" );
	     print PROXIES "@proxyaddr[0] @proxyport[0]\n";
	     close(PROXIES);
	     }
	elsif( $1 =~ /usereliables/ )
	     {
	     if ( $proxy{usereliables} = 0 )
	        {
	        $outputfield->Append( "using reliable proxies\n" );
	        $proxy{usereliables} = 1;
	        getreliables();
	        }
	     else
	        {
	        $outputfield->Append( "stopping using reliable proxies\n" );
	        $proxy{usereliables} = 0;
	        }
	     if( $select->can_write() )
	       { print $remote "<EXIT />\0"; print $remote "<NOP />\0"; print $remote "<NOP />\0"; }
	     login("relogin");
	     }
	}
   elsif( $command =~ /\/clear (.+)/ )
	{
	if   ( $1 =~ /screen/ )
	     {
	     $outputfield->SelectAll();
	     $outputfield->ReplaceSel( "" );
	     }
	elsif( $1 =~ /usersdata/ )
	     {
	     my($keys);
	     foreach $keys ( keys %usersdata )
	                   { $usersdata{$keys} = undef; }
	     }
	}
   elsif( $command =~ /\/newinstance\s*(.*)/ )
	{
	if ( $1 =~ /here\s*(.*)\s*(.*)/ )
	   {
	   my($newinstancecounter) = $1||1;
	   my($seconds) = $2||10;
	   for( my($counter) = 0; $counter < $newinstancecounter; $counter++ )
	      {
	      system("start socket.pl -proxy -timeout 1 -room $logindata{room2}");
	      sleep($seconds);
	      }
	   }
	else { system("start socket.pl -proxy -timeout 1"); }
	}
   elsif( $command =~ /\/invisible/ )
	{
	$logindata{name}      = undef;
	$logindata{character} = undef;
	$logindata{status}    = undef;
	$logindata{trip}      = undef;
	$logindata{xposition} = undef;
	$logindata{yposition} = undef;
	enterroom("reenter");
	}
   elsif( $command =~ /\/antiignore\s*(\d*)/ )
	{
	my($antiignoreid) = "antiignore$1";
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

sub login
    {
    my($option) = shift;
    if ( $option eq "relogin" )
       {
       $endloop = 1;
       select(undef, undef, undef, 0.2);
       #$endloop = 0;
       }
    if ( $proxy{on} == 1 )
       {
       $proxy{retry} = 1;
       while( $proxy{retry} == 1 )
	    {
	    $proxy{retry} = 0;
	    if( $proxy{usereliables} == 1 and !@reliableaddr[0] )
	      {
	      $proxy{usereliables} = 0;
	      $outputfield->Append( "There are no more reliable proxies\n" );
	      }
	    if( !@proxyaddr[0] )
	      { getproxylist(); }
	    $remote = IO::Socket::Socks->new( ProxyAddr   => $proxy{lockaddr}||"@reliableaddr[0]"||"@proxyaddr[0]",
	                                      ProxyPort   => $proxy{lockport}||"@reliableport[0]"||"@proxyport[0]",
	                                      ConnectAddr => $socketdata{address}||"153.122.46.192",
	                                      ConnectPort => $socketdata{port}||"9095",
	                                      SocksDebug  => $proxy{debug}||1,
	                                      Timeout     => $proxy{timeout}||2 )
	                                      or warn "$SOCKS_ERROR\n" and $proxy{retry} = 1;
	    if( $proxy{usereliables} == 1 )
	      { shift @reliableaddr; shift @reliableport; }
	    if( $proxy{skip} > 0 )
	      { $proxy{retry} = 1; $proxy{skip}--; }
	    if( $proxy{retry} == 1 )
	      { shift @proxyaddr; shift @proxyport; }
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
	enterroom();
	if( $option eq "relogin" )
	  {
	  $endloop = 0;
	  $readsocketthread = threads->create(\&readsocket);
	  $pingthread       = threads->create(\&ping, "20");
	  }
	}

sub enterroom
    {
    my($option) = shift;
    if( $option eq "reenter" )
      {
      if( $select->can_write() )
	{ print $remote "<EXIT no=\"$logindata{id}\" \/>\0"; }
	}
      if( $select->can_write() )
	{
	if ( $logindata{room2} eq "main" )
	   { print $remote "<ENTER room=\"$logindata{room1}\" name=\"$logindata{name}\" attrib=\"$logindata{attrib}\" />\0"; }
	else
	   { print $remote "<ENTER room=\"$logindata{room1}/$logindata{room2}\" umax=\"0\" type=\"$logindata{character}\" name=\"$logindata{name}\" x=\"$logindata{xposition}\" y=\"$logindata{yposition}\" r=\"$logindata{r}\" g=\"$logindata{g}\" b=\"$logindata{b}\" scl=\"$logindata{scl}\" status=\"$logindata{status}\" />\0"; }
        }
    }

sub getproxylist
    {
    $proxylist = get("http://www.socks-proxy.net");
    my($counter) = 0;
    while( $proxylist =~ /<td>(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})<\/td><td>(\d{4,5})<\/td><td>(US|GB|CA|AU|JP)<\/td><td>(.+?)<\/td>/g )
         {
	 @proxyaddr[$counter] = "$1";
	 @proxyport[$counter] = "$2";
	 $counter++;
	 }
    }

sub getreliables
    {
    my($line, $counter) = 0;
    open( "PROXIES", '<', "proxies.txt" );
    while( $line = <PROXIES> )
	 {
	 if( $line =~ /(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}) (\d{4,5})/ )
	   {
	   @reliableaddr[$counter] = $1;
	   @reliableport[$counter] = $2;
	   $counter++;
	   }
	 }
	close(PROXIES);
    }

sub ping
    {
    my($seconds) = shift;
    while( $endloop == 0 )
	 {
	 for( my($counter) = 0; $counter <= 100 and $endloop == 0; $counter++ )
	    {
	    select(undef, undef, undef, 0.2);
	    if( $counter == 100 and $endloop == 0 )
	      {
	      if( $select->can_write() )
	        { print $remote "<NOP />\0"; }
	      }
	    }
	 }
    }

sub readsocket
    {
    while( $endloop == 0 )
	 {
	 if( $select->can_read(0.2) )
	   {
	   sysread($remote, $read, 20000);
	   $read = decode("utf8",  $read) or warn "Couldn't decode: $!" and select(undef, undef, undef, 0.5);
	   $read = encode("cp932", $read) or warn "Couldn't encode: $!" and select(undef, undef, undef, 0.5);
	   @read = split(/>/, $read);
	   for( my ($counter) = 0; @read[$counter + 1]; $counter++ )
	      {
	      if( !( @read[$counter] =~ /\+connect|Connection timeout\.\.>/ ) )
	        { @read[$counter] = @read[$counter] . ">"; }
	      }
	   printread(@read);
	   }
	 else { print $counter++, "\n"; }
	 }
    }

sub saveandprintusersdata
    {
    my($mode) = shift;
    my($userid) = shift;
    my($name, $id, $stat, $type, $trip, $ihash, $r, $g, $b, $x, $y, $scl) =
      ("name$userid", "id$userid", "stat$userid", "type$userid", "trip$userid", "ihash$userid",
       "r$userid", "g$userid", "b$userid", "x$userid", "y$userid", "scl$userid");
    my($tripid, $triptrip, $tripihash) = (@_[1], @_[4], @_[5]);
    $trip{$triptrip}  = $tripid;
    $trip{$tripihash} = $tripid;
    $usersdata{$name}  = shift;
    $usersdata{$id}    = shift;
    $usersdata{$stat}  = shift;
    $usersdata{$type}  = shift;
    $usersdata{$trip}  = shift;
    $usersdata{$ihash} = shift;
    $usersdata{$r}     = shift;
    $usersdata{$g}     = shift;
    $usersdata{$b}     = shift;
    $usersdata{$x}     = shift;
    $usersdata{$y}     = shift;
    $usersdata{$scl}   = shift;
    if   ( $stalk{on} == 1 )
	 {
	 if( $stalk{ihash} == $usersdata{$ihash} )
	   { $stalk{id} = $usersdata{$id}; }
	 }
    if   ( $stalk{antistalkon} == 1 )
	 {
	 if( $stalk{antistalkihash} == $usersdata{$ihash} )
	   { $stalk{antistalkid} = $usersdata{$id}; }
	 }
    if   ( $usersdata{$scl} ==  "100" ) { $scl = "right"; }
    elsif( $usersdata{$scl} == "-100" ) { $scl = "left";  }
    if   ( $usersdata{$trip} =~ /trip="(.+?)"/ )
	 {
	 $usersdata{$trip} = $1;
	 $outputfield->Append( "$usersdata{$name} $usersdata{$trip} $usersdata{$ihash} ($usersdata{$id}) " );
	 $outputfield->Append( "$usersdata{$stat} $usersdata{$type} x$usersdata{$x} $scl" );
	 }
    else {
	 $outputfield->Append( "$usersdata{$name} $usersdata{$ihash} ($usersdata{$id}) " );
	 $outputfield->Append( "$usersdata{$stat} $usersdata{$type} x$usersdata{$x} $scl" );
	 }
    if   ( $mode eq "enter" )
	 { $outputfield->Append( " has logged in\n" ); }
    elsif( $mode eq "user" )
	 { $outputfield->Append( "\n" ); }
    }

sub printread
    {
    my(@read) = @_;
    while( @read )
	 {
	 if ( $search{on} == 1 )
	    {
	    my($read);
	    my($counter) = 0;
	    my($keys);
	    if( $select->can_read() )
	      {
	      sleep(1);
	      sysread($remote, $read, 20000);
	      while( $read =~ /<ROOM c="(.+?)" n="(.+?)" \/>/g )
	           {
	           my($room) = $2;
	           my($number) = $1;
	           if( $1 != 0 )
	             {
	             $room = decode("utf8", $room);
	             $room = encode("cp932", $room);
	             $number = decode("utf8", $number);
	             $number = encode("cp932", $number);
	             $roomdata{$room} = $number;
	             }
	           }
	      }
	    if( $search{room2} == 1 )
	      {
	      foreach $keys ( sort( keys %roomdata ) )
	                    {
	                    $logindata{room2} = $keys;
	                    enterroom("reenter");
	                    if( $select->can_read() )
	                      {
	                      sleep(2);
	                      sysread($remote, $read, 20000);
	                      $read = decode("utf8", $read);
	                      $read = encode("cp932", $read);
	                      $outputfield->Append( "\n" );
	                      sleep(2);
	                      $outputfield->Append( "$read\n" );
	                      while( $read =~ /<USER r="(\d{1,3})" name="(.*?)" id="(\d{1,3})"(.+?)ihash="(.{10})" \w{4,6}="(.*?)" g="(\d{1,3})" type="(.*?)" b="(\d{1,3})" y="(.*?)" x="(.*?)" scl="(.+?)" \/>/g )
	                           {
	                           my($name, $trip, $ihash) = ($2, $4, $5);
	                           saveandprintusersdata("user", $3, $2, $3, $6, $8, $4, $5, $1, $7, $9, $10, $11, $12);
	                           if   ( $trip =~ /trip="(.+?)"/ ) { $trip = " $1 "; }
	                           else { $trip = " "; }
	                           if   ( !$roomdata{$keys} ) { $roomdata{$keys} = "$name$trip$ihash"; }
	                           else { $roomdata{$keys} = $roomdata{$keys} . ", " . "$name$trip$ihash"; }
	                           }
	                      }
	                   }
	      }
	      $logindata{room2} = $logindata{currentroom};
	      enterroom("reenter");
	      my($roomswithusers) = scalar keys %roomdata;
	      if ( $search{print} == 1 )
	         { print $remote "<COM cmt=\"There are $roomswithusers rooms with people:\" />\0"; }
	      else
	         { $outputfield->Append( "There are $roomswithusers rooms with people:\n" ); }
	      foreach $keys ( sort( keys %roomdata ) )
	                    {
	                    if ( $search{print} == 1 )
	                       {
	                       $keys = decode("cp932", $keys);
	                       $keys = encode("utf8", $keys);
                               $roomdata{$keys} = decode("cp932", $roomdata{$keys});
	                       $roomdata{$keys} = encode("utf8", $roomdata{$keys});
	                       print $remote "<COM cmt=\"room $keys: $roomdata{$keys}\" />\0";
	                       $counter++;
	                       if( $counter < $roomswithusers )
	                         { select(undef, undef, undef, 0.8); }
	                       }
	                    else
	                       {
	                       $outputfield->Append( "room $keys: $roomdata{$keys}" );
	                       $counter++;
	                       if ( $counter < $roomswithusers )
	                          { $outputfield->Append( ", " ); }
	                       else
	                          { $outputfield->Append( "\n" ); }
	                       }
	                    }
	      foreach $keys ( keys %roomdata )
	                    { $roomdata{$keys} = undef; }
              $search{on}       = 0;
	      $search{print}    = 0;
	      $search{room2}    = 0;
	      }
	 elsif( @read[0] =~ /\+connect id=(\d{1,3})/ )
	      {}
	 elsif( @read[0] =~ /<CONNECT id="(.+?)" \/>/ )
	      {
	      $logindata{id} = $1;
	      $outputfield->Append( "Logged in, id=$logindata{id}\n\n" );
	      }
	 elsif( @read[0] =~ /<ROOM>/ )
	      {}
	 #    { $outputfield->Append( "Users in this room:\n" ); }
	 elsif( @read[0] =~ /<ROOM \/>/ )
	      {}
	 elsif( @read[0] =~ /<\w{4,5} r="(\d{1,3})" name="(.*?)" id="(\d{1,3})"(.+?)ihash="(.{10})".+\w{4,6}="(.*?)" g="(\d{1,3})" type="(.*?)" b="(\d{1,3})" y="(.*?)" x="(.*?)" scl="(.+?)" \/>/ )
	      {
	      #my($option) = $1;
	      #if   ( $option =~ /USER/  )  { $option = "user";  }
	      #elsif( $option =~ /ENTER/ )  { $option = "enter"; }
	      #$outputfield->Append("$1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13\n");
	      #saveandprintusersdata("$option", $4, $3, $4, $7, $9, $5, $6, $2, $8, $10, $11, $12, $13);
	      saveandprintusersdata("enter", $3, $2, $3, $6, $8, $4, $5, $1, $7, $9, $11, $10, $12);
	      }
	 elsif( @read[0] =~ /<USER ihash="(.+?)" name="(.*?)" id="(.+?)" \/>/ )
	      { $outputfield->Append( "User $2 $1 ($3) has logged in\n" ); }
	 elsif( @read[0] =~ /<ENTER id="(.+?)" \/>/ )
	      { $outputfield->Append( "User with id $1 entered this room\n" ); }
	 elsif( @read[0] =~ /<UINFO name="(.*?)" id="(\d{1,3})" \/>/ )
	      {
	      if( $logindata{room2} eq "main" )
	        { $outputfield->Append( "$1 id=$2\n" ); }
	      }
         elsif( @read[0] =~ /<SET stat="(.*?)" id="(.+?)" \/>/ )
	      {
	      my($name, $id, $trip, $ihash, $stat) = ("name$2", "id$2", "trip$2", "ihash$2", "stat$2");
	      $usersdata{$stat} = $1;
	      $outputfield->Append( "$usersdata{$name} $usersdata{$ihash} ($usersdata{$id}) changed stat to $usersdata{$stat}\n" );
	      }
	 elsif( @read[0] =~ /<SET x="(.*?)" scl="(.+?)" id="(.+?)" y="(.*?)" \/>/ )
	      {
	      my($name, $id, $trip, $ihash, $x, $y, $scl) =
	        ("name$3", "id$3", "trip$3", "ihash$3", "x$3", "y$3", "scl$3");
	      if( $usersdata{$x} != $1 )
	        {
	        $usersdata{$x} = $1;
	        $outputfield->Append( "$usersdata{$name} moved to x $usersdata{$x}\n" );
	        }
	   if( $usersdata{$y} != $4 )
	     {
	     $usersdata{$y} = $4;
	     $outputfield->Append( "$usersdata{$name} moved to y $usersdata{$y}\n" );
	     }
	   if( $usersdata{$scl} != $2 )
	     {
	     $usersdata{$scl} = $2;
	     if   ( $usersdata{$scl} ==  "100" ) { $scl = "right"; }
	     elsif( $usersdata{$scl} == "-100" ) { $scl =  "left"; }
	     $outputfield->Append( "$usersdata{$name} moved to $scl\n" );
	     }
	   if( $stalk{on} == 1 and $stalk{nomove} == 0 and $stalk{id} == $3 )
	     {
	     $logindata{xposition} = $1;
	     $logindata{yposition} = $4;
	     $logindata{scl}       = $2;
	     if( $select->can_write() )
	       { print $remote "<SET x=\"$logindata{xposition}\" scl=\"$logindata{scl}\" y=\"$logindata{yposition}\" />\0"; }
	     }
	   if( $stalk{antistalkon} == 1 and $stalk{antistalkid} == $3 )
             {
	     if( $logindata{xposition} - $1 < 40 and $logindata{xposition} - $1 > -40 )
	       { $logindata{xposition} = 680-$1+40; }
	     if( $logindata{yposition} - $4 < 40 and $logindata{yposition} - $4 > -40 )
	       { $logindata{yposition} = 320-$4+240; }
	     if( $select->can_write() )
	       { print $remote "<SET x=\"$logindata{xposition}\" scl=\"$logindata{scl}\" y=\"$logindata{yposition}\" />\0"; }
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
	      { $outputfield->Append( "You exited the room\n" ); }
	 elsif( @read[0] =~ /<EXIT id="(.+?)" \/>/ )
	      {
	      my ($name, $id, $trip, $ihash) = ("name$1", "id$1", "trip$1", "ihash$1");
	      $outputfield->Append( "$usersdata{$name} $usersdata{$ihash} ($usersdata{$id}) exited this room\n" );
	      }
	 elsif( @read[0] =~ /<COUNT>/ )
	      {
	      $outputfield->Append( "Rooms:\n" );
	      while( !( @read[0] =~ /<\/COUNT>/ ) )
	           {
	           shift @read;
	           if( @read[0] =~ /<ROOM c="(.+?)" n="(.+?)" \/>/ and $logindata{room2} eq "main" )
	             { $outputfield->Append( "room $2 persons $1\n" ); }
	           }
	      }
	 elsif( @read[0] =~ /<ROOM c="(.+?)" n="(.+?)" \/>/ )
	      {
	      if( $1 != "0" )
	        { $outputfield->Append( "room $2 persons $1\n" ); }
	      }
	 elsif( @read[0] =~ /<\/ROOM>/ )
	      {}
	 elsif( @read[0] =~ /<\/COUNT>/ )
	      {}
	 elsif( @read[0] =~ /<COUNT \/>/ )
	      {}
	 elsif( @read[0] =~ /<COUNT c="(.+?)" n="(.+?)" \/>/ )
	      { $outputfield->Append( "room $2 persons $1\n" ); }
	 elsif( @read[0] =~ /<COM cmt="(.+?)" id="(.+?)" cnt="(.+?)" \/>/ )
	      {
	      my($name, $id, $trip, $ihash) = ("name$2", "id$2", "trip$2", "ihash$2");
	      if ( $usersdata{$trip} )
	         { $outputfield->Append( "$usersdata{$name} $usersdata{$trip} $usersdata{$ihash} ($usersdata{$id}): $1\n" ); }
	      else
	         { $outputfield->Append( "$usersdata{$name} $usersdata{$ihash} ($usersdata{$id}): $1\n" ); }
	      if ( $stalk{on} == 1 )
	         {
	         if( $stalk{id} == $2 )
	           {
	           my($line) = $1;
	           $line = decode("cp932", $line);
	           $line = encode("utf8",  $line);
	           if( $select->can_write() )
	             { print $remote "<COM cmt=\"$line\" />\0"; }
	           }
	         }
	      }
	 elsif( @read[0] =~ /<COM cmt="(.+?)" cnt="(.+?)" id="(.+?)" \/>/ )
	      {
	      my($name, $id, $trip, $ihash) = ("name$3", "id$3", "trip$3", "ihash$3");
	      if ( $usersdata{$trip} )
	         { $outputfield->Append( "$usersdata{$name} $usersdata{$trip} $usersdata{$ihash} ($usersdata{$id}): $1\n" ); }
	      else
	         { $outputfield->Append( "$usersdata{$name} $usersdata{$ihash} ($usersdata{$id}): $1\n" ); }
	      if ( $stalk{on} == 1 )
	         {
	         if( $stalk{id} == $3 )
	           {
	           my($line) = $1;
	           $line = decode("cp932", $line);
	           $line = encode("utf8", $line);
	           if( $select->can_write() )
	             { print $remote "<COM cmt=\"$line\" />\0"; }
	           }
	         }
	      }
	 elsif( @read[0] =~ /<COM cmt="(.+?)" id="(.+?)" \/>/ )
	      {
	      my($name, $id, $trip, $ihash) = ("name$2", "id$2", "trip$2", "ihash$2");
	      if ( $usersdata{$trip} )
	         { $outputfield->Append( "$usersdata{$name} $usersdata{$trip} $usersdata{$ihash} ($usersdata{$id}): $1\n" ); }
	      else
	         { $outputfield->Append( "$usersdata{$name} $usersdata{$ihash} ($usersdata{$id}): $1\n" ); }
	      if ( $stalk{on} == 1 )
	         {
	         if( $stalk{id} == $2 )
	           {
	           my($line) = $1;
	           $line = decode("cp932", $line);
	           $line = encode("utf8",  $line);
	           if( $select->can_write() )
	             { print $remote "<COM cmt=\"$line\" />\0"; }
	           }
	         }
	      }
	 elsif( @read[0] =~ /Connection timeout\.\./ )
	      {
	      $outputfield->Append( "Connection timeout..\n" );
	      login();
	      }
	 elsif( @read[0] =~ /^<R|^<USER/ )
	      {
	      $firstline = @read[0];
	      $firstlinecounter = 1;
	      }
	 elsif( $firstlinecounter == 1 )
	      {
	      my($line) = $firstline . @read[0];
	      if   ( $line !~ />$/ )
	           { $line = $line . ">"; }
	      if   ( $line =~ /<ROOM c="(.+?)" n="(.+?)" \/>/ )
	           {
	           if( $1 != 0 )
	             { $outputfield->Append( "room $2 persons $1\n" ); }
	           }
	      elsif( $line =~ /<\w{4,5} r="(\d{1,3})" name="(.*?)" id="(\d{1,3})"(.+?)ihash="(.{10})" \w{4,6}="(.*?)" g="(\d{1,3})" type="(.*?)" b="(\d{1,3})" y="(.*?)" x="(.*?)" scl="(.+?)" \/>/ )
	           { saveandprintusersdata("enter", $3, $2, $3, $6, $8, $4, $5, $1, $7, $9, $10, $11, $12); }
	      else { $outputfield->Append( "$line\n" ); }
	      $firstlinecounter = 0;
	      }
	 else { $outputfield->Append( "@read[0]\n" ); }
	 shift @read;
	 }
	}

$window      = Win32::GUI::Window->new( -name => "Window", -title => "Monachat", -height => 320, -width => 620 );
#$tab = $window->AddTabStrip( -name => "Tab", -height => 320, -width => 620, -left => 0, -top => 0 );
#$tab1 = $tab->InsertItem( -text => 1 );
$inputfield  = $window->AddTextfield  ( -name => "Inputfield", -height => 30, -width => 420, -left => 100,
                                        -top => 240 );
$outputfield = $window->AddTextfield  ( -height => 180, -width => 520, -left => 50, -top => 40, -multiline => 1,
                                        -vscroll => 1, -autovscroll => 1 );
#$tab = $window->AddTabStrip( -name => "Tab", -height => 320, -width => 620, -left => 0, -top => 0 );
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

%logindata, %usersdata, %roomdata, %trip, %search, %stalk, %ignore, %default, %encrypt, %socketdata, %proxy;
@proxyaddr, @proxyport, @reliableaddr, @reliableport;
$endloop;

share( %logindata );
share( %usersdata );
share( %roomdata );
share( %trip );
share( %search );
share( %stalk );
share( %ignore );
share( %default );
share( %encrypt );
share( %socketdata );
share( %proxy );
share( @proxyaddr );
share( @proxyport );
share( @reliableaddr );
share( @reliableport );
share( $endloop );

while( @ARGV[0] )
     {
     if   ( @ARGV[0] eq ("-proxy" or "-p") )
          {
          $proxy{on} = 1;
          getproxylist();
          }
     elsif( @ARGV[0] eq "-usereliables" )
          {
          $proxy{usereliables} = 1;
          getreliables();
          }
     elsif( @ARGV[0] eq ("-timeout" or "-t") )
          { shift; $proxy{timeout} = @ARGV[0]; }
     elsif( @ARGV[0] eq "-skip" )
	  { shift; $proxy{skip} = @ARGV[0]; }
     elsif( @ARGV[0] eq "-debug" )
	  { $proxy{debug} = 1; }
     elsif( @ARGV[0] eq "-ip" )
	  { shift; $socketdata{address} = @ARGV[0]; }
     elsif( @ARGV[0] eq "-port" )
	  { shift; $socketdata{port} = @ARGV[0]; }
     elsif( @ARGV[0] eq "-name" )
	  { shift; $logindata{name} = @ARGV[0]; }
     elsif( @ARGV[0] eq "-character" )
	  { shift; $logindata{character} = @ARGV[0]; }
     elsif( @ARGV[0] eq "-status" )
	  { shift; $logindata{status} = @ARGV[0]; }
     elsif( @ARGV[0] eq "-rgb" )
	  {
	  shift; $logindata{r} = @ARGV[0];
	  shift; $logindata{g} = @ARGV[0];
	  shift; $logindata{b} = @ARGV[0];
	  }
     elsif( @ARGV[0] eq "-x" )
	  { shift; $logindata{xposition} = @ARGV[0]; }
     elsif( @ARGV[0] eq "-y" )
	  { shift; $logindata{yposition} = @ARGV[0]; }
     elsif( @ARGV[0] eq "-scl" )
	  { shift; $logindata{scl} = @ARGV[0]; }
     elsif( @ARGV[0] eq "-attrib" )
	  { shift; $logindata{attrib} = @ARGV[0]; }
     elsif( @ARGV[0] eq ("-room" or "-r") )
          {
	  shift;
          if   ( @ARGV[0] eq "iriguchi" )     { $logindata{room1} = "MONA8094";    $socketdata{port} = 9095; shift; }
          elsif( @ARGV[0] eq "atochi" )       { $logindata{room1} = "ANIKI8088";   $socketdata{port} = 9083; shift; }
          elsif( @ARGV[0] eq "ooheya" )       { $logindata{room1} = "MONABIG8093"; $socketdata{port} = 9093; shift; }
          elsif( @ARGV[0] eq "chibichato" )   { $logindata{room1} = "ANIMAL8098";  $socketdata{port} = 9090; shift; }
          elsif( @ARGV[0] eq "moa" )          { $logindata{room1} = "MOA8088";     $socketdata{port} = 9092; shift; }
          elsif( @ARGV[0] eq "chiikibetsu" )  { $logindata{room1} = "AREA8089";    $socketdata{port} = 9095; shift; }
          elsif( @ARGV[0] eq "wadaibetsu" )   { $logindata{room1} = "ROOM8089";    $socketdata{port} = 9090; shift; }
          elsif( @ARGV[0] eq "tateyokoheya" ) { $logindata{room1} = "MOXY8097";    $socketdata{port} = 9093; shift; }
          elsif( @ARGV[0] eq "cool" )         { $logindata{room1} = "COOL8099";    $socketdata{port} = 9090; shift; }
          elsif( @ARGV[0] eq "kanpu" )        { $logindata{room1} = "kanpu8000";   $socketdata{port} = 9094; shift; }
          elsif( @ARGV[0] eq "monafb" )       { $logindata{room1} = "MOFB8000";    $socketdata{port} = 9090; shift; }
          $logindata{room2} = @ARGV[0];
          }
     shift;
     }

%logindata =  ( name      => $logindata{name}||"American man...",
                character => $logindata{character}||"chotto1",
                status    => $logindata{status}||"normal",
	        room1     => $logindata{room1}||"MONA8094",
	        room2     => $logindata{room2}||"main",
	        xposition => $logindata{xposition}||381,
	        yposition => $logindata{yposition}||275,
	        scl       => $logindata{scl}||100,
	        r         => $logindata{r}||100,
	        g         => $logindata{g}||100,
	        b         => $logindata{b}||100,
	        attrib    => $logindata{attrib}||"no" );
%default    = %logindata;
%stalk      = ( on => 0, id => 0, ihash => 0 );
%search     = ( on => 0, main => 0, counter => 0, lockstarttime => 0, print => 0, room1 => 0, room2 => 0 );
%ignore     = ( antiignoreon => 0, antiignoreall => 0 );
%socketdata = ( address => $socketdata{address}||"153.122.46.192",
                port    => $socketdata{port}||9095 );
%proxy      = ( on           => $proxy{on}||0,
                retry        => 1,
	        timeout      => $proxy{timeout}||2,
	        skip         => $proxy{skip}||0,
	        lockproxy    => 0,
	        lockaddr     => 0,
                lockport     => 0,
	        usereliables => $proxy{usereliables}||0,
	        debug        => $proxy{debug}||1 );
$endloop    = 0;
login();

$pingthread       = threads->create(\&ping, "20");
$readsocketthread = threads->create(\&readsocket);

Win32::GUI->Dialog();
