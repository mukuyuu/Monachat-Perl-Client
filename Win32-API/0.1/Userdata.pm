package Userdata;
use Encode qw(encode decode);
use threads;
use threads::shared qw(shared_clone);

sub new_login_data
    {
    my($class) = shift;
    my($name, $character, $status, $r, $g, $b, $xposition, $yposition, $scl, $room1, $room2, $attrib) = @_;
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
    my($class) = shift;
    my($self) :shared = shared_clone({});
    return bless($self, $class);
    }

sub set_name
    {
    my($self, $name, $id) = @_;
    my($idname) = $id . "name";
    $name = encode("utf8", $name);
    $self->{$idname} = $name;
    }

sub get_name
    {
    my($self, $id) = @_;
    my($idname) = $id . "name";
    if( $id ) { return $self->{$idname}; }
    else      { return $self->{name}; }
    }

sub set_status
    {
    my($self, $status, $id) = @_;
    my($idstatus) = $id . "status";
    $status = encode("utf8", $status);
    $self->{$idstatus} = $status;
    }

sub get_status
    {
    my($self, $id) = @_;
    my($idstatus) = $id . "status";
    if( $id ) { return $self->{$idstatus}; }
    else      { return $self->{status}; }
    }

sub set_character
    {
    my($self, $character, $id) = @_;
    my($idcharacter) = $id . "character";
    $character = encode("utf8", $character);
    $self->{$idcharacter} = $character;
    }

sub get_character
    {
    my($self, $id) = @_;
    my($idcharacter) = $id . "character";
    if( $id ) { return $self->{$idcharacter}; }
    else      { return $self->{character}; }
    }

sub set_id
    {
    my($self, $id) = @_;
    $self->{id} = $id;
    }

sub get_id
    {
    my($self) = shift;
    return $self->{id};
    }

sub set_trip
    {
    my($self, $trip, $id) = @_;
    my($idtrip) = $id . "trip";
    $self->{$idtrip} = $trip;
    }

sub get_trip
    {
    my($self, $id) = @_;
    my($idtrip) = $id . "trip";
    if( $id ) { return $self->{$idtrip}; }
    else      { return $self->{trip}; }
    }

sub set_ihash
    {
    my($self, $ihash, $id) = @_;
    my($idihash) = $id . "ihash";
    $self->{$idihash} = $ihash;
    }

sub get_ihash
    {
    my($self, $id) = @_;
    my($idihash) = $id . "ihash";
    if( $id ) { return $self->{$idihash}; }
    else      { return $self->{ihash}; }
    }

sub set_room
    {
    my($self, $room) = @_;
    $self->{room1} = $room;
    }

sub get_room
    {
    my($self) = shift;
    return $self->{room1};
    }

sub set_room2
    {
    my($self, $room2) = @_;
    $room2 = encode("utf8", $room2);
    $self->{room2} = $room2;
    }

sub get_room2
    {
    my($self) = shift;
    return $self->{room2};
    }

sub set_r
    {
    my($self, $r, $id) = @_;
    my($idr) = $id . "r";
    $self->{$idr} = $r;
    }

sub get_r
    {
    my($self, $id) = @_;
    my($idr) = $id . "r";
    if( $id ) { return $self->{$idr}; }
    else      { return $self->{r}; }
    }

sub set_g
    {
    my($self, $g, $id) = @_;
    my($idg) = $id . "g";
    $self->{$idg} = $g;
    }

sub get_g
    {
    my($self, $id) = @_;
    my($idg) = $id . "g";
    if( $id ) { return $self->{$idg}; }
    else      { return $self->{g}; }
    }

sub set_b
    {
    my($self, $b, $id) = @_;
    my($idb) = $id . "b";
    $self->{$idb} = $b;
    }

sub get_b
    {
    my($self, $id) = @_;
    my($idb) = $id . "b";
    if( $id ) { return $self->{$idb}; }
    else      { return $self->{b}; }
    }

sub set_x
    {
    my($self, $x, $id) = @_;
    my($idx) = $id . "xposition";
    $self->{$idx} = $x;
    }

sub get_x
    {
    my($self, $id) = @_;
    my($idx) = $id . "xposition";
    if( $id ) { return $self->{$idx}; }
    else      { return $self->{xposition}; }
    }

sub set_y
    {
    my($self, $y, $id) = @_;
    my($idy) = $id . "yposition";
    $self->{$idy} = $y;
    }

sub get_y
    {
    my($self, $id) = @_;
    my($idy) = $id . "yposition";
    if( $id ) { return $self->{$idy}; }
    else      { return $self->{yposition}; }
    }

sub set_scl
    {
    my($self, $scl, $id) = @_;
    my($idscl) = $id . "scl";
    $self->{$idscl} = $scl;
    }

sub get_scl
    {
    my($self, $id) = @_;
    my($idscl) = $id . "scl";
    if( $id ) { return $self->{$idscl}; }
    else      { return $self->{scl}; }
    }

sub set_attrib
    {
    my($self, $attrib, $id) = @_;
    my($idattrib) = $id . "attrib";
    $self->{$idattrib} = $attrib;
    }

sub get_attrib
    {
    my($self, $id) = @_;
    my($idattrib) = $id . "attrib";
    if( $id ) { return $self->{$idattrib}; }
    else      { return $self->{attrib}; }
    }

sub set_stalk
    {
	my($self, $on, $id) = @_;
	my($stalkihash) = "stalk" . $self->get_ihash($id);
	$self->{$stalkihash} = $on;
	}

sub get_stalk
    {
	my($self, $id) = @_;
	my($stalkihash) = "stalk" . $self->get_ihash($id);
	return $self->{$stalkihash};
	}

sub set_antistalk
    {
	my($self, $on, $id) = @_;
	my($antistalkihash) = "antistalk" . $self->get_ihash($id);
	$self->{$antistalkihash} = $on;
	}

sub get_antistalk
    {
	my($self, $id) = @_;
	my($antistalkihash) = "antistalk" . $self->get_ihash($id);
	return $self->{$antistalkihash};
	}

sub set_ignore
    {
	if  (@_[3])
	    {
	    my($self, $ihash, $stat, $id) = @_;
	    my($idignoreihash) = $id . "ignore" . $ihash;
	    if   ( $stat ==  "on" ) { $stat = 1; }
	    elsif( $stat == "off" ) { $stat = 0; }
	    $self->{$idignoreihash} = $stat;
	    }
	else{
	    my($self, $ihash, $id) = @_;
		my($ignoreihashid) = $id . "ignore" . $ihash;
		if   ( $self->{$idignoreihash} == 1 ) { $self->{$idignoreihash} = 0; }
		elsif( $self->{$idignoreihash} == 0 ) { $self->{$idignoreihash} = 1; }
		}
	}

sub get_ignore
    {
	my($self, $ihash, $id) = @_;
	my($idignoreihash) = $id . "ignore" . $ihash;
	return $self->{$idignoredihash};
	}

sub set_antiignore
    {
	my($self, $ihash, $id) = @_;
	my($idantiignoreihash) = $id . "antiignore" . $ihash;
	if   ( $self->{$idantiignoreihash} == 0 ) { $self->{$idantiignoreihash} = 1; }
	elsif( $self->{$idantiignoreihash} == 1 ) { $self->{$idantiignoreihash} = 0; }
	}

sub get_antiignore
    {
	my($self, $ihash, $id) = @_;
	my($idantiignoreihash) = $id . "antiignore" . $ihash;
	return $self->{$idantiignoreihash};
	}

sub get_data_by_ihash
    {
	my($self, $ihash) = @_;
	my($ihashid);
	for my $id (1..300)
	    {
		my($idihash) = $id . "ihash";
		if( $self->{$idihash} eq $ihash )
		  { $ihashid = $id; break; }
		}
	return($self->get_name($ihashid), $ihashid);
	}

1;
