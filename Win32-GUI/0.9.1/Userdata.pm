#-------------------------------------------------------------------------------------------------------------------#
# Userdata.pm                                                                                                       #
#                                                                                                                   #
# Info: Userdata class, contains functions related to structuring and storing monachat user data and other useful   #
#       functions                                                                                                   #
#                                                                                                                   #
# Issues:                                                                                                           #
# - Can't change character when invisible                                                                           #
#-------------------------------------------------------------------------------------------------------------------#

package Userdata;
use Encode qw(encode decode);
use threads;
use threads::shared qw(shared_clone);

### Global variable declaration
$ID_NAME         = '$id."name"';
$ID_CHARACTER    = '$id."character"';
$ID_STATUS       = '$id."status"';
$ID_TRIP         = '$id."trip"';
$ID_IHASH        = '$id."ihash"';
$ID_R            = '$id."r"';
$ID_G            = '$id."g"';
$ID_B            = '$id."b"';
$ID_HEX_RGB      = '$id."hexrgb"';
$ID_X            = '$id."x"';
$ID_Y            = '$id."y"';
$ID_SCL          = '$id."scl"';
$STALK_IHASH     = '"stalk".$self->get_ihash($id)';
$EVADE_IHASH = '"evade".$self->get_ihash($id)';
$ID_IGNORE_IHASH = '$id."ignore".$ihash';
$ID_ANTIIGNORE   = '$id."antiignore"';

### Read configuration file
open(CONFIG, "<", "config.txt");
for my $line (<CONFIG>) { $config{$1} = $2 if $line =~ /^(.+?) = (.+)$/; }
close(CONFIG);

sub new_login_data {
    my $class = shift;
    my($name, $character, $status, $trip, $r, $g, $b, $x, $y, $scl, $room1, $room2, $attrib) = @_;
    my $self :shared = shared_clone( {
        name      => $name      || "",
        character => $character || "",
        status    => $status    || "",
        trip      => $trip      || "",
        r         => $r         || "",
        g         => $g         || "",
        b         => $b         || "",
        x         => $x         || "",
        y         => $y         || "",
        scl       => $scl       || "",
        room1     => $room1     || "",
        room2     => $room2     || "",
        attrib    => $attrib    || "" }
    );
    return bless($self, $class);
}

sub new_user_data
    {
    my $class = shift;
    my $self :shared = shared_clone({});
    return bless($self, $class);
    }

sub set_name
    {
    my($self, $name, $id) = ($_[0], $_[1]||"", $_[2]||"");
    $self->{eval($ID_NAME)} = $name if $id =~ /^\d{1,3}$/;
    }

sub get_name
    {
    my($self, $id) = ($_[0], $_[1]||"");
    return $id =~ /^\d{1,3}$/ ? $self->{eval($ID_NAME)} : $self->{name};
    }

sub set_status
    {
    my($self, $status, $id) = ($_[0], $_[1]||"", $_[2]||"");
    $self->{eval($ID_STATUS)} = $status if $id =~ /^\d{1,3}$/;
    }

sub get_status
    {
    my($self, $id) = ($_[0], $_[1]||"");
    return $id =~ /^\d{1,3}$/ ? $self->{eval($ID_STATUS)} : $self->{status};
    }

sub set_character
    {
    my($self, $character, $id) = ($_[0], $_[1]||"", $_[2]||"");
    $self->{eval($ID_CHARACTER)} = $character if $id =~ /^\d{1,3}$/;
    }

sub get_character
    {
    my($self, $id) = ($_[0], $_[1]||"");
    return $id =~ /^\d{1,3}$/ ? $self->{eval($ID_CHARACTER)} : $self->{character};
    }

sub set_id
    {
    my($self, $id) = ($_[0], $_[1]||"");
    $self->{id} = $id if $id =~ /^\d{1,3}/;
    }

sub get_id
    {
    my $self = shift;
    return $self->{id};
    }

sub set_trip
    {
    my($self, $trip, $id) = ($_[0], $_[1]||"", $_[2]||"");
    return if $trip =~ /.{10}/;
    
    $trip = substr($trip, 1, -1) if $trip =~ /^#/;
    $trip = pack("U*", hex("25C6")).$trip if $config{square};    
    $id =~ /^\d{1,3}$/ ? $self->{eval($ID_TRIP)} = $trip : $self->{trip} = $trip;
    }

sub get_trip
    {
    my($self, $id) = ($_[0], $_[1]||"");
    return $id =~ /^\d{1,3}$/ ? $self->{eval($ID_TRIP)} : $self->{trip};
    }

sub set_ihash
    {
    my($self, $ihash, $id) = ($_[0], $_[1]||"", $_[2]||"");
    return if $ihash =~ /.{10}/;
    
    $ihash = pack("U*", hex("25C7")).$ihash if $config{square};
    $self->{eval($ID_IHASH)} = $ihash if $id =~ /^\d{|,3}$/;
    }

sub get_ihash
    {
    my($self, $id) = ($_[0], $_[1]||"");
    if( $id =~ /^\d{1,3}$/ ) { return $id ? $self->{eval($ID_IHASH)} : $self->{ihash}; }
    }

sub set_room
    {
    my($self, $room) = ($_[0], $_[1]||"");
    $self->{room1} = $room;
    }

sub get_room
    {
    my $self = shift;
    return $self->{room1};
    }

sub set_room2
    {
    my($self, $room2) = ($_[0], $_[1]||"");
    $self->{room2} = $room2;
    }

sub get_room2
    {
    my $self = shift;
    return $self->{room2};
    }

sub set_r
    {
    my($self, $r, $id) = ($_[0], $_[1]||"", $_[2]||"");
    $self->{eval($ID_R)} = $r if $id =~ /^\d{1,3}$/;
    }

sub get_r
    {
    my($self, $id) = ($_[0], $_[1]||"");
    return $id =~ /^\d{1,3}$/ ? $self->{eval($ID_R)} : $self->{r};
    }

sub set_g
    {
    my($self, $g, $id) = ($_[0], $_[1]||"", $_[2]||"");
    $self->{eval($ID_G)} = $g if $id =~ /^\d{1,3}$/;
    }

sub get_g
    {
    my($self, $id) = ($_[0], $_[1]||"");
    return $id =~ /^\d{1,3}$/ ? $self->{eval($ID_G)} : $self->{g};
    }

sub set_b
    {
    my($self, $b, $id) = ($_[0], $_[1]||"", $_[2]||"");
    $self->{eval($ID_B)} = $b if $id =~ /^\d{1,3}$/;
    }

sub get_b
    {
    my($self, $id) = ($_[0], $_[1]||"");
    return $id =~ /^\d{1,3}$/ ? $self->{eval($ID_B)} : $self->{b};
    }

sub set_rgb
    {
    my($self, $r, $g, $b, $id) = ($_[0], $_[1]||"", $_[2]||"", $_[3]||"", $_[4]||"");
    return if $id !~ /^\d{1,3}$/;
    $self->{eval($ID_R)} = $r;
    $self->{eval($ID_G)} = $g;
    $self->{eval($ID_B)} = $b;
    }

sub get_rgb
    {
    my($self, $id) = ($_[0], $_[1]||"");
    $id =~ /^\d{1,3}$/ ?
      return($self->{eval($ID_R)}, $self->{eval($ID_G)}, $self->{eval($ID_B)}) :
      return($self->{r}, $self->{g}, $self->{b});
    }

sub set_hex_rgb
    {
    my($self, $r, $g, $b, $id) = ($_[0], $_[1]||0, $_[2]||0, $_[3]||0, $_[4]||"");
    return if $id !~ /^\d{1,3}$/;
    
    $r = $r =~ /^\d{1,3}$/ ? $r : 0;
    $g = $g =~ /^\d{1,3}$/ ? $g : 0;
    $b = $b =~ /^\d{1,3}$/ ? $b : 0;
    
    $r = unpack("H2", pack("C", $r));
    $g = unpack("H2", pack("C", $g));
    $b = unpack("H2", pack("C", $b));
    $self->{eval($ID_HEX_RGB)} = "#$r$g$b";
    }

sub get_hex_rgb
    {
    my($self, $id) = ($_[0], $_[1]||"");
    return $id =~ /^\d{1,3}$/ ? $self->{eval($ID_HEX_RGB)} : $self->{hexrgb};
    }

sub set_x
    {
    my($self, $x, $id) = ($_[0], $_[1]||"", $_[2]||"");
    $self->{eval($ID_X)} = $x if $id =~ /^\d{1,3}$/;
    }

sub get_x
    {
    my($self, $id) = ($_[0], $_[1]||"");
    return $id =~ /^\d{1,3}$/ ? $self->{eval($ID_X)} : $self->{x};
    }

sub set_y
    {
    my($self, $y, $id) = ($_[0], $_[1]||"", $_[2]||"");
    $self->{eval($ID_Y)} = $y if $id =~ /^\d{1,3}$/;
    }

sub get_y
    {
    my($self, $id) = ($_[0], $_[1]||"");
    return $id =~ /^\d{1,3}$/ ? $self->{eval($ID_Y)} : $self->{y};
    }

sub set_scl
    {
    my($self, $scl, $id) = ($_[0], $_[1]||"", $_[2]||"");
    $self->{eval($ID_SCL)} = $scl if $id =~ /^\d{1,3}$/;
    }

sub get_scl
    {
    my($self, $id) = ($_[0], $_[1]||"");
    return $id =~ /^\d{1,3}$/ ? $self->{eval($ID_SCL)} : $self->{scl};
    }

sub set_x_y_scl
    {
    my($self, $x, $y, $scl) = ($_[0], $_[1]||"", $_[2]||"", $_[3]||"");
    return if $id !~ /^\d{1,3}$/;
    $self->{eval($ID_X)}   = $x;
    $self->{eval($ID_Y)}   = $y;
    $self->{eval($ID_SCL)} = $scl;
    }

sub get_x_y_scl
    {
    my($self, $id) = ($_[0], $_[1]||"");
    $id =~ /^\d{1,3}$/ ?
      return($self->{eval($ID_X)}, $self->{eval($ID_Y)}, $self->{eval($ID_SCL)}) :
      return($self->{x}, $self->{y}, $self->{scl});
    }

sub set_attrib
    {
    my($self, $attrib) = ($_[0], $_[1]||"");
    $self->{attrib} = $attrib;
    }

sub get_attrib
    {
    my $self = shift;
    return $self->{attrib};
    }

sub set_stalk
    {
    my($self, $id) = ($_[0], $_[1]||"");
    if( $id =~ /^\d{1,3}$/ ) { $self->{eval($STALK_IHASH)} = $self->{eval($STALK_IHASH)} ? 0 : 1; }
    }

sub get_stalk
    {
    my($self, $id) = ($_[0], $_[1]||"");
    return $self->{eval($STALK_IHASH)} if $id =~ /^\d{1,3}$/;
    }

sub set_evade
    {
    my($self, $id) = ($_[0], $_[1]||"");
    if( $id =~ /^\d{1,3}$/ ) { $self->{eval($EVADE_IHASH)} = $self->{eval($EVADE_IHASH)} ? 0 : 1; }
    }

sub get_evade
    {
    my($self, $id) = ($_[0], $_[1]||"");
    return $self->{eval($EVADE_IHASH)} if $id =~ /^\d{|.3}$/;
    }

sub set_ignore
    {
    my($self, $ihash, $stat, $id) = ($_[0], $_[1]||"", $_[2]||"", $_[3]||"");
    return if $id !~ /^\d{1,3}$/ or $ihash !~ /^.{10}$/;
    $stat = $stat eq "on"  ? 1 : $stat eq "off" ? 0 : "";
    $self->{eval($ID_IGNORE_IHASH)} = $stat;
    }

sub get_ignore
    {
    my($self, $ihash, $id) = ($_[0], $_[1]||"", $_[2]||"");
    return $self->{eval($ID_IGNORE_IHASH)} if $id =~ /^\d{1,3}$/ and $ihash =~ /^.{10}$/;
    }

sub set_antiignore
    {
    my($self, $id) = ($_[0], $_[1]||"");
    if( $id =~ /^\d{1,3}$/ ) { $self->{eval($ID_ANTIIGNORE)} = $self->{eval($ID_ANTIIGNORE)} ? 0 : 1; }
    }

sub get_antiignore
    {
    my($self, $id) = ($_[0], $_[1]||"");
    return $self->{eval($ID_ANTIIGNORE)} if $id =~ /^\d{1,3}$/;
    }

sub set_data {
    my($self, $name, $id, $character, $status, $trip, $ihash, $r, $g, $b, $x, $y, $scl) =
      ($_[0], $_[1]||"", $_[2]||"", $_[3]||"", $_[4]||"", $_[5]||"", $_[6]||"", $_[7]||0,
       $_[8]||0, $_[9]||0, $_[10]||"", $_[11]||"", $_[12]||"");
    
    return if $id !~ /^\d{1,3}$/;
    
    $ihash = substr($ihash, 4) if $config{tripdigit} == 6;
    if( $config{square} ) {
        $ihash = pack("U*", hex("25C7")).$ihash if $ihash;
        $trip  = pack("U*", hex("25C6")).$trip  if $trip;
    }
    
    $self->{eval($ID_NAME)}      = $name;
    $self->{eval($ID_CHARACTER)} = $character;
    $self->{eval($ID_STATUS)}    = $status;
    $self->{eval($ID_TRIP)}      = $trip =~ /^#/ ? substr($trip, 1, -1) : $trip;
    $self->{eval($ID_IHASH)}     = $ihash;
    $self->{eval($ID_R)}         = $r;
    $self->{eval($ID_G)}         = $g;
    $self->{eval($ID_B)}         = $b;
    $self->{eval($ID_HEX_RGB)}   = $self->set_hex_rgb($r, $g, $b, $id);
    $self->{eval($ID_X)}         = $x;
    $self->{eval($ID_Y)}         = $y;
    $self->{eval($ID_SCL)}       = $scl;
}

sub get_data {
    my($self, $id) = ($_[0], $_[1]||"");
    if ( $id =~ /^\d{1,3}$/ ) {
        return(
            $self->{eval($ID_NAME)},
            $self->{eval($ID_CHARACTER)},
            $self->{eval($ID_STATUS)},
            $self->{eval($ID_TRIP)},
            $self->{eval($ID_IHASH)},
            $self->{eval($ID_R)},
            $self->{eval($ID_G)},
            $self->{eval($ID_B)},
            $self->{eval($ID_X)},
            $self->{eval($ID_Y)},
            $self->{eval($ID_SCL)}
        );
    }
    else {
        return(
            $self->{name},
            $self->{character},
            $self->{status},
            $self->{trip},
            $self->{ihash},
            $self->{r},
            $self->{g},
            $self->{b},
            $self->{x},
            $self->{y},
            $self->{scl},
            $self->{attrib}
        );
    }
}

### Issues:
###
### - Use of uninitialized value at 425
sub get_data_by_ihash
    {
    my($self, $ihash) = ($_[0], $_[1]||"");
    return if $ihash !~ /^.{10}$/;
    
    for my $id (1..300)
        {
        if( $self->{eval($ID_IHASH)} and $self->{eval($ID_IHASH)} eq $ihash )
          { return($self->get_name($id), $id); }
        }
    }

sub set_profile
    {
    my($self, $profile, $loginid) = @_;
    return if $profile !~ /^\d+$/ or $loginid !~ /^\d{1,3}$/;
    
    $profile = "p".$profile;
    my($pname, $pcharacter, $pstatus, $ptrip, $pr, $pg, $pb, $px, $py, $pscl) =
      ($profile."name", $profile."character", $profile."status", $profile."trip",
       $profile."r", $profile."g", $profile."b", $profile."x", $profile."y", $profile."scl");
    
    $self->set_data(
        decode("cp932", $config{$pname}),
        decode("cp932", $loginid),
        decode("cp932", $config{$pcharacter}),
        decode("cp932", $config{$pstatus}),
        decode("cp932", $config{$ptrip}),
        decode("cp932", $self->get_ihash($loginid)),
        decode("cp932", $config{$pr}),
        decode("cp932", $config{$pg}),
        decode("cp932", $config{$pb}),
        decode("cp932", $config{$px}),
        decode("cp932", $config{$py}),
        decode("cp932", $config{$pscl})
      );
    }

sub random
    {
    my($self, $id, $sex, $country) = ($_[0], $_[1]||"", $_[2]||"", $_[3]||"");

    ### Set user agent
    my $useragent = LWP::UserAgent->new();
    $useragent->agent("getnamelist");
    #$useragent->show_progress(1);

    ### Format url
    my $url = "http://namegen.chobitool.com/?sex=$sex&country=$country&middlename=&middlename_cond=fukumu".
              "&middlename_rarity=&middlename_rarity_cond=ika&lastname=&lastname_cond=fukumu&lastname_rarity=".
              "&lastname_rarity_cond=ika&lastname_type=name&firstname=&firstname_cond=fukumu&firstname_rarity=".
              "&firstname_rarity_cond=ika&firstname_type=name";
    
    ### Get it
    my $page = $useragent->get($url);
    $page    = $page->content();
    $page    = decode("utf8", $page);

    ### Set name
    ### Get name data
    my $fullname = $1 if $page =~ /<td class="name">\s+(.+?)\s+<\/td>/;
    my $kana     = $1 if $page =~ /<td class="pron">(.+?)<\/td>/;

    ### Get first and last name
    my($first, $last)         = $fullname =~ /(.+?)\s+(.+)/;
    my($kanafirst, $kanalast) = $kana     =~ /(.+?)\s+(.+)/;

    ### Remove spaces
    $fullname =~ s/\s//;
    $kana     =~ s/\s//;

    ### Sort randomly
    my $rand = rand(10);
    $name =
        $rand < 1              ? $fullname  :
        $rand > 1 && $rand < 3 ? $kana      :
        $rand > 3 && $rand < 4 ? $first     :
        $rand > 4 && $rand < 5 ? $last      :
        $rand > 5 && $rand < 7 ? $kanafirst :
                                 $kanalast;
    
    ### Set character
    my @character = qw{abogado agemona alice anamona aramaki asou bana batu boljoa boljoa3 boljoa4
                       charhan chichon chotto1 chotto2 chotto3 coc2 cock dokuo dokuo2 foppa fusa
                       fuun gaku gakuri gari gerara giko ging ginu gyouza haa haka hat2 hati hati3
                       hati4 hikk hiyoko hokkyoku6 hosh ichi ichi2 ichineko iiajan iyou jien joruju
                       joruju2 kabin kagami kamemona kappappa kasiwa kato kikko2 kita koit koya kunoichi
                       kuromimi kyaku maji marumimi maturi mina miwa mona monaka mora mosamosa1 mosamosa2
                       mosamosa3 mosamosa4 mossari moudamepo mouk mouk1 mouk2 nanyo nezumi nida niku nin3
                       niraime niraime2 niramusume niraneko nyog oni oniini oomimi osa papi polygon ppa2
                       puru ranta remona ri riru ri_man sai sens shaitama shak shob shodai sii2 sika sira
                       siranaiwa sugoi3 sumaso2 suwarifusa tahara tatigiko taxi tibifusa tibigiko tibisii
                       tiraneyo tofu tokei tuu uma unknown2 unko urara usi wachoi welneco2 yamazaki1
                       yamazaki2 yokan zonu zuza};
    my $character = $character[int(rand(scalar @character))];

    ### Set status
    ### Issues: Not working
    #my @status = qw( normal notnormal );
    my $status = ""; #$status[int(rand(scalar @status))];
    
    ### Set trip
    my $trip = rand(10000);
    
    ### Set ihash
    my $ihash = $self->get_ihash($id);
    
    ### Set color
    my($r, $g, $b) = (int(rand(256)), int(rand(256)), int(rand(256)));
    
    ### Set position
    my($x, $y, $scl) = (int(rand(600)), int(rand(600)), rand(2) > 1 ? 100 : -100);
    
    $self->set_data(
        $name,
        $id,
        $character,
        $status,
        $trip,
        $ihash,
        $r,
        $g,
        $b,
        $x,
        $y,
        $scl
      );
    }
sub copy {
    my($self, $id, $loginid) = ($_[0], $_[1]||"", $_[2]||"");
    return if $id !~ /^\d{1,3}$/;
    
    $self->set_data(
        $self->get_name($id),
        $loginid,
        $self->get_character($id),
        $self->get_status($id),
        $self->get_trip($id),
        $self->get_ihash($id),
        $self->get_r($id),
        $self->get_g($id),
        $self->get_b($id),
        $self->get_x($id),
        $self->get_y($id),
        $self->get_scl($id)
    );
}

sub default {
    my($self, $logindata) = @_;
    my $id = $logindata->{id};
    $self->set_data(
        $logindata->{name},
        $logindata->{id},
        $logindata->{character},
        $logindata->{status},
        $logindata->{trip},
        $self->get_ihash($id),
        $logindata->{r},
        $logindata->{g},
        $logindata->{b},
        $logindata->{x},
        $logindata->{y},
        $logindata->{scl}
    );
}

sub invisible {
    my($self, $id) = ($_[0], $_[1]||"");
    $self->set_data("", $id, "", "", "", "", "", "", "", "", "") if $id =~ /^\d{1,3}$/;
}

1;
