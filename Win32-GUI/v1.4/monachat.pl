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
use Win32::GUI::Constants qw(EN_LINK ENM_LINK WM_CHAR);
use Win32::Clipboard;
use LWP::UserAgent;
use POSIX qw(LC_COLLATE);
use WWW::Shorten qw{TinyURL :short};
use JSON qw{encode_json decode_json from_json to_json};
use JSON::Parse qw{json_file_to_perl};

#-------------------------------------------------------------------------------------------------------------------#
# TODO and issues                                                                                                   #
#-------------------------------------------------------------------------------------------------------------------#

### - When looping between @inputline elements upside cursor position isn't in the last position
### - /change enters an infinite loop when it's on
### - Why do dialog windows hide when clicked?
### - For some reason outputfield selection only works with double click
### - Url clicking not implemented
### - Evade not well implemented
### - Trip doesn't change until relogin
### - Not sure if ping problem while looping between all rooms is fixed in search
### - There are three kind of comment signals
### - There are times when your login data isn't sent and therefore the <\ROOM> endline isn't shown in screen
### - Trip storing doesn't really match names, just look inside them
### - There are times when login data isn't loaded
### - Ping can't write directly to socket, so it's a bit unreliable
### - Would be better to have more proxy sites, socksproxylist have a lot of proxies but don't know how
###   reliable it is
### - Add limits to comment cache so that it goes up or down only when there is a comment stored (better?)
### - Write /getignore
### - Add encoding to url recognition
### - Possible issues with line break in <NOP />
### - Possible issue with login not loading x and y
### - Possible relogin with default after changing x and y?
### - Please, enter an incorrect room name - message when in main room
### - Doesn't change room with interface prompt
### - Put a space between attributes and parameters in login data

#-------------------------------------------------------------------------------------------------------------------#


share($LANGUAGE);
share($ENCODING);

### Make a backup of trip.txt
#system("mkdir tripbackup") if !-e "tripbackup";
#($second, $minute, $hour, $day, $month, $year) = localtime(time());
#$month++;
#$year += 1900;
#$filename = "[$day-$month-$year $hour"."h$minute"."m$second"."s]trip.txt";
#system("copy trip.txt \"tripbackup\\$filename\"") if -e "trip.txt";

### Load configuration
$configref = json_file_to_perl("config.json");
### For some reason if it's shared before declaration won't load correctly some variables
share(%config = %$configref);

### Set global configuration
###
### displaymode:
###
### Set space length
### Display mode 1: Thought to have a good size and position but it seems not to be so in japanese windows
### Display mode 2: Not tested
###

$ENABLE_GRAPHIC_INTERFACE = 1 if $config{graphic_interface};
($LANGUAGE, $ENCODING)    = $config{client_language} eq "english" ? ("english", "cp932") : ("japanese", "UTF-8");

### Load libraries
###
### The language variable is loaded from language.pm, and therefore has to be loaded after configuration,
### this enables for language quick swapping
###
use lib "lib";
use Userdata;
use Language;

### Load SDL modules
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
$SIG{__DIE__} = sub {
    my($second, $minute, $hour) = localtime(time());
    open(LOG, ">>", "log.txt");
    print LOG "[$hour:$minute:$second] Error: @_";
    print "Error: ", @_;
    close(LOG);
};


#-------------------------------------------------------------------------------------------------------------------#
# Events                                                                                                            #
#-------------------------------------------------------------------------------------------------------------------#

#-------------------------------------------------------------------------------------------------------------------#
# Main window                                                                                                       #
#-------------------------------------------------------------------------------------------------------------------#

### The event loop in Win32::GUI is ended when -1 is returned
###
sub Window_Terminate
    {
    if( $config{client_savelog} )
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

sub Window_Minimize
    {
    $window->Hide();
    $MINIMIZED = 3;
    }

sub Window_Resize
    {
    ### Window_Resize and Window_Minimize are called when the window is resized
    ### so MINIMIZED has to be reduced two times,
    ### the first when the window is minimized and the second when it's restored
    $MINIMIZED-- if $MINIMIZED > 1;
    if   ($MINIMIZED == 1)
         {
         $window->Show();
         $MINIMIZED = 0;
         }
    elsif($MINIMIZED)
         {
         return;
         }
    return if !$CANRESIZE;
    my($width, $height) = ($window->Width(), $window->Height());
    
    my $wdifference = $width  - $WINDOWWIDTH;
    my $hdifference = $height - $WINDOWHEIGHT;
    
    if( $width  != $WINDOWWIDTH )
      {
      $outputfield->Width     ($outputfield->Width()      + $wdifference);
      $inputfield->Width      ($inputfield->Width()       + $wdifference);
      $configbutton->Left     ($configbutton->Left()      + $wdifference);
      $menulistview->Left     ($menulistview->Left()      + $wdifference);
      $optionlistview->Left   ($optionlistview->Left()    + $wdifference);
      $logindatalistview->Left($logindatalistview->Left() + $wdifference);
      }
    if( $height != $WINDOWHEIGHT )
      {
      $outputfield->Height      ($outputfield->Height()       + $hdifference);
      $inputfield->Top          ($inputfield->Top()           + $hdifference);
      $configbutton->Top        ($configbutton->Top()         + $hdifference);
      $menulistview->Height     ($menulistview->Height()      + $hdifference);
      $optionlistview->Height   ($optionlistview->Height()    + $hdifference);
      $logindatalistview->Height($logindatalistview->Height() + $hdifference);
      }
    
    ($WINDOWHEIGHT, $WINDOWWIDTH) = ($height, $width);
    $inputfield->Hide();
    $inputfield->Show();
    }


#-------------------------------------------------------------------------------------------------------------------#
# Notify icon                                                                                                       #
#-------------------------------------------------------------------------------------------------------------------#

### Send the window to the taskbar icon when minimized
#sub Window_Minimize
#    {
#    $window->Disable();
#    $window->Hide();
#    }

### Show the window when the taskbar icon is clicked
#sub NotifyIcon_Click
#    {
#    $window->Enable();
#    $window->Show();
#    }


#-------------------------------------------------------------------------------------------------------------------#
# Config button                                                                                                     #
#-------------------------------------------------------------------------------------------------------------------#

### Config button left click
sub ConfigButton_MouseDown { show_listview("menulistview"); }

### Config button middle click
sub ConfigButton_MouseMiddleDown { show_listview("logindatalistview"); }

### Config button right click
sub ConfigButton_MouseRightDown { show_listview("optionlistview"); }

sub show_listview
    {
    no strict "refs";
    my $listview = shift;
    
    #$listbox->SetBkColor("#AABBCC");
    
    $option{readonly} = $CONFIGMENU;
    $CANRESIZE        = $CONFIGMENU;
    $inputfield->SetFocus();
    $outputfield->Change(-readonly => $option{readonly});
    
    refresh_listview_users() if $listview eq "menulistview";
    refresh_logindata()      if $listview eq "logindatalistview";
    
    if   ( $CONFIGMENU )
         {
         ${$listview}->Hide();
         $window->Width($window->Width() - 180);
         }
    else {
         ${$listview}->Show();
         $window->Width($window->Width() + 180);
         }
    
    $CONFIGMENU = $CONFIGMENU ? 0 : 1;
    }


#-------------------------------------------------------------------------------------------------------------------#
# Listview                                                                                                          #
#-------------------------------------------------------------------------------------------------------------------#

sub refresh_listview_users
    {
    my $columnposition = 0;
    $menulistview->Clear();
    
    foreach my $id (keys %roomid)
        {
        my $name     = $userdata->get_name($id)||"null";
        my $ihash    = $userdata->get_ihash($id)||"no ihash";
        my $userdata = $config{client_showtrip} ? "$name $ihash." : $name;
        $userdata = encode("cp932", $userdata);
        $menulistview->InsertItem(-text => $userdata) if !$CONFIGMENU;
        $roomid{$id} = $columnposition++;
        }
    }

sub refresh_logindata
    {
    $logindatalistview->Clear();
    my $loginid = $logindata->get_id();
    my($name, $character, $status, $trip, $ihash, $r, $g, $b, $x, $y, $scl) = $userdata->get_data($loginid);
    my $space = " " x 8;
    
    $trip = "null" if !$trip;
    
    $logindatalistview->InsertItem(-text => "name:".encode("cp932", $name));
    $logindatalistview->InsertItem(-text => "character: ".encode("cp932", $character));
    $logindatalistview->InsertItem(-text => "status: ".encode("cp932", $status));
    $logindatalistview->InsertItem(-text => "trip: ".encode("cp932", $trip));
    $logindatalistview->InsertItem(-text => "r: ".encode("cp932", $r));
    $logindatalistview->InsertItem(-text => "g: ".encode("cp932", $g));
    $logindatalistview->InsertItem(-text => "b: ".encode("cp932", $b));
    $logindatalistview->InsertItem(-text => "x: ".encode("cp932", $x));
    $logindatalistview->InsertItem(-text => "y: ".encode("cp932", $y));
    $logindatalistview->InsertItem(-text => "scl: ".encode("cp932", $scl));

    }

#-------------------------------------------------------------------------------------------------------------------#
# User menu                                                                                                         #
#-------------------------------------------------------------------------------------------------------------------#

sub MenuListView_ItemClick
    {
    my $index = shift;
    foreach (keys %roomid) { $menuid = $_ if $roomid{$_} == $index; }
    my($x, $y) = Win32::GUI::GetCursorPos();
    
    $window->TrackPopupMenu($usermenu->{UserMenu}, $x, $y);
    }

sub UserMenuIgnore_Click
    {
    $writesocketqueue->enqueue("IGNORE", $menuid);
    }
    
sub UserMenuAntiignore_Click
    {
    my $id = $menuid;
    $option{antiignore} = 1;
    $userdata->set_antiignore($menuid);
    print_output("NOTIFICATION", ANTIIGNORE_ID);
    }
    
sub UserMenuMute_Click
    {
    my $id = $menuid;
    $mute{$id} = $mute{$id} ? 0 : 1;
    print_output("NOTIFICATION", MUTE_ID);
    }
    
sub UserMenuMutecom_Click
    {
    my $id = $menuid;
    $mute{"com$id"} = $mute{"com$id"} ? 0 : 1;
    print_output("NOTIFICATION", MUTE_COMMENT_ID);
    }
    
sub UserMenuCopy_Click      { $userdata->copy($menuid); }
sub UserMenuGetname_Click   { get_name($menuid); }
sub UserMenuGettrip_Click   { get_trip($menuid); }
sub UserMenuStalk_Click     { $userdata->set_stalk($menuid); }
sub UserMenuEvade_Click { $userdata->set_evade($menuid); }


#-------------------------------------------------------------------------------------------------------------------#
# Logindata menu                                                                                                    #
#-------------------------------------------------------------------------------------------------------------------#

sub LogindataListView_ItemClick
    {
    my $index = shift;
    
    ### TODO: Add rgb
    $index == 0  ? logindata_menu_name()      :
    $index == 1  ? logindata_menu_character() :
    $index == 2  ? logindata_menu_status()    :
    $index == 3  ? logindata_menu_trip()      :
    $index == 4  ? logindata_menu_r()         :
    $index == 5  ? logindata_menu_g()         :
    $index == 6  ? logindata_menu_b()         :
    $index == 7  ? logindata_menu_x()         :
    $index == 8  ? logindata_menu_y()         :
    $index == 9  ? logindata_menu_scl()       :
    undef;
    }

sub logindata_menu_name      { dialog("NAME");      } #0
sub logindata_menu_character { dialog("CHARACTER"); } #1
sub logindata_menu_status    { dialog("STATUS");    } #2
sub logindata_menu_trip      { dialog("TRIP");      } #3
sub logindata_menu_r         { dialog("R");         } #4
sub logindata_menu_g         { dialog("G");         } #5
sub logindata_menu_b         { dialog("B");         } #6
sub logindata_menu_x         { dialog("X");         } #7
sub logindata_menu_y         { dialog("Y");         } #8
sub logindata_menu_scl       { dialog("SCL");       } #9


#-------------------------------------------------------------------------------------------------------------------#
#Option menu                                                                                                        #
#-------------------------------------------------------------------------------------------------------------------#

sub OptionListView_ItemClick
    {
    ### Add reenter
    my $index = shift;
    
    $index == 0  ? open_menu("ProfileMenu")  :
    $index == 1  ? option_menu_default()     :
    $index == 2  ? open_menu("SearchMenu")   :
    $index == 3  ? option_menu_trigger_on()  :
    $index == 4  ? option_menu_debug_on()    :
    $index == 5  ? option_menu_roominfo_on() :
    $index == 6  ? open_menu("LanguageMenu") :
    $index == 7  ? option_menu_bkgnd_color() :
    $index == 8  ? option_menu_proxy_on()    :
    $index == 9  ? option_menu_timeout()     :
    $index == 10 ? option_menu_skip()        :
    $index == 11 ? option_menu_end()         :
    $index == 12 ? open_menu("NewMenu")      :
    $index == 13 ? option_menu_random()      :
    $index == 14 ? option_menu_server()      :
    $index == 15 ? option_menu_room()        :
    $index == 16 ? option_menu_openurl()     :
    $index == 17 ? option_menu_copyurl()     :
    $index == 18 ? option_menu_savelog()     :
    $index == 19 ? option_menu_reenter()     :
    $index == 20 ? option_menu_relogin()     :
    $index == 21 ? option_menu_disconnect()  :
    undef;
    }
    
### Profile menu
sub Profile1_Click
    {
    $userdata->set_profile(1, $logindata->get_id());
    $writesocketqueue->enqueue("REENTER");
    }
sub Profile2_Click
    {
    $userdata->set_profile(2, $logindata->get_id());
    $writesocketqueue->enqueue("REENTER");
    }
sub Profile3_Click
    {
    $userdata->set_profile(3, $logindata->get_id());
    $writesocketqueue->enqueue("REENTER");
    }

### Default click (1)
sub option_menu_default
    {
    $userdata->default($logindata);
    $option{stalk}         = 0;
    $option{nomove}        = 0;
    $option{antiignore}    = 0;
    $option{antiignoreall} = 0;
    $writesocketqueue->enqueue("REENTER");
    }

### Search menu
sub SearchMain_Click { $writesocketqueue->enqueue("SEARCH", "MAIN"); }
sub SearchAll_Click  { $writesocketqueue->enqueue("SEARCH", "ALL");  }

### Search user dialog
sub SearchUser_Click { dialog("SEARCHUSER"); }

### Trigger click (3)
sub option_menu_trigger_on  { $option{popup} = $option{popup} ? 0 : 1; }

### Debug click (4)
sub option_menu_debug_on    { $option{debug} = $option{debug} ? 0 : 1; }

### Roominfo click (5)
sub option_menu_roominfo_on { $option{roominfo} = $option{roominfo} ? 0 : 1; }

### Language menu
sub LanguageEnglish_Click   { ($LANGUAGE, $ENCODING) = ("english",  "cp932"); }
sub LanguageJapanese_Click  { ($LANGUAGE, $ENCODING) = ("japanese", "UTF-8"); }

### Background color dialogue (7)
sub option_menu_bkgnd_color { dialog("BKGNDCOLOR"); }

### Proxy click (8)
sub option_menu_proxy_on
    {
    $proxy{on} = $proxy{on} ? 0 : 1;
    $writesocketqueue->enqueue("RELOGIN");
    }

### Timeout dialogue (9)
sub option_menu_timeout { dialog("TIMEOUT"); }

### Skip dialogue (10)
sub option_menu_skip
    {
    $DIALOGTYPE = "SKIP";
    dialog();
    }

sub option_menu_end { $outputfield->Scroll(-1); } ### New click (11)

### New menu (12)
sub NewMain_Click       { new_instance(); }
sub NewHere_Click       { new_instance("here"); }

### Random click(13)
sub option_menu_random
    {
    my $loginid = $logindata->get_id();
    my $sex     = rand(10) + 1 > 5 ? "male" : "female";
    my $country = "japan";
    my $option  = "no";
    $userdata->random($loginid, $sex, $country, $option);
    $writesocketqueue->enqueue("REENTER");
    }

### Server dialog (14)
sub option_menu_server { dialog("SERVER"); }

### Room dialog (15)
sub option_menu_room { dialog("ROOM"); }

### Open url click (16)
sub option_menu_openurl
    {
    if( !$option{url} )
      {
      print_output("ERROR", "There isn't any url to open.\n");
      return;
      }
    
    my $url = $option{url};
    $url    = "www.".$url if $url !~ m/^(?:https?:\/\/|www.)/;
    system("start $url");
    }

### Copy url click (17)
sub option_menu_copyurl
    {
    if( !$option{url} )
      {
      print_output("ERROR", "There isn't any url to copy.\n");
      return;
      }
    $clipboard->Set($option{url});
    }

### Save log dialogue (18)
sub option_menu_savelog { dialog("SAVELOG"); }

### Reenter click (19)
sub option_menu_reenter { $writesocketqueue->enqueue("REENTER"); }

### Relogin click (20)
sub option_menu_relogin { $readsocketthread->kill("STOP"); }

### Disconnect click (21)
sub option_menu_disconnect
    {
    $writesocketqueue->enqueue("DISCONNECT");
    $readsocketthread->kill("KILL");
    }

sub open_menu
    {
    no strict "refs";
    my $menuname = shift;
    my($x, $y)   = Win32::GUI::GetCursorPos();
    
    my $menuobject = lc($menuname);
    $window->TrackPopupMenu(${$menuobject}->{"$menuname"}, $x, $y);
    }


#-------------------------------------------------------------------------------------------------------------------#
# Dialog                                                                                                            #
#-------------------------------------------------------------------------------------------------------------------#

sub DialogYes_Click
    {
    ### inputfield focus
    ### no length limits
    ### stat not working
    my $text = $dialoginputfield->Text();
    chomp($text);
    
    $dialog->Hide();
    
    my $loginid = $logindata->get_id();
    
    if( $DIALOGTYPE eq "NAME" ) {
        $userdata->set_name($text, $loginid);
        $writesocketqueue->enqueue("REENTER");
    }
    elsif( $DIALOGTYPE eq "CHARACTER" ) {
        $userdata->set_character($text, $loginid);
        $writesocketqueue->enqueue("REENTER");
    }
    elsif( $DIALOGTYPE eq "STATUS" ) {
        $writesocketqueue->enqueue("STAT", $text);
    }
    elsif( $DIALOGTYPE eq "TRIP" ) {
        $userdata->set_trip($text, $loginid);
        $writesocketqueue->enqueue("REENTER");
    }
    #elsif( $DIALOGTYPE eq "RGB" ) {
    #    my($r, $g, $b) = ($1, $2, $3) if $text =~ /(\d{1,3}) (\d{1,3}) (\d{1,3})/;
    #    $writesocketqueue->enqueue("REENTER");
    #}
    elsif( $DIALOGTYPE eq "R" ) {
        $userdata->set_r($text, $loginid);
        $writesocketqueue->enqueue("REENTER");
    }
    elsif( $DIALOGTYPE eq "G" ) {
        $userdata->set_g($text, $loginid);
        $writesocketqueue->enqueue("REENTER");
    }
    elsif( $DIALOGTYPE eq "B" ) {
        $userdata->set_b($text, $loginid);
        $writesocketqueue->enqueue("REENTER");
    }
    elsif( $DIALOGTYPE eq "X" ) {
        $writesocketqueue->enqueue("SETXYSCL", "x$text");
    }
    elsif( $DIALOGTYPE eq "Y" ) {
        $writesocketqueue->enqueue("SETXYSCL", "y$text");
    }
    elsif( $DIALOGTYPE eq "SCL" ) {
        my $scl = $userdata->get_scl($loginid) == 100 ? -100 : 100;
        $writesocketqueue->enqueue("SETXYSCL", "scl$scl");
    }
    elsif( $DIALOGTYPE eq "SEARCHUSER" ) {
        $option{searchuser} = $text;
        $writesocketqueue->enqueue("SEARCH", "ALL");
    }
    elsif( $DIALOGTYPE eq "SERVER" ) {
        $logindata->set_room1($text);
        $writesocketqueue->enqueue("RELOGIN");
    }
    elsif( $DIALOGTYPE eq "ROOM" ) {
        $logindata->set_room2($text);
        $writesocketqueue->enqueue("RELOGIN");
    }
    elsif( $DIALOGTYPE eq "SAVELOG" ) {
        save_log($text);
    }
    elsif( $DIALOGTYPE eq "BKGNDCOLOR" ) {
        $outputfield->SetBkgndColor($text);
    }
    elsif( $DIALOGTYPE eq "TIMEOUT" ) {
        $proxy{timeout} = $text;
    }
    elsif( $DIALOGTYPE eq "SKIP" ) {
        $proxy{skip}    = $text;
    }
    
    $dialoglabel->Hide();
    $DIALOGTYPE = undef;
    }

sub DialogNo_Click
    {
    $dialog->Hide();
    $dialoglabel->Hide();
    $DIALOGTYPE = undef;
    }

sub dialog
    {
    $DIALOGTYPE = shift;
    ### Set dialog text
    my($label, $title) =
        $DIALOGTYPE eq "NAME"       ? ("Name:", "Choose a name")              :
        $DIALOGTYPE eq "CHARACTER"  ? ("Character:", "Choose a character")    :
        $DIALOGTYPE eq "STATUS"     ? ("Stat:", "Choose a stat")              :
        $DIALOGTYPE eq "TRIP"       ? ("Trip:", "Choose a trip")              :
        $DIALOGTYPE eq "RGB"        ? ("Color:", "Choose a color")            :
        $DIALOGTYPE eq "X"          ? ("x:", "Choose x")                      :
        $DIALOGTYPE eq "Y"          ? ("y:", "Choose y")                      :
        $DIALOGTYPE eq "SCL"        ? ("scl:", "Choose scl")                  :
        $DIALOGTYPE eq "SERVER"     ? ("server:", "Choose a server")          :
        $DIALOGTYPE eq "ROOM"       ? ("room:", "Choose a room")              :
        $DIALOGTYPE eq "SAVELOG"    ? ("Log name:", "Choose a log name")      :
        $DIALOGTYPE eq "SEARCHUSER" ? ("User:", "Choose a user to search")    :
        $DIALOGTYPE eq "BKGNDCOLOR" ? ("Color:", "Choose a background color") :
        $DIALOGTYPE eq "TIMEOUT"    ? ("Timeout:", "Choose a timeout value")  :
        $DIALOGTYPE eq "SKIP"       ? ("Skip:", "Number of proxies to skip")  : ### - Not working ?
        (undef, undef);
    
    ### Change title
    $dialog->Change(-title => $title);
    
    ### Add dialog text
    $dialoglabel = $dialog->AddLabel(
        -text => $label,
        -top  => 26,
        -left => 20
    );
    
    #$dialog->DoModal(1);
    $dialog->Show();
    }


#-------------------------------------------------------------------------------------------------------------------#
# Outputfield                                                                                                       #
#-------------------------------------------------------------------------------------------------------------------#

sub Outputfield_MouseDown { $option{readonly} = 0; }

### Do something when a url is clicked
###
### Takes:
### - array: Click related data
### Returns:
### - scalar: Url address
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

### TODO
###sub Outputfield_Update
###    {
###    $outputfield->Scroll(-1) if $outputfield->GetLine(15) and !$FIRSTSCROLL;
###    $FIRSTSCROLL = 1;
###    }


#-------------------------------------------------------------------------------------------------------------------#
# Inputfield                                                                                                        #
#-------------------------------------------------------------------------------------------------------------------#

### So that inputfield never loses focus
###
sub Inputfield_LostFocus { $inputfield->SetFocus() if $option{readonly}; }

sub Inputfield_WM_CHAR
    {
    my($inputfield, $key, $a) = @_;
    return $key == 13 ? 0 : 1; ### To avoid beeps when pressing enter
    }

sub Inputfield_MouseDown
    {
    $option{readonly} = 1;
    $inputfield->SetFocus();
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
### - array: Inputfield related data
### Returns:
### - Nothing
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
        if($FIRSTCOPIED)
          {
          shift(@inputline);
          $FIRSTCOPIED  = 0;
          $INPUTCOUNTER = 0;
          }
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
   elsif( $key == 38 )
        {
        ### Get text and decode it from utf8
        my $text = $inputfield->Text()||"";
        chomp($text);
        
        ### Push current line into @inputline if its position is the first
        if(!$INPUTCOUNTER)
          {
          unshift(@inputline, $text);
          $FIRSTCOPIED = 1;
          }

        ### And copy previous line to $inputfield
        if( $inputline[$INPUTCOUNTER + 1] )
          {
          $INPUTCOUNTER++;
          $inputfield->SelectAll();
          $inputfield->ReplaceSel($inputline[$INPUTCOUNTER]);
          }
        }
   
   ### Or down...
   ###
   elsif( $key == 40 )
        {
        if( $inputline[$INPUTCOUNTER - 1] and $INPUTCOUNTER )
          {
          $INPUTCOUNTER--;
          $inputfield->SelectAll();
          $inputfield->ReplaceSel($inputline[$INPUTCOUNTER]);
          
          shift(@inputline) if !$INPUTCOUNTER;
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
   elsif( $key == WM_CHAR )
        {
        print "WM_CHAR.\n";
        }
   }



#--------------------------------------------------------------------------------------------------------------------



### Handles $inputfield input
###
### Takes:
### - scalar: An inputfield command
### Returns:
### - Nothing
###
sub command_handler
    {
    local $command = shift;
    
    my    $loginid = $logindata->get_id();
    if   ( $command eq "/login" )
         { $readsocketthread->kill("STOP"); }
    #elsif( $command =~ /^\/relogin\s*(.*)/ )
    #     {
    #     $proxy{skip} = $1 if $1 =~ /skip (\d+)/;
    #     $readsocketthread->kill("STOP");
    #     }
    elsif( $command eq "/reenter" )
         { $writesocketqueue->enqueue("REENTER"); }
    elsif( $command eq "/disconnect" )
         {
         $writesocketqueue->enqueue("DISCONNECT");
         $readsocketthread->kill("KILL");
         }
    elsif( $command =~ /\/name (.+)/ )
         {
         my $name = $1;
         if  ($config{client_cutname})
             { $name = substr($name, 0, 20); }
         else{
             if( length($name) > 20 )
               {
               print_output("ERROR", NAME_TOO_LARGE);
               return;
               }
             }
         $userdata->set_name($name, $loginid);
         $writesocketqueue->enqueue("REENTER");
         }
    elsif( $command =~ /\/character (.+)/ )
         {
         $userdata->set_character($1, $loginid);
         $writesocketqueue->enqueue("REENTER");
         }
    elsif( $command =~ /\/stat (.+)/ )
         {
         my $status = $1;
         if  ($config{client_cutstatus})
             { $status = substr($status, 0, 20); }
         else{
             if( length($1) > 20 )
               {
               print_output("ERROR", STAT_TOO_LARGE);
               return;
               }
             }
         $writesocketqueue->enqueue("STAT", $status);
         }
    elsif( $command =~ /\/trip (.+)/ )
         {
         ### Just in case
         my $trip = $1 ne " " ? $1 : "";
         $logindata->set_trip($trip);
         $writesocketqueue->enqueue("REENTER");
         }
    elsif( $command =~ /\/changetrip (.+)/ )
         {
         my $trip = $1;
         $writesocketqueue->enqueue(qq{<SET trip="$trip" />\0});
         }
    elsif( $command =~ /\/room (.+)/ )
         {
         my $room = $1 ? $1 : '0';
         $logindata->set_room2($room);
         $writesocketqueue->enqueue("REENTER");
         }
    elsif( $command eq "/previous" )
         {
         my $room = $logindata->get_room2();
         my $previousroom = 0;
         
         if(!%search)
           {
           $writesocketqueue->enqueue("SEARCH", "MAIN");
           return;
           }
         
         my @roomlist = grep {$_} keys %search;
         @roomlist    = sort {$a <=> $b} @roomlist;
         
         foreach(keys @roomlist)
             {
             $room         = $previousroom and last if $roomlist[$_] >= $room;
             $previousroom = $roomlist[$_];
             $room         = $previousroom if !$roomlist[$_+1];
             }
         
         return if !$room;
         #$room = 1 if !$room;
         $logindata->set_room2($room);  
         $writesocketqueue->enqueue("REENTER");
         }
    elsif( $command eq "/next" )
         {
         my $room = $logindata->get_room2();
         my $previousroom = 0;
         
         if(!%search)
           {
           $writesocketqueue->enqueue("SEARCH", "MAIN");
           return;
           }
         
         my @roomlist = grep {$_} keys %search;
         @roomlist    = sort {$a <=> $b} @roomlist;
         
         foreach(keys @roomlist)
             {
             $room = $roomlist[$_] and last if $roomlist[$_] > $room;
             }
         
         return if !$room;
         $logindata->set_room2($room);
         $writesocketqueue->enqueue("REENTER");
         }
    ### Issues:
    ### - Translate
    elsif( $command =~ /\/server (.+)/ )
         {
         my($room, $port) = get_server($1);
         
         print "room: $room, port: $port.\n";
         
         if  ( $room and $port )
             {
             $logindata->set_room($room);
             $logindata->set_room2("main");
             $socketdata{port} = $port;
             $readsocketthread->kill("STOP");
             }
         else{ print_output("ERROR", "Please, enter an incorrect room name.\n") };
         }
    elsif( $command =~ /\/rgb (\d{1,3}|x) (\d{1,3}|x) (\d{1,3}|x)/ )
         {         
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
         elsif( $1 =~ /(\d{1,4})/ )
              {
              my $id           = $1;
              my($x, $y, $scl) = $userdata->get_x_y_scl($id);
              $option{stalk}   = 1;
              $userdata->set_stalk($id);
              $writesocketqueue->enqueue("SETXYSCL", "x$x"."y$y"."scl$scl");
              print_output("NOTIFICATION", STALK_ID);
              }
         }
    elsif( $command =~ /\/evade (.+)/ )
         {
         if   ( $1 =~ /(on|off)/  )
              {
              $option{evade} = $1 eq "on" ? 1 : 0;
              print_output("NOTIFICATION", EVADE_ON);
              }
         elsif( $1 =~ /(\d{1,4})/ )
              {
              my $id = $1;
              $option{evade} = 1;
              $userdata->set_evade($id);
              print_output("NOTIFICATION", EVADE_ID);
              }
         }
    elsif( $command eq "/nanashi" )
         {
         $userdata->nanashi($loginid);
         $writesocketqueue->enqueue("REENTER");
         }
    elsif( $command =~ /\/copy (\d{1,4})/ )
         {         
         $userdata->copy($1, $loginid);
         $writesocketqueue->enqueue("REENTER");
         }
    elsif( $command =~ /^\/random\s*(.*)$/ )
         {
         my $search = $1;
         
         ### Look for sex and country and if there isn't any set default
         my $sex     = $search && $search =~ /(male|female)/ ? $1 : (rand(10) + 1) > 5 ? "male" : "female";
         my $country = $search && $search =~ /(america|uk|germany|france|russia|canada)/ ? $1 : "japan";
         my $option  = $search && $search =~ /(nomove|stay)/ ? $1 : "";
         
         ### Get name
         $userdata->random($loginid, $sex, $country, $option);
         
         $writesocketqueue->enqueue("REENTER");
         }
    elsif( $command eq "/default" )
         {
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
    elsif( $command =~ /\/profile (.+)/ )
         {
         $userdata->set_profile($1, $loginid);
         $writesocketqueue->enqueue("REENTER");
         }
    elsif( $command =~ /\/saveprofile\s*(.*)/ )
         {
         my $p;
         for(1...10)
            {
            $p = $_;
            last if !$config{"p$p"."_name"};
            }
            
         my $phead      = "p$p"."_head";
         my $pname      = "p$p"."_name";
         my $pcharacter = "p$p"."_character";
         my $pstatus    = "p$p"."_status";
         my $ptrip      = "p$p"."_trip";
         my $pr         = "p$p"."_r";
         my $pg         = "p$p"."_g";
         my $pb         = "p$p"."_b";
         my $px         = "p$p"."_x";
         my $py         = "p$p"."_y";
         my $pscl       = "p$p"."_scl";
         my $pattrib    = "p$p"."_attrib";
         my $proom1     = "p$p"."_room1";
         my $proom2     = "p$p"."_room2";
          
         my($name, $character, $status, $trip, $ihash, $r, $g, $b, $x, $y, $scl) = $userdata->get_data($loginid);
         
         local $/;
         binmode STDOUT, ":utf8";
         use utf8;
    
         open(CONFIGJSON, "<", "config.json");
         my $configjson = <CONFIGJSON>;
         close(CONFIGJSON);
    
         $configjson = decode_json($configjson);
         
         $configjson->{$phead}      = "[PROFILE $p]";
         $configjson->{$pname}      = $name;
         $configjson->{$pcharacter} = $character;
         $configjson->{$pstatus}    = $status;
         $configjson->{$ptrip}      = $trip;
         $configjson->{$pr}         = $r;
         $configjson->{$pg}         = $g;
         $configjson->{$pb}         = $b;
         $configjson->{$px}         = $x;
         $configjson->{$py}         = $y;
         $configjson->{$pscl}       = $scl;
         $configjson->{$pattrib}    = "no";
         $configjson->{$proom1}     = $logindata->get_room();
         $configjson->{$proom2}     = $logindata->get_room2();
         
         open(CONFIGJSON, ">", "config.json");
         print CONFIGJSON encode_json($configjson);
         close(CONFIGJSON);
         
         print_output("SEARCH", "Profile saved as $p.");
         }
    elsif( $command =~ /\/deleteprofile (\d+)/ )
         {
         return if !$1;

         local $/;
         binmode STDOUT, ":utf8";
         use utf8;
         
         open(CONFIGJSON, "<", "config.json");
         my $configjson = <CONFIGJSON>;
         close(CONFIGJSON);
         
         $configjson = decode_json($configjson);
         
         my @profiledata = ("p$1_head", "p$1_name", "p$1_character", "p$1_status", "p$1_trip",
                            "p$1_r", "p$1_g", "p$1_b", "p$1_x", "p$1_y", "p$1_scl",  "p$1_attrib",
                            "p$1_room1", "p_$1room2");
                              
         delete $configjson->{$_} foreach (@profiledata);
         
         open(CONFIGJSON, ">", "config.json");
         print CONFIGJSON encode_json($configjson);
         close(CONFIGJSON);
         
         print_output("SEARCH", "Profile $1 deleted.");
         }
    elsif( $command =~ /\/proxy\s*(.*)/ )
         {
         return if !( $1 eq "on" or $1 eq "off" );

         $proxy{on} = $1 eq "on" ? 1 : 0;
         print_output("NOTIFICATION", PROXY_ON);
         $readsocketthread->kill("STOP");
         }
    elsif( $command =~ /\/skip (\d+)/ )
         {
         $proxy{skip} = $1;
         print_output("NOTIFICATION", PROXY_SKIP);
         }
    elsif( $command =~ /\/timeout (\d\.*\d*)/ )
         {
         $proxy{timeout} = $1;
         print_output("NOTIFICATION", PROXY_TIMEOUT);
         }
    elsif( $command =~ /\/site (\d{1,4})/ )
         {
         $proxy{site} =
             $1 == 1 ? "socksproxy" :
             $1 == 2 ? "socksproxylist" :
             $proxy{site};
         print_output("NOTIFICATION", PROXY_SITE);
         $readsocketthread->kill("STOP");
         }
    elsif( $command =~ /\/change (\w{2,3})/ )
         {
         $proxy{change} =
             $1 eq "on"  ? 1 :
             $1 eq "off" ? 0 : $proxy{change};
         print_output("NOTIFICATION", PROXY_CHANGE);
         }
    elsif( $command eq "/openurl" )
         {
         if( !$option{url} )
           {
           print_output("ERROR", "There isn't any url to open.\n");
           return;
           }
         
         my $url = $option{url};
         $url    = "www.".$url if $url !~ m/^(?:https?:\/\/|www.)/;
         system("start $url");
         }
    elsif( $command eq "/copyurl" )
         {
         if( !$option{url} )
           {
           print_output("ERROR", "There isn't any url to copy.\n");
           return;
           }
         
         $clipboard->Set($option{url});
         }
    elsif( $command =~ /\/shorturl (.+)/ )
         {
         my $longurl  = $1;
         my $shorturl = short_link($longurl);
         $writesocketqueue->enqueue("COMMENT", $shorturl);
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
    ### Issues:
    ###
    ### - Scrolls in main
    ###
    elsif( $command =~ /\/end/ )
         { $outputfield->Scroll(-1) if !$logindata->get_room2() or $logindata->get_room2() ne "main"; }
    elsif( $command =~ /\/new\s*(.*)|\/newinstance\*(.*)/ )
         { $1 ? new_instance($1) : new_instance(); }
    elsif( $command =~ /\/antiignore (.+)/ )
         {
         if   ( $1 eq "on" or $1 eq "off" )
              {
              $option{antiignore}    = $1 eq "on" ? 1 : 0;
              $option{antiignoreall} = 0 if $1 eq "off";
              print_output("NOTIFICATION", ANTIIGNORE_ON);
              }
         elsif( $1 =~ /(\d{1,4})/ )
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
         my $search = $1; ###
         
         if   ( $search eq "on" or $search eq "off" ) {
                print_output("NOTIFICATION", MUTE_ON);
                $option{mute} = $1 eq "on" ? 1 : 0;
         }
         elsif( $search =~ /(\d{1,4})/ ) {
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
              push(@{$config{client_trigger}}, $1);
              }
         }
    elsif( $command =~ /^\/repeat (.+)$/ )
         {
         my $argument = $1;
         my($command, $timeout, $wait, $number) = (undef, 999_999_999, 0, 1);
         
         $command  = $1 if $argument =~ /"(.+?)"/;
         $timeout  = $1 if $argument =~ /timeout (\d+)/;
         $wait     = $1 if $argument =~ /wait (.+)/;
         $number   = $1 if $argument =~ /number (\d+)/;
         
         return if !$command;
         
         repeat($command, $number, $wait, $timeout);
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
         return if !($1 eq "on" or $1 eq "off");
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
         return if $1 ne "on" and $1 ne "off";
         $option{readonly} = $1 eq "on" ? 1 : 0;
         $outputfield->Change(-readonly => $option{readonly});
         }
    elsif( $command =~ /\/backgroundcolor (.+)/ )
         {
         #return if $1 !~ /#\w{6}/;
         $outputfield->SetBkgndColor($1);
         }
    elsif( $command =~ /\/getname (.+)/ )
         {
         if  ($1 eq "all")
             {
             foreach my $id (sort keys %roomid)
                 {
                 next if $id == $logindata->get_id();
                 print_output("SEARCH", get_name($id));
                 }
             }
         else
             {
             print_output("SEARCH", get_name($1));
             }
         }
    elsif( $command =~ /\/gettrip (.+)/ )
         { get_trip($1); }
    elsif( $command =~ /\/addname (\d{1,4}) (.+)/ )
         {
         my $trip = length($1) == 10 ? $trip : $userdata->get_ihash($1);
         my $name = $2;
         $tripqueue->enqueue($trip, $name);
         }
    elsif( $command eq "/getroom" )
         { foreach my $id (keys %roomid) { print_data("USER", $id); } }
    elsif( $command eq "/getignore" )
         {
         ### TODO
         ...
         }
    elsif( $command =~ /\/save\s*(.*)/  )
         { save_log($1); }
    elsif( $command eq "/exit" ) { exit(); }
    else { print_output("ERROR", NO_COMMAND); }
    }

sub repeat
    {
    my($command, $number, $wait, $timeout) = @_;
    
    $number = 999_999_999 if !$number < 0 or !$number;
    print "command: $command, number: $number, wait: $wait, timeout: $timeout\n";
    
    my $starttime = time();
    for(1...$number)
       {
       command_handler($command);
       
       if($timeout)
         {
         last if time() - $starttime > $timeout;
         }
         
       use Time::HiRes qw{usleep};
       
       usleep($wait*10000) if $wait;
       }
    }

### Takes data from print_output and prints it on outputfield
###
### Takes:
### - array: An array sorted with a color/phrase scheme
### Returns:
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
         $text = decode("cp932", $text);
         $text = encode("cp932", $text);
         $outputfield->ReplaceSel($text);
         }
    
    ### Scroll automatically
    if( !$FIRSTSCROLL and $outputfield->GetLine(16) )
      {
      $outputfield->Scroll(-1);
      $FIRSTSCROLL = 1;
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
sub print_output
    {
    my($option, $usercolor) = (shift, "");
    my $line;
    
    if   ( $option{displaymode} == 1 ) { $line = $LANGUAGE eq "english" ? "-" x 190 : "-" x 384; }
    elsif( $option{displaymode} == 2 ) { $line = $LANGUAGE eq "english" ? "-" x 93  : "-" x 190; }
    
    ### Sets the user color
    if( $_[0] eq "USERCOLOR" )
      {
      shift;
      $usercolor = shift||"#000000";
      $usercolor = "#000000" if $usercolor eq "#FFFFFF" or $usercolor eq "#646464";
      }
    
    if( $option eq "USERDATA" )
      {
      ### Issues: not printing in main
      return if $logindata->get_room2() eq "main";
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
    elsif( $option eq "COMMENT" )
         {
         my($date, $name, $trip, $ihash, $id, $comment) = @_;
         
         print_list (
             "#000000", $date,
             $usercolor||"#000000", " $name",
             $usercolor||"#000000", "$trip$ihash",
             $usercolor||"#000000", " ($id)",
             "#000000", ": $comment"
           );
         }
    elsif( $option eq "IGNORE" )
         {
         my($name, $ihash, $id, $ignore, $ignorecolor, $ignorename, $ignoreihash, $ignoreid) = @_;
         $ignorecolor = "#000000" if $ignorecolor eq "#FFFFFF" or $ignorecolor eq "#646464";
         $ignorega    = $LANGUAGE eq "japanese" ? GA : " $ignore";
         #$ignorename  = $LANGUAGE eq "japanese" ? "$ignorename" : " $ignorename"; ?
         
         print_list (
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
    elsif( $option eq "LOGIN" )
         {
         return if $logindata->get_room2() eq "main";
         my $text = shift;
         chomp($text);
         
         print_list (
            "#000000", "$line\n",
            "#000000", "$LOGINSPACE$text",
            "#000000", "$line\n"
           );
         }
    elsif( $option eq "ROOM" )
         {
         my $text = shift;
         chomp($text);
         
         print_list(
             "#0000FF", "$line\n",
             "#0000FF", "$ROOMSPACE$text\n",
             "#0000FF", "$line\n"
           );
         }
    elsif( $option eq "EXIT" )
         {
         return if $logindata->get_room2() eq "main"; ###
         my $text = shift;
         return if $text eq "\n"; # ?
         
         print_list(
             "#000000", "<-- ",
             $usercolor||"#000000", $text
           );
         }
    elsif( $option eq "SEARCH" )
         {
         my $text = shift;
         chomp($text);
         
         print_list(
             "#FFFF00", "$line\n",
             "#FFFF00", "$text\n",
             "#FFFF00", "$line\n"
           );
         }
    elsif( $option eq "ENTER" )
         {
         return if $logindata->get_room2() eq "main"; ###
         my $text = shift;
         my $color = $usercolor||"#000000"; ###
         print_list($color, $text);
         }
    else {
         my $text  = shift;
         my $color =
             $option eq "NOTIFICATION" ? "#0000FF" :
             #$option eq "ENTER"        ? $usercolor||"#000000" :
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
sub login
    {
    my $option = shift||"";
    $pingsemaphore->down();
    $pingthread->kill("STOP");
    
    if( $proxy{on} )
      {
      while()
           {
           ### Get proxy list if it's empty
           while(!@proxyaddr)
                {
                $proxy{version} = 5 if $proxy{site} eq "socksproxylist";
                get_proxy_list();
               
                if ( $proxy{site} ne "socksproxylist" and !@proxyaddr )
                   { $proxy{version} = $proxy{version} == 4 ? 5 : 4; }
                }

           ### Connect through the proxy
           $remote = IO::Socket::Socks->new(
               ProxyAddr    => $proxyaddr[0],
               ProxyPort    => $proxyport[0],
               ConnectAddr  => $socketdata{address},
               ConnectPort  => $socketdata{port},
               SocksDebug   => $proxy{debug},
               Timeout      => $proxy{timeout},
               SocksVersion => $proxy{version}
           ) or warn "$SOCKS_ERROR\n" and shift(@proxyaddr) and shift(@proxyport) and redo;

           ### Redo if skip is higher than 0 or change is on
           if( $proxy{skip} or ($proxy{change} and $proxy{previousaddr} and $proxy{previousaddr} == $proxyaddr[0]))
             {
             shift(@proxyaddr);
             shift(@proxyport);
             $proxy{skip}--;
             next;
             }
          
           $proxy{previousaddr} = $proxyaddr[0];
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
    
    print $remote encode("utf8", "MojaChat\0");
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
sub enter_room
    {
    my($option, $enter) = (shift||"", "");
    my $id    = $logindata->get_id();
    
    my $room  = $logindata->get_room();
    my $room2 = $logindata->get_room2();
    
    if( $room2 and $room2 ne "main" ) { $room .= "/$room2"; }
    #else { $room .= "/0"; } ### So that it can enter room 0
    
    my $attrib = $logindata->get_attrib();
    my($name, $character, $status, $trip, $ihash, $r, $g, $b, $x, $y, $scl) =
        $option eq "FIRSTTIME" ? $logindata->get_data() : $userdata->get_data($id);
    
    ### For the time being
    ### For some reason there is corruption without this line
    ($name, $character, $status, $trip, $ihash, $r, $g, $b, $x, $y, $scl) = ( ("") x 11 ) if !$name;
    
    $scl = 100;
    $trip = $logindata->get_trip();
    
    ### Set $option{room} to true so that a line is drawn in the screen
    $option{room} = 1;
    
    ### And empty rooms user list
    %roomid = ();
    
    ### Push a delete all room users event to SDL queue
    push_event(26, "all") if $ENABLE_GRAPHIC_INTERFACE;
    
    ### Send data
    print $remote encode("utf8", qq{<EXIT no="$id" \/>\0}) if $option eq "REENTER";
    if   ( $logindata->get_room2() eq "main" )
         { $enter = qq{<ENTER room="$room" name="$name" attrib="$attrib" />\0}; }
    else {
         $enter  = qq{<ENTER room="$room" umax="0" type="$character" name="$name" };
         $enter .= qq{trip="$trip" } if $trip ne "";
         $enter .= qq{x="$x" y="$y" r="$r" g="$g" b="$b" scl="$scl" stat="$status" />\0};
         }
    print $remote encode("utf8", $enter);
    }

sub get_server
    {
    my($room, $option) = ($_[0], $_[1]||"");
    my($room1, $port);
    
    if  ( $option eq "reverse" )
        {
        ($room1) =
            $room eq "MONA8094"    ? "iriguchi"     :
            $room eq "ANIKI8080"   ? "atochi"       :
            $room eq "MONABIG8093" ? "ooheya"       :
            $room eq "ANIMAL8098"  ? "chibichato"   :
            $room eq "MOA8088"     ? "moa"          :
            $room eq "AREA8089"    ? "chiikibetsu"  :
            $room eq "ROOM8089"    ? "wadaibetsu"   :
            $room eq "MOXY8097"    ? "tateyokoheya" :
            $room eq "COOL8099"    ? "cool"         :
            $room eq "kanpu8000"   ? "kanpu"        :
            $room eq "MOFB8000"    ? "monafb"       :
                                     (undef, undef);
        return $room1;
        }
    else
        {
        ($room1, $port) =
            $room eq "iriguchi"     ? ("MONA8094",    9095) :
            $room eq "atochi"       ? ("ANIKI8080",   9092) :
            $room eq "ooheya"       ? ("MONABIG8093", 9093) :
            $room eq "chibichato"   ? ("ANIMAL8098",  9090) :
            $room eq "moa"          ? ("MOA8088",     9092) :
            $room eq "chiikibetsu"  ? ("AREA8089",    9095) :
            $room eq "wadaibetsu"   ? ("ROOM8089",    9090) :
            $room eq "tateyokoheya" ? ("MOXY8097",    9093) :
            $room eq "cool"         ? ("COOL8099",    9090) :
            $room eq "kanpu"        ? ("kanpu8000",   9094) :
            $room eq "monafb"       ? ("MOFB8000",    9090) :
                                      (undef, undef);
        return($room1, $port);
        }
    }

sub new_instance
    {
    ### It would be better if a instance skipped the ip other instances are currently using
    ### x doesnt work
    my $search = shift||"";
         
    ### Make a backup of trip.txt
    #system("mkdir tripbackup") if !-e "tripbackup";
    #my($second, $minute, $hour, $day, $month, $year) = localtime(time());
    #$month++;
    #$year += 1900;
    #my $filename = "[$day-$month-$year $hour"."h$minute"."m$second"."s]trip.txt";
    #system("copy trip.txt \"tripbackup\\$filename\"") if -e "trip.txt";
         
    $proxy{skip} = $1 if $search =~ /skip (\d+)/;
    my $site = $proxy{site} eq "socksproxy" ? 1 : 2; ###

    my $loginid   = $logindata->get_id();
    my $name      = $userdata->get_name($loginid);
    my $character = $userdata->get_character($loginid);
    my $status    = $userdata->get_status($loginid);
    my($r, $g, $b) = $userdata->get_rgb($loginid);
    my $x         = $config{client_xrandom} ? int(rand(600) + 1) : "";
    my $y         = $config{client_yrandom} ? int(rand(400) + 1) : 275;
    my $scl       = 100;
    my $room1 = $logindata->get_room();
    $room1 = get_server($room1, "reverse");
    my $room2 = $logindata->get_room2();
    my $room = $room2 ? "$room1 $room2" : $room1;
    
    $name      = encode("cp932", $name);
    $character = encode("cp932", $character);
    $status    = encode("cp932", $status);
    $room      = encode("cp932", $room);
    
    my $loginuserdata = qq{start perl monachat.pl -proxy yes -x $x -y $y -scl $scl -site $site -new};
    $loginuserdata .= qq{ -room $room -name "$name" -character "$character" -status "$status" -rgb $r $g $b} if $search =~ /here\s*(.*)/;
    
    if( $search =~ /here\s*(.*)/ )
      {
      my $instancecounter = $1||1;
      my $room = $logindata->get_room2();
             
      for(1..$instancecounter)
         {
         system($loginuserdata);
         sleep(1);
         }
      }
    else { system($loginuserdata); }
    }

### Send x, y and scl(direction) signal to the server, calls to this function are in the format "x$x y$y scl$scl"
sub send_x_y_scl
    {
    my $line = shift;
    my $id   = $logindata->get_id();
    my $x    = $line =~ /x\s?(\d+)/     ? $1 : $userdata->get_x($id);
    my $y    = $line =~ /y\s?(\d+)/     ? $1 : $userdata->get_y($id);
    my $scl  = $line =~ /scl\s?(-?\d+)/ ? $1 : $userdata->get_scl($id);
    print $remote encode("utf8", qq{<SET x="$x" scl="$scl" y="$y" />\0});
    }

### Search function, first searches the main room and stores room with users, then if $option{ALL} is
### true searches those rooms, if $option{USER $user} is on then stops if that user is found
###
### Takes:
### - scalar: Option with ALL or USER
### Returns:
### - Nothing
###
sub search
    {
    local $option = shift||"";
    my($read, $counter, $found);
    local $room;
    local %roomdata;
    $REFRESHMAIN = 0;
    %mainroom = (); ### To delete duplicates
    
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
         $mainroom{$room} = $number if $number != 0;
         }
    %search = %mainroom;
         
    ### Goes through that list
    if( $option eq "ALL" )
      {
      my $searchusertype;
      if( $option{searchuser} ) { $searchusertype = $option{searchuser} =~ /^.{10}$/ ? "trip" : "name"; }
      
      GO_THROUGH_ROOMS: foreach $room ( sort( keys %roomdata ) )
        {
        $logindata->set_room2($room);
        enter_room("REENTER");
        ### Checks for ping
        ### Issues:
        ### - Invalid argument(undef) when that index doesn't exist
        ###
        #for( my $counter; $writesocketqueue->peek($counter); $counter++ )
        #   {
        #   if( $writesocketqueue->peek($counter) eq "PING" )
        #    {
        #    $writesocketqueue->extract($counter);
        #    print $remote encode("utf8", "<NOP />\0");
        #    }
        #   }
        ### Gets and shows the list of users in each room
        sleep(2);
        sysread($remote, $read, 20000) if $select->can_read();
        $read = decode("utf8", $read);
        
        GETUSERDATA: while( $read =~ m/<(USER)\s r="(\d{1,3})"\s name="(.*?)"\s(.+?)stat="(.*?)"\s g="(\d{1,3})"\s
                                       type="(.*?)"\s b="(\d{1,3})"\s y="(.*?)"\s x="(.*?)"\s scl="(.+?)"\s \/>/xg )
             {
             my($enteruser, $name, $idtripihash, $character, $status, $r, $g, $b, $x, $y, $scl) =
               ($1, $3, $4, $7, $5, $2, $6, $8, $10, $9, $11);
             my $id    = $idtripihash =~ /id="(\d{1,4})"/  ? $1 : "";
             my $trip  = $idtripihash =~ /trip="(.{10})"/  ? $1 : "";
             my $ihash = $idtripihash =~ /ihash="(.{10})"/ ? $1 : "";
             $userdata->set_data($name, $id, $character, $status, $trip, $ihash, $r, $g, $b, $x, $y, $scl);
             print_data($enteruser, $id);
             
             next if !$searchusertype;
             if   ( ($searchusertype eq "name" and $option{searchuser} eq $name)   or
                    ($searchusertype eq "trip" and $option{searchuser} eq $ihash ) or
                    ($searchusertype eq "trip" and $option{searchuser} eq $trip ) )
                  {
                  $found = 1;
                  print_output("SEARCH", SEARCH_USER_FOUND);
                  $option{searchuser} = undef;
                  last GO_THROUGH_ROOMS;
                  }
             }
        }
      ### Stops if user is found
      if ( !$found )
         {
         $logindata->set_room2($currentroom);
         enter_room("REENTER");
         }
      }
      
    ### Prints the results
    else {
         #local $roomswithusers = scalar keys %roomdata;
         #local $usernumber;
         #$usernumber += $_ foreach (values %roomdata);
         #$usernumber = 0 if !$usernumber;

         refresh_main("SEARCH");
         $logindata->set_room2($currentroom);
         enter_room("REENTER");
         }
    }

### Gets proxy list, this site blocks the user agent from LWP::Simple::get()
###
### Takes:
### - Nothing
### Returns:
### - Nothing
###
sub get_proxy_list
    {
    my $useragent = LWP::UserAgent->new();
    $useragent->agent("getproxylist");
    $useragent->show_progress(1);
    
    if( $proxy{site} eq "socksproxy" ) {
        my $socks     = "Socks".$proxy{version};
        my $proxylist = $useragent->get("http://socks-proxy.net");
        $proxylist    = $proxylist->content();
        
        @proxyaddr    = $proxylist =~ /<td>(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})<\/td><td>\d{4,5}<\/td>.+?$socks/g;
        @proxyport    = $proxylist =~ /<td>\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}<\/td><td>(\d{4,5})<\/td>.+?$socks/g;
    }
    
    elsif( $proxy{site} eq "socksproxylist" ) {
        ### Get main page...
        my $proxylist = $useragent->get("http://socksproxylist24.blogspot.com");
        $proxylist = $proxylist->content();
        
        ### And then post page...
        my $listurl = $1 if $proxylist =~ /(http:\/\/socksproxylist24\.blogspot\.com\.?\w*.+?-socks-proxy-list.+?\.html)/;
        $proxylist = $useragent->get($listurl);
        $proxylist = $proxylist->content();
        
        ### And recognize addresses
        @proxylist = $proxylist =~ /(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}:\d{3,5})/g;    
        @proxyaddr = map(/(.+?):.+/, @proxylist);
        @proxyport = map(/.+?:(.+)/, @proxylist);
    }
    }

sub save_log
    {
    ### If there is no filename, defaults to the room name
    my $name = shift||$logindata->get_room2();
    
    my($second, $minute, $hour, $day, $month, $year) = localtime(time());
    system("mkdir LOG") if !-e "LOG";
         
    ### Get log
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

### Refreshes main room screen
###
### Issues:
###
### - Double main room comprobation
###
sub refresh_main
    {
    my $option = shift||"ROOM";
    my($mainscreen, $roomcounter) = ("\n\t", 0);
    my $room2 = $logindata->get_room2()||"";

    if( !$room2 or $room2 eq "main")
      {
      if($option ne "SEARCH")
        {
        $outputfield->Select("0", "-1");
        $outputfield->ReplaceSel("");
        }
      
      my($usernumber, $roomswithusers) = (0, 0);
      foreach (values %mainroom)
          {
          $usernumber += $_;
          $roomswithusers++;
          }
    
      ### Format screen
      print_output("SEARCH", "\t\t\t\t  Monachat ($roomswithusers rooms, $usernumber people)");
      foreach my $room (sort {$a <=> $b} (keys %mainroom))
          {
          $mainscreen .= "[Room $room]: $mainroom{$room}";
          $roomcounter++;
          $mainscreen .= $roomcounter < 5 ? "\t" : "\n\t";
          $roomcounter = 0 if $roomcounter == 5;
          }
      $mainscreen .= "\n\n";
      #$mainscreen  = encode("cp932", $mainscreen); ### encoding issues
    
      ### Print it
      #$outputfield->Select("-1", "-1");
      #$outputfield->ReplaceSel($mainscreen);
      print_output($option, $mainscreen);
    
      if($option ne "SEARCH") { print_data("USER", $_) foreach (sort(keys %roomid)); }
      }
    %search = %mainroom;
    %mainroom = () if $logindata->get_room2() ne "main"; ### Could break main room
    }

### Ping function, this function is only used as a separate thread
###
### Takes:
### - Nothing
### Returns:
### - Nothing
###
sub ping
    {
    my $counter;
    while()
        {
        local $SIG{"STOP"} = sub {
            $pingsemaphore->down();
            $counter = 0;
            $pingsemaphore->up();
        };
         
        for( $counter = 0; $counter <= 100; $counter++ )
           {
           select(undef, undef, undef, 0.2);
           $writesocketqueue->enqueue("PING") if $counter >= 100;
           }
        }
    }

### Stores names into a json object and writes them to trip.json
###
### Takes:
### - scalar: ihash
### - scalar: name
### Returns:
### - Nothing
###
sub trip_store
    {
    my $tripfile = "trip.json";
    
    local $/;
    binmode STDOUT, ":utf8";
    use utf8;
    
    open(TRIPJSON, "<", "trip.json");
    my $tripjson = <TRIPJSON>;
    close(TRIPJSON);
    
    $tripjson = decode_json($tripjson);
    
    TRIPQUEUE: while()
         {
         my $ihash      = $tripqueue->dequeue();
         my $searchname = $tripqueue->dequeue();
         #$searchname    = encode("utf8", $searchname);
         
         ### Creates a new file and prints the ihash and name in it if it doesn't exist
         if   ( !-e $tripfile )
              {
              open(TRIP, ">", $tripfile) or die "Couldn't create trip.txt\n";
              print TRIP "{\n}";
              }
         else {              
              foreach my $name (@{$tripjson->{$ihash}})
                  {
                  redo TRIPQUEUE if $name eq $searchname;
                  }
              
              push(@{$tripjson->{$ihash}}, $searchname);
              open(TRIPJSON, ">", "trip.json");
              print TRIPJSON encode_json($tripjson);
              close(TRIPJSON);
              }
         }
    }

sub get_name
    {
    my $search = shift;
    local $trip;
    my @triplist;
         
    ### Push trips into an array
    if   ( $search =~ /^(.{10})$/ )   { $trip = $1; }
    elsif( $search =~ /^(\d{1,4})$/ ) { $trip = $userdata->get_ihash($1); }
    else { return; }
    
    my($name, $id) = $userdata->get_data_by_ihash($trip);
    
    if(!$trip)
      {
      print_output("ERROR", "Trip not found.\n");
      return;
      }

    my $tripjsonref = json_file_to_perl("trip.json") or die "trip.json doesn't exist.\n";
    my %tripjson = %$tripjsonref;
    
    my @namelist = @{$tripjson{$trip}};
    if(!@namelist)
      {
      print_output("ERROR", TRIP_NOT_FOUND);
      return;
      }
    
    my $namelist = "$name ($trip): ";
    while(@namelist)
         {
         my $name = shift(@namelist);
         $namelist .= @namelist ? "$name : " : $name;
         }

    return $namelist;
    }

sub get_trip
    {
    my $search = shift;
    my $searchname;
         
    if   ( $search =~ /^name (.+)$/ ) { $searchname = encode("utf8", $1); }
    elsif( $search =~ /^(\d{1,4})$/ ) { $searchname = encode("utf8", $userdata->get_name($1)); }
    else { $searchname = encode("utf8", $search); }
         
    ### Load trip.txt
    open(TRIPJSON, "<", "trip.json");
    my $tripjson = <TRIPJSON>;
    close(TRIPJSON);
    
    $tripjson = decode_json($tripjson);
         
    ### Search for name in trip.txt
    SEARCHTRIP: foreach my $trip (keys %{$tripjson})
        {
        my $match;
        SEARCHNAME: foreach my $name (@{$tripjson->{$trip}})
            {
            if ($name eq $searchname)
               {
               print_output("SEARCH", get_name($trip));
               next SEARCHTRIP;
               }
            }        
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
### TODO:
###
### - Make a separate function time return
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
             local $second = time() - $starttime;
             local $minute = int($second / 60);
             $second      %= 60;
             $starttime    = time();
             $remote->close();
             print_output("NOTIFICATION", DISCONNECT);
         };
         local $SIG{"STOP"} = sub {
             %mainroom = ();
             local $second = time() - $starttime;
             local $minute = int($second / 60);
             $second      %= 60;
             $starttime    = time();
             print_output("NOTIFICATION", RELOGIN);
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
           @read = $read =~ /(<.+?>|\+connect id=\d{1,4}|Connection timeout\.\.)/g;
           read_handler(@read);
           }
         }
    }

### Prints user login data and calls user_code 25 to create a sprite, then checks if that users ihash exists
### in stalk or evade and if so, the id is added
###
### Takes:
### - scalar: ENTER or USER
### - scalar: id
### Returns:
### - Nothing
###
sub print_data
    {
    my($enteruser, $id) = @_;
    my($name, $character, $status, $trip, $ihash, $r, $g, $b, $x, $y, $scl);
    local $room = $logindata->get_room2();
    
    ### Get data
    ($name, $character, $status, $trip, $ihash, $r, $g, $b, $x, $y, $scl) = $userdata->get_data($id);# while !$name;
    
    ### Format data
    $scl       = $scl  && $scl  eq '-100'  ? LEFT  : RIGHT; ### Not allowing null scl
    $trip      = $trip && $trip ne  ""     ? " $trip " : " ";
    $enteruser = $enteruser     eq "ENTER" ? ENTER : "\n";
    
    ### Print end line
    if( $option{room} )
      {
      ### Issues:
      ###
      ### - Don't work correctly when there is no </ROOM> signal
      
      #$room = $logindata->get_room2() if !$room; ###
      print_output("ROOM", ROOM);
      $REFRESHMAIN = 1;
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
    
    refresh_listview_users()           if !$CONFIGMENU;
    $name  = "null"                    if !$name;
    $ihash = substr($ihash, 1)         if $config{client_square};
    $tripqueue->enqueue($ihash, $name) if $room ne "main";
    $userdata->set_stalk($id)          if $option{stalk} and $userdata->get_stalk($userdata->get_ihash($id));
    $userdata->set_evade($id)          if $option{evade} and $userdata->get_evade($userdata->get_ihash($id));
    }

### Handles information sent from read_socket()
###
### Takes:
### - scalar: A signal or xml data
### Returns:
### - Nothing
###
sub write_handler
    {
    my $write = shift;
    
    if   ( $write eq "REENTER"  ) { enter_room("REENTER"); }
    elsif( $write =~ /SET trip/ ) { print $remote $write; }
    elsif( $write eq "SETXYSCL" ) { send_x_y_scl($writesocketqueue->dequeue()); }
    elsif( $write eq "SEARCH"   ) { search($writesocketqueue->dequeue()); }
    elsif( $write eq "SHUTUP"   ) { for (1..9) { print $remote encode("utf8", qq{<RSET cmd="go" param="$_" />\0}); } }
    elsif( $write eq "PING" )     { print $remote encode("utf8", qq{<NOP />\0}); }
    elsif( $write eq "DISCONNECT" )
         {
         print $remote
            encode("utf8", qq{<EXIT />\0}),
            encode("utf8", qq{<NOP />\0}),
            encode("utf8", qq{<NOP />\0});
         }
    elsif( $write eq "STAT"     )
         {
         my $status = $writesocketqueue->dequeue();
         print $remote encode("utf8", qq{<SET stat="$status" />\0});
         }
    elsif( $write eq "IGNORE"   )
         {
         my $id    = $writesocketqueue->dequeue();
         my $ihash = $userdata->get_ihash($id);
         my $stat  = $userdata->get_ignore($ihash, $id) ? "off" : "on";
         print $remote encode("utf8", qq{<IG ihash="$ihash" stat="$stat" />\0});
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
         ### If it doesn't end in > (signal is not complete) and isn't "MojaChat" get the second part
         $write .= $writesocketqueue->dequeue() if ($write !~ />$/) and ($write ne "MojaChat"||"");
         chomp($write);
         print $remote encode("utf8", "$write\0") if $select->can_write();
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
sub read_handler
    {
    my @read = @_;
    while( @read )
         {
         print_output("NOTIFICATION", $read[0]) if $option{debug};
         if   ( $read[0] =~ /\+connect id=\d{1,4}/ ) {}
         elsif( $read[0] =~ /<CONNECT id="(.+?)" \/>/ )
              {
              ### Set own id
              $logindata->set_id($1);
              print_output("LOGIN", LOGGED_IN);
              }
         elsif( $read[0] =~ /<ENTER id="(.+?)" \/>/ )
              {
              ### Add user to room user list
              $roomid{$1}   = 1;
              
              my $name      = $userdata->get_name($1);
              my $ihash     = $userdata->get_ihash($1);
              my $enterroomid = ENTER_ROOM_ID;
              
              #my $nameihash = $name =~ /^\s+$/ ? $ihash : "$name $ihash";
              $enterroomid   .= " (Maybe it's $name $ihash ?)" if $ihash;
              print_output("ENTER", $enterroomid) if $logindata->get_room2() eq "main";
              }
         elsif( $read[0] =~ /<UINFO name="(.*?)" id="(\d{1,4})" \/>/ )
              {
              print_output("ROOM", UINFO) if $logindata->get_room2() eq "main";
              ### Allow main screen refreshing
              $REFRESHMAIN = 1;
              }
         elsif( $read[0] eq "<ROOM>" ) ### Sent when you enter the room
              {
              ### ?
              #$option{room} = 1;
              #my $room2 = $logindata->get_room2();
              #print_output("ROOM", ROOM);
              #$REFRESHMAIN = 1;
              }
         elsif( $read[0] eq "<ROOM />" ) {} ### Sent when you exit the room
         elsif( $read[0] =~ /<ROOM c="(.+?)" n="(.+?)" \/>/ ) ### There is a necessity for this one?
              {
              my $room = $logindata->get_room2();
              #print_output("ROOM", ROOM_USER) if $option{roominfo} or $room eq "main" and $1 != 0;
              $mainroom{$2} = $1 if $1 != 0;
              
              ### Refresh main screen
              refresh_main() if $REFRESHMAIN; ### if $logindata->get_room2() eq "main";
              }
         elsif( $read[0] eq "</ROOM>" ) {} ### Sent when sending the room user list
         elsif( $read[0] =~ /<COUNT>/ )
              {
              while( $read[0] !~ /<\/COUNT>/ )
                   {
                   $mainroom{$2} = $1 if $read[0] =~ /<ROOM c="(.+?)" n="(.+?)" \/>/ and $1 != 0;
                   
                   ### Refresh main screen
                   refresh_main() if $REFRESHMAIN;
                   shift(@read);
                   }
              }
         elsif( $read[0] =~ /<\/COUNT>/  ) {} ### In main
         #elsif( $read[0] =~ /<COUNT \/>/ ) {} ### Is this necessary?
         elsif( $read[0] =~ /<COUNT c="(.+?)" n="(.+?)"\s?\/?>/ )
              {
              ### Text corruption before encode triggers warnings
              #no warnings;
              print_output("ROOM", ROOM_USER) if $option{roominfo};
              
              ### Set SDL event data
              $eventdata{room}    = $2;
              $eventdata{persons} = $1;
              
              ### And main to refresh
              $REFRESHMAIN = 1;
              
              ### Format main window title
              my $id    = $logindata->get_id();
              my $name  = $userdata->get_name($id)  || "";
              my $ihash = $userdata->get_ihash($id) || "";
              my $title = TITLE_ROOM." @ $name $ihash ($id)";
              $title    = encode("cp932", $title);
              $window->Text($title);
              
              ### And push event to SDL queue
              push_event(24) if $ENABLE_GRAPHIC_INTERFACE;
              }
         elsif( $read[0] =~ m/<(\w{4,5})\s r="(.*?)"\s name="(.*?)"\s(.+?)stat="(.*?)"\s g="(.*?)"\s
                              type="(.*?)"\s b="(.*?)"\s y="(.*?)"\s x="(.*?)"\s scl="(.*?)"\s\/>/x )
              {
              my($enteruser, $name, $idtripihash, $character, $status, $r, $g, $b, $x, $y, $scl) =
                ($1, $3, $4, $7, $5, $2, $6, $8, $10, $9, $11);
              my $id    = $idtripihash =~ /id="(\d{1,4})"/  ? $1 : "";
              my $trip  = $idtripihash =~ /trip="(.{10})"/  ? $1 : "";
              my $ihash = $idtripihash =~ /ihash="(.{10})"/ ? $1 : "";
              
              $userdata->set_data($name, $id, $character, $status, $trip, $ihash, $r, $g, $b, $x, $y, $scl);
              print_data($enteruser, $id);
              }
         elsif( $read[0] =~ /<SET stat="(.*?)" id="(.+?)" \/>/ )
              {
              local($status, $id) = ($1, $2);
              local $name        = $userdata->get_name($id);
              local $trip        = $userdata->get_trip($id);
              local $ihash       = $userdata->get_ihash($id);
              local $hexrgb      = $userdata->get_hex_rgb($id);
              $trip              = $trip ne "" ? " $trip " : " ";
              
              $userdata->set_status($status, $id);
              print_output("CHANGE", "USERCOLOR", $hexrgb, CHANGE_STAT) if !$option{mute} and !$mute{$id};
              
              ### Push event to SDL event queue
              push_event(24) if $ENABLE_GRAPHIC_INTERFACE;
              }
         elsif( $read[0] =~ /<SET x="(.*?)" scl="(.*?)" id="(\d{1,4})" y="(.*?)" \/>/ )
              {
              ### -100 isn't numeric
              #no warnings;
              local($x, $scl, $id, $y) = ($1, $2, $3, $4);
              local $name              = $userdata->get_name($id);
              local $trip              = $userdata->get_trip($id);
              local $ihash             = $userdata->get_ihash($id);
              my $loginid              = $logindata->get_id();
              my $hexrgb               = $userdata->get_hex_rgb($id);
              $trip                    = $trip ? " $trip " : " ";
              
              ### Check if x, y or scl have changed
              if( $userdata->get_x($id) ne $x )
                {
                $userdata->set_x($x, $id);
                print_output("CHANGE", "USERCOLOR", $hexrgb, SET_X) if !$option{mute} and !$mute{$id};
                }
              if( $userdata->get_y($id) ne $y )
                {
                $userdata->set_y($y, $id);
                print_output("CHANGE", "USERCOLOR", $hexrgb, SET_Y) if !$option{mute} and !$mute{$id};
                }
              if( $userdata->get_scl($id) ne $scl )
                {
                $userdata->set_scl($scl, $id);
                $scl = $scl == 100 ? RIGHT : LEFT;
                print_output("CHANGE", "USERCOLOR", $hexrgb, SET_SCL) if !$option{mute} and !$mute{$id};
                }
              
              ### Send event to SDL queue
              push_event(27, $id) if $ENABLE_GRAPHIC_INTERFACE;
              
              ### Stalk or evade
              if( $option{stalk} and !$option{nomove} and $userdata->get_stalk($id) )
                {
                my $line = "x$x"."y$y"."scl$scl";
                send_x_y_scl($line);
                }
              if( $option{evade} and $userdata->get_evade($id) )
                {
                if( $userdata->get_x($id) - $x < 40 and $userdata->get_x($id) - $x > -40 )
                  { $userdata->set_x(680-$x+40, $loginid); }
                if( $userdata->get_y($id) - $y < 40 and $userdata->get_y($id) - $y > -40 )
                  { $userdata->set_y(320-$y+240, $loginid); }
                send_x_y_scl();
                }
              }
         elsif( $read[0] =~ /<IG ihash="(.{10})" stat="(.+)" id="(\d{1,4})" \/>/ )
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
              
              ### Relogin if antiignore is on and have been ignored
              login() if ($option{antiignore} and $userdata->get_antiignore($id)) or $option{antiignoreall};
              }
         elsif( $read[0] =~ /<RSET cmd="go" param="(.+)" id="(\d{1,4})" \/>/ )
              {
              my $hexrgb = $userdata->get_hex_rgb($2);
              print_output("RSET", "USERCOLOR", $hexrgb, SAITAMA) if !$option{mute};
              }
         elsif( $read[0] =~ /^<SET cmd="play" id="(\d{1,4}) \/>/ ) {}
         elsif( $read[0] =~ /^<SET cmd="ev".+?\/>/ )
              {
              ### <SET cmd="ev" id="\d{1,4}" />
              ### <SET cmd="ev" pre="0" param="0" id=\d{1,4} />
              ### <SET cmd="ev" pre="0|1" param="0|1" id="\d{1,4}" />
              ### <SET cmd="ev" set="start|wait" param="start|wait" id="\id{1,4}" />
              #if( !$option{mute} and !$mute{$id} ) { print_output("NOTIFICATION", $read[0]) };
              }
         elsif( $read[0] eq "<EXIT />" )
              {
              print_output("EXIT", EXIT_ROOM);
              
              ### Refresh user list in listview
              refresh_listview_users() if !$CONFIGMENU;
              
              ### Empty room user list
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
              
              ### Delete that user from room users list
              delete $roomid{$id};
              
              ### Refresh character and listview
              push_event(26, $id)      if $ENABLE_GRAPHIC_INTERFACE;
              refresh_listview_users() if !$CONFIGMENU;
              }
         elsif( $read[0] =~ /<COM cmt="(.+?)".+?id="(.+?)".+?\/>/ ) ### There are three comment patterns
              {
              #<COM cmt"(.+?)" id="(.+?)" cnt="(.+?)" \/>
              #<COM cmt="(.+?)" cnt="(.+?)" id="(.+?)" \/>
              #<COM cmt="(.+?)" id="(.+?)" \/>
              #<SET cmd="com" pre="" param="(.+?)" id=(\d{1,4}) \/>
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
              
              ### Store url if there is one
              if   ( $comment =~ m{^((?:(?:[^:/?#]+):)?(?://(?:[^/?#]*))?(?:[^?#]*)(?:\?(?:[^#]*))?(?:#(?:.*))?)} )
                   { $option{url} = $1; }
              
              ### Print comment
              if( !$mute{"com$id"} ) {
                  print_output("COMMENT", "USERCOLOR", $hexrgb, $date, $name, $trip, $ihash, $id, "$comment\n");
              }
              
              ### Stalk if the id is the same
              if ( $option{stalk} and $userdata->get_stalk($id) )
                 {
                 $writesocketqueue->enqueue("<COM cmt=\"$comment\" />");
                 }
                 
              ### Search for the comment for triggers and show a popup if matches
              if( $option{popup} )
                {
                chomp($line);
                $line = substr($line, 11);
                $line = encode("cp932", $line);
                
                if   ($option{popupall})
                     {
                     $notifyicon->Change("-balloon_tip", $line);
                     $notifyicon->ShowBalloon();
                     }
                else {
                     foreach my $trigger (@{$config{client_trigger}})
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
                   {
                   print_output("ROOM", ROOM_USER) if $1 != 0;
                   $REFRESHMAIN = 1;
                   }
              elsif( $line =~ m/<(\w{4,5})\s r="(.*?)"\s name="(.*?)"\s(.+?)stat="(.*?)"\s g="(.*?)"\s
                                type="(.*?)"\s b="(.*?)"\s y="(.*?)"\s x="(.*?)"\s scl="(.*?)"\s \/>/x )
                   {
                   my($enteruser, $name, $idtripihash, $character, $status, $r, $g, $b, $x, $y, $scl) =
                     ($1, $3, $4, $7, $5, $2, $6, $8, $10, $9, $11);
                   my $id    = $idtripihash =~ /id="(\d{1,4})"/  ? $1 : "";
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
### - array: @ARGV
### Returns:
### - Nothing
###
sub get_argument
    {
    while( @ARGV )
         {
         if( $ARGV[0] =~ m/(-proxy|-timeout|-ip|-port|-debug|-change|-skip|-name|
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
           $1 eq "-name"      ? $argument{name}      = decode("cp932", $ARGV[0]) :
           $1 eq "-character" ? $argument{character} = decode("cp932", $ARGV[0]) :
           $1 eq "-status"    ? $argument{status}    = decode("cp932", $ARGV[0]) :
           $1 eq "-trip"      ? $argument{trip}      = deocde("cp932", $ARGV[0]) :
           $1 eq "-x"         ? $argument{x}         = $ARGV[0] :
           $1 eq "-y"         ? $argument{y}         = $ARGV[0] :
           $1 eq "-scl"       ? $argument{scl}       = $ARGV[0] :
           $1 eq "-attrib"    ? $argument{attrib}    = $ARGV[0] :
                                undef;
           }
         elsif( $ARGV[0] eq "-rgb" )
              {
              shift(@ARGV); $argument{r} = $ARGV[0];
              shift(@ARGV); $argument{g} = $ARGV[0];
              shift(@ARGV); $argument{b} = $ARGV[0];
              }
         elsif( $ARGV[0] eq "-new" )
              { $NEWINSTANCE = 1; }
         elsif( $ARGV[0] eq "-site" )
              {
              shift(@ARGV);
              $argument{site} =
                  $ARGV[0] == 1 ? "socksproxy" :
                  $ARGV[0] == 2 ? "socksproxylist" :
                  undef;
              }
         elsif( $ARGV[0] eq "-room" )
              {
              shift(@ARGV);
              if( $ARGV[0] =~ m/iriguchi|atochi|ooheya|chibichato|moa|chiikibetsu|wadaibetsu|
                                tateyokoheya|cool|kanpu|monafb/x )
                { ($argument{room1}, $argument{port}) = get_server($ARGV[0]); }
              shift(@ARGV) if $argument{room1};
              $argument{room2} = $ARGV[0];
              }
         else { die "Command not recognized: $ARGV[0].\n"; }
         shift(@ARGV);
         }
    }
    

#------------------------------------------------------------------------------------------------------------------#
# SDL                                                                                                              #
#------------------------------------------------------------------------------------------------------------------#

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
         my $character = "lib//character//" . $userdata->get_character($id) . ".png"; ### Not tested
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
sub sdl_window {
    my %roomdata; ### Local variable used to store sprites in the current room
    my $window = SDLx::App->new(
        width  => 620,
        height => 320,
        name   => "Monachat"
    );
    $window->update();
    $window->add_event_handler(\&event_handler);
    $window->run();
}


#------------------------------------------------------------------------------------------------------------------#
# Global variable declaration and config loading                                                                   #
#------------------------------------------------------------------------------------------------------------------#

### SDL constants
sub SDL_QUIT            { 12 }
sub SDL_KEYDOWN         { 2 }
sub SDL_MOUSEBUTTONDOWN { 6 }
sub SDL_MOUSEBUTTONUP   { 9 }
sub SDL_BUTTON_LEFT     { 1 }

### Global shared variables
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
share(%mainroom);
share(%search);

### TODO: Make a hash
### Global local variables
$INPUTCOUNTER = 0;         ### Counter for @inputline
$FIRSTCOPIED  = 0;
$CONFIGMENU   = 0;         ### Config menu opened/closed
$FIRSTSCROLL  = 0;         ### Wether to scroll at the end when outputfield is updated
$REFRESHMAIN  = 1;         ### Wether to refresh screen when a room is updated, can mess with search
$WINDOWHEIGHT = 320;       ### Main window height 
$WINDOWWIDTH  = 617;       ### Main window width
$CANRESIZE    = 0;
$NEWINSTANCE  = 0;         ### Put in a hash
$MINIMIZED    = 0;

### Get command line arguments
get_argument();

### Set display mode
if   ( $config{graphic_displaymode} == 1 )
     {
     ($LOGINSPACE, $ROOMSPACE) =
         $LANGUAGE eq "japanese" ?
         (" " x 73, " " x 90) :
         (" " x 82, " " x 87);
     }
elsif( $config{graphic_displaymode} == 2 )
     {
     ($LOGINSPACE, $ROOMSPACE) =
         $LANGUAGE eq "japanese" ?
         (" " x 70, " " x 86) :
         (" " x 82, " " x 87);
     }

### Initial login data
$logindata = Userdata->new_login_data(
    $argument{name}      || $config{default_name},
    $argument{character} || $config{default_character},
    $argument{status}    || $config{default_status},
    $argument{trip}      || $config{default_trip},
    $argument{r}         || $config{default_r},
    $argument{g}         || $config{default_g},
    $argument{b}         || $config{default_b},
    $argument{x}         || $config{default_x},
    $argument{y}         || $config{default_y},
    $argument{scl}       || $config{default_scl},
    $argument{room1}     || $config{default_room1},
    $argument{room2}     || $config{default_room2},
    $argument{attrib}    || $config{default_attrib}
) or die "Couldn't create logindata.\n";

### User data
$userdata =  Userdata->new_user_data() or die "Couldn't create userdata.\n";

%socketdata = (
    address => $argument{address} || $config{socket_address} || "153.122.46.192",
    port    => $argument{port}    || $config{socket_port}    || 9095
);

%proxy = (
    on      => $argument{proxy}      || $config{socket_proxy}   || 0,
    timeout => $argument{timeout}    || $config{socket_timeout} || 1,
    debug   => $argument{debug}      || $config{socket_debug}   || 0,
    change  => $argument{change}     || $config{socket_change}  || 0,
    site    => $argument{site}       || $config{socket_site}    || "socksproxy",
    skip    => $argument{skip}       || 0,
    version => $config{socksversion} || 4,
);

%option = (
    mute        => $config{client_mute}        || 0,
    popup       => $config{client_popup}       || 0,
    roominfo    => $config{client_roominfo}    || 0,
    displaymode => $config{client_displaymode} || 1,
    popupall    => 0,
    evade       => 0,
    room        => 0,
    readonly    => 1,
    debug       => 0
);
  
$proxy{on}        = $proxy{on}        eq "yes" ? 1 : 0; ###
$proxy{debug}     = $proxy{debug}     eq "yes" ? 1 : 0; ###

$clipboard        = Win32::Clipboard();
$pingsemaphore    = Thread::Semaphore->new(); ### Used to restart ping thread
$eventsemaphore   = Thread::Semaphore->new(); ### Prevents %eventdata being accessed
$writesocketqueue = Thread::Queue->new();     ### Queues socket write requests
$tripqueue        = Thread::Queue->new();     ### Queues trip store requests


#------------------------------------------------------------------------------------------------------------------#
# Main window                                                                                                      #
#------------------------------------------------------------------------------------------------------------------#

$window = Win32::GUI::Window->new(
    -name    => "Window",
    -title   => "Monachat",
    -height  => $WINDOWHEIGHT,
    -width   => $WINDOWWIDTH,
    -minsize => [$WINDOWWIDTH, $WINDOWHEIGHT]
);

if( $config{client_popup} ) {
    #$taskbaricon = Win32::GUI::Icon->new("GUIPERL.ICO");
    $notifyicon  = $window->AddNotifyIcon(
    #    -icon            => $taskbaricon,
        -name            => "NotifyIcon",
        -tip             => "Monachat",
        -balloon         => 1,
        -balloon_timeout => 4
    );
}

$inputfield = $window->AddTextfield(
    -name        => "Inputfield",
    -height      => 30,
    -width       => 560, #598
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
    -autovscroll => 1
    #-class       => "RichEdit20A", ### Japanese characters appear too small
);

$configbutton = $window->AddButton(
    -name   => "ConfigButton",
    -text   => "C",
    -width  => 30,
    -height => 30,
    -left   => 566,
    -top    => 240
);


#------------------------------------------------------------------------------------------------------------------#
# List view                                                                                                        #
#------------------------------------------------------------------------------------------------------------------#

{
no warnings "once"; ### To remove not directly but randomly used variables warnings

$menulistview = $window->AddListView(
    -name   => "MenuListView",
    -width  => 160,
    -height => 260,
    -top    => 10,
    -left   => 610
);

$menulistview->InsertColumn(
    -index => 0,
    -text  => "User menu",
    -width => 150,
);

$optionlistview = $window->AddListView(
    -name   => "OptionListView",
    -width  => 160,
    -height => 260,
    -top    => 10,
    -left   => 610
);

$optionlistview->InsertColumn(
    -index => 0,
    -text  => "Command",
    -width => 150
);

### TODO: Translate
$optionlistview->InsertItem( -text => "Change Profile" );   #0
$optionlistview->InsertItem( -text => "Default" );          #1
$optionlistview->InsertItem( -text => "Search" );           #2
$optionlistview->InsertItem( -text => "Trigger on/off" );   #3
$optionlistview->InsertItem( -text => "Debug on/off" );     #4
$optionlistview->InsertItem( -text => "Roominfo on/off" );  #5
$optionlistview->InsertItem( -text => "Change Language" );  #6
$optionlistview->InsertItem( -text => "Background color" ); #7
$optionlistview->InsertItem( -text => "Proxy on/off" );     #8
$optionlistview->InsertItem( -text => "Proxy timeout" );    #9
$optionlistview->InsertItem( -text => "Proxy skip" );       #10
$optionlistview->InsertItem( -text => "End" );              #11
$optionlistview->InsertItem( -text => "New" );              #12
$optionlistview->InsertItem( -text => "Random" );           #13
$optionlistview->InsertItem( -text => "Server" );           #14
$optionlistview->InsertItem( -text => "Room" );             #15
$optionlistview->InsertItem( -text => "Open url" );         #16
$optionlistview->InsertItem( -text => "Copy url" );         #17
$optionlistview->InsertItem( -text => "Save log" );         #18
$optionlistview->InsertItem( -text => "Reenter" );          #19
$optionlistview->InsertItem( -text => "Relogin" );          #20
$optionlistview->InsertItem( -text => "Disconnect" );       #21

$usermenu = Win32::GUI::Menu->new(
    "User menu"      => "UserMenu",
    ">&Ignore"       => "UserMenuIgnore",
    ">&Antiignore"   => "UserMenuAntiignore",
    ">&Mute"         => "UserMenuMute",
    ">&Mute comment" => "UserMenuMutecom",
    ">&Get name"     => "UserMenuGetname",
    ">&Get trip"     => "UserMenuGettrip",
    ">&Stalk"        => "UserMenuStalk",
    ">&Evade"        => "UserMenuEvade"
);

$profilemenu = Win32::GUI::Menu->new(
    "Profile menu" => "ProfileMenu",
    ">&Profile 1"  => "Profile1",
    ">&Profile 2"  => "Profile2",
    ">&Profile 3"  => "Profile3"
);

$searchmenu = Win32::GUI::Menu->new(
    "Search menu" => "SearchMenu",
    ">&Main"      => "SearchMain",
    ">&All"       => "SearchAll",
    ">&User"      => "SearchUser"
);

$languagemenu = Win32::GUI::Menu->new(
    "Language Menu" => "LanguageMenu",
    ">&English"     => "LanguageEnglish",
    ">&Japanese"    => "LanguageJapanese"
);

$newmenu = Win32::GUI::Menu->new(
    "New Menu" => "NewMenu",
    ">&Main"   => "NewMain",
    ">&Here"   => "NewHere"
);

$logindatalistview = $window->AddListView(
    -name   => "LogindataListView",
    -width  => 160,
    -height => 260,
    -top    => 10,
    -left   => 610
);

$logindatalistview->InsertColumn(
    -index => 0,
    -text  => "Login data",
    -width => 150
);

$logindatalistview->InsertItem( -text => "Name" );       #0
$logindatalistview->InsertItem( -text => "Character" );  #1
$logindatalistview->InsertItem( -text => "Stat" );       #2
$logindatalistview->InsertItem( -text => "Trip" );       #3
$logindatalistview->InsertItem( -text => "RGB" );        #4
$logindatalistview->InsertItem( -text => "x" );          #5
$logindatalistview->InsertItem( -text => "y" );          #6
}


#------------------------------------------------------------------------------------------------------------------#
# Dialog window                                                                                                    #
#------------------------------------------------------------------------------------------------------------------#

$dialog = Win32::GUI::Window->new(
    -name     => "DialogWindow",
    -height   => 160,
    -width    => 290,
    -dialogui => 1
);

$dialoginputfield = $dialog->AddTextfield(
    -name   => "DialogTextField",
    -width  => 160,
    -height => 30,
    -top    => 20,
    -left   => 80
);

$dialog->AddButton(
    -name   => "DialogYes",
    -text   => "Ok",
    -width  => 40,
    -height => 30,
    -top    => 80,
    -left   => 70
);

$dialog->AddButton(
    -name   => "DialogNo",
    -text   => "Exit",
    -width  => 40,
    -height => 30,
    -top    => 80,
    -left   => 160
);


#------------------------------------------------------------------------------------------------------------------#
# GUI options                                                                                                      #
#------------------------------------------------------------------------------------------------------------------#

#$inputfield->SetLimitText(50);                            ### Set inputfield limit to 50 (can't shorten long url)
$inputfield->Hook(WM_CHAR, \&Inputfield_WM_CHAR);          ### To avoid beeps when pressing enter
$inputfield->SetFocus();                                   ### Set focus on inputfield on startup
$outputfield->SetCharFormat( -name => "MS Shell Dlg" );    ### Set font to MS Shell Dlg
$outputfield->SetBkgndColor($config{graphic_backgroundcolor});     ### Set background color
### - $outputfield->Scroll(-1);                            ### Scroll to end

### Enable URL clicking
$outputfield->SetTextMode(1, 1);
$eventmask = $outputfield->GetEventMask();
$outputfield->SetEventMask($eventmask | ENM_LINK);
$outputfield->Hook(EN_LINK, \&Outputfield_URL);
$outputfield->AutoURLDetect();

$menulistview->Hide();      ###
$optionlistview->Hide();    ###
$logindatalistview->Hide(); ###
$dialog->Center();


#------------------------------------------------------------------------------------------------------------------#
# Thread and main window initialization                                                                            #
#------------------------------------------------------------------------------------------------------------------#
 
if( $ENABLE_GRAPHIC_INTERFACE )
  {
  $event           = SDL::Event->new();
  $sdlwindowthread = threads->create(\&sdl_window);
  }

threads->create(\&trip_store);
$pingthread        = threads->create(\&ping);
$readsocketthread  = threads->create(\&read_socket);
$window->Center();
$window->Show();
$CANRESIZE = 1;

Win32::GUI::Dialog();
