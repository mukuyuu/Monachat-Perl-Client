package Userdata;
use Encode /encode decode/;
use threads;
use threads::shared /shared_clone/;

sub new_login_data
    {
    $class = shift;
    ($name, $character, $status, $r, $g, $b, $xposition, $yposition, $scl, $attrib) = @_;
    my($self) :shared = shared_clone({ name      => $name||undef,
                     character => $character||undef,
                     status    => $status||undef,
                     r         => $r||undef,
                     g         => $g||undef,
                     b         => $b||undef,
                     xposition => $xposition||undef,
                     yposition => $yposition||undef,
                     scl       => $scl||undef,
                     room1     => $room1||undef,
                     room2     => $room2||undef,
                     attrib    => $attrib||undef });
    return bless($self, $class);
    }

sub new_user_data
    {
    $class = shift;
    my($self) :shared = shared_clone({});
    return bless($self, $class);
    }

sub set_name
    {
    ($self, $name, $id) = @_;
    $idname = $id . "name";
    $name = encode("utf8", $name);
    $self->{$idname} = $name;
    }

sub get_name
    {
    ($self, $id) = @_;
    $idname = $id . "name";
    if( $id ) { return $self->{$idname}; }
    else      { return $self->{name}; }
    }

sub set_status
    {
    ($self, $status, $id) = @_;
    $idstatus = $id . "status";
    $status = encode("utf8", $status);
    $self->{$idstatus} = $status;
    }

sub get_status
    {
    ($self, $id) = @_;
    $idstatus = $id . "status";
    if( $id ) { return $self->{$idstatus}; }
    else      { return $self->{status}; }
    }

sub set_character
    {
    ($self, $character, $id) = @_;
    $characterid = $character . "id";
    $character = encode("utf8", $character);
    $self->{$idcharacter} = $character;
    }

sub get_character
    {
    ($self, $id) = @_;
    $characterid = $character . "id";
    if( $id ) { return $self->{$idcharacter}; }
    else { return $self->{character}; }
    }

sub set_id
    {
    ($self, $id) = @_;
    $self->{id} = $id;
    }

sub get_id
    {
    $self = shift;
    return $self->{id};
    }

sub set_trip
    {
    ($self, $trip, $id) = @_;
    $idtrip = $id . "trip";
    $self->{$idtrip} = $trip;
    }

sub get_trip
    {
    ($self, $id) = @_;
    $idtrip = $id . "trip";
    if( $id ) { return $self->{$idtrip}; }
    else      { return $self->{trip}; }
    }

sub set_ihash
    {
    ($self, $ihash, $id) = @_;
    $idihash = $id . "ihash";
    $self->{$idihash} = $ihash;
    }

sub get_ihash
    {
    ($self, $id) = @_;
    $idihash = $id . "ihash";
    if( $id ) { return $self->{$idihash}; }
    else      { return $self->{ihash}; }
    }

sub set_room
    {
    ($self, $room) = @_;
    $self->{room} = $room;
    }

sub get_room
    {
    $self = shift;
    return $self->{room};
    }

sub set_room2
    {
    ($self, $room2) = @_;
    $room2 = encode("utf8", $room2);
    $self->{room2} = $room2;
    }

sub get_room2
    {
    $self = shift;
    return $self->{room2};
    }

sub set_r
    {
    ($self, $r, $id) = @_;
    $idr = $id . "r";
    $self->{$idr} = $r;
    }

sub get_r
    {
    ($self, $id) = @_;
    $idr = $id . "r";
    if( $id ) { return $self->{$idr}; }
    else      { return $self->{r}; }
    }

sub set_g
    {
    ($self, $g, $id) = @_;
    $idg = $id . "g";
    $self->{$idg} = $g;
    }

sub get_g
    {
    ($self, $id) = @_;
    $idg = $id . "g";
    if( $id ) { return $self->{$idg}; }
    else      { return $self->{g}; }
    }

sub set_b
    {
    ($self, $b, $id) = @_;
    $idb = $id . "b";
    $self->{$idb} = $b;
    }

sub get_b
    {
    ($self, $id) = @_;
    $idb = $id . "b";
    if( $id ) { return $self->{$idb}; }
    else      { return $self->{b}; }
    }

sub set_x
    {
    ($self, $x, $id) = @_;
    $idx = $id . "xposition";
    $self->{$idx} = $x;
    }

sub get_x
    {
    ($self, $id) = @_;
    $idx = $id . "xposition";
    if( $id ) { return $self->{$idx}; }
    else      { return $self->{xposition}; }
    }

sub set_y
    {
    ($self, $y, $id) = @_;
    $idy = $id . "yposition";
    $self->{$idy} = $y;
    }

sub get_y
    {
    ($self, $id) = @_;
    $idy = $id . "yposition";
    if( $id ) { return $self->{$idy}; }
    else      { return $self->{yposition}; }
    }

sub set_scl
    {
    ($self, $scl, $id) = @_;
    $idscl = $id . "scl";
    $self->{$idscl} = $scl;
    }

sub get_scl
    {
    ($self, $id) = @_;
    $idscl = $id . "scl";
    if( $id ) { return $self->{$idscl}; }
    else      { return $self->{scl}; }
    }

sub set_attrib
    {
    ($self, $attrib, $id) = @_;
    $idattrib = $id . "attrib";
    $self->{$idattrib} = $attrib;
    }

sub get_attrib
    {
    ($self, $id) = @_;
    $idattrib = $id . "attrib";
    if( $id ) { return $self->{$idattrib}; }
    else      { return $self->{attrib}; }
    }

1;
