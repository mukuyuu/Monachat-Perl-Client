package Userdata;
use threads;
use threads::shared qw(shared_clone);

sub new_login_data
    {
    my($class) = shift;
    my($name, $character, $status, $r, $g, $b, $x, $y, $scl, $room1, $room2, $attrib) = @_;
    my($self) :shared = shared_clone({ name      => $name||undef,
                                       character => $character||undef,
                                       status    => $status||undef,
                                       r         => $r||undef,
                                       g         => $g||undef,
                                       b         => $b||undef,
                                       x         => $x||undef,
                                       y         => $y||undef,
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
    $self->{$idname} = $name;
    }

sub get_name
    {
    my($self, $id) = @_;
    my($idname) = $id . "name";
    return $id ? $self->{$idname} : $self->{name};
	}

sub set_status
    {
    my($self, $status, $id) = @_;
    my($idstatus) = $id . "status";
    $self->{$idstatus} = $status;
    }

sub get_status
    {
    my($self, $id) = @_;
    my($idstatus) = $id . "status";
    return $id ? $self->{$idstatus} : $self->{status};
	}

sub set_character
    {
    my($self, $character, $id) = @_;
    my($idcharacter) = $id . "character";
    $self->{$idcharacter} = $character;
    }

sub get_character
    {
    my($self, $id) = @_;
    my($idcharacter) = $id . "character";
    return $id ? $self->{$idcharacter} : $self->{character};
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
	return $id ? $self->{$idtrip} : $self->{trip};
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
	return $id ? $self->{$idihash} : $self->{ihash};
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
	return $id ? $self->{$idr} : $self->{r};
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
	return $id ? $self->{$idg} : $self->{g};
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
	return $id ? $self->{$idb} : $self->{b};
    }

sub set_x
    {
    my($self, $x, $id) = @_;
    my($idx) = $id . "x";
    $self->{$idx} = $x;
    }

sub get_x
    {
    my($self, $id) = @_;
    my($idx) = $id . "x";
	return $id ? $self->{$idx} : $self->{x};
    }

sub set_y
    {
    my($self, $y, $id) = @_;
    my($idy) = $id . "y";
    $self->{$idy} = $y;
    }

sub get_y
    {
    my($self, $id) = @_;
    my($idy) = $id . "y";
	return $id ? $self->{$idy} : $self->{y};
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
	return $id ? $self->{$idscl} : $self->{scl};
    }

sub get_x_y_scl
    {
	my($self, $id) = @_;
	my($idx, $idy, $idscl) = ($id . "x", $id . "y", $id . "sclposition");
	return $id ? ($self->{$idx}, $self->{$idy}, $self->{$idscl}) :
	             ($self->{x}, $self->{y}, $self->{scl});
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
	return $id ? $self->{$idattrib} : $self->{attrib};
    }

sub set_stalk
    {
	my($self, $id) = @_;
	my($stalkihash) = "stalk" . $self->get_ihash($id);
	$self->{$stalkihash} = $self->{$stalkihash} ? 0 : 1;
	}

sub get_stalk
    {
	my($self, $id) = @_;
	my($stalkihash) = "stalk" . $self->get_ihash($id);
	return $self->{$stalkihash};
	}

sub set_antistalk
    {
	my($self, $id) = @_;
	my($antistalkihash) = "antistalk" . $self->get_ihash($id);
	$self->{$antistalkihash} = $self->{$antistalkihash} ? 0 : 1;
	}

sub get_antistalk
    {
	my($self, $id) = @_;
	my($antistalkihash) = "antistalk" . $self->get_ihash($id);
	return $self->{$antistalkihash};
	}

sub set_ignore
    {
	if  ($_[3])
	    {
	    my($self, $ihash, $stat, $id) = @_;
	    my($idignoreihash) = $id . "ignore" . $ihash;
		$stat = $stat == "on" or "off" and $stat == "on" ? 1 : 0;
	    $self->{$idignoreihash} = $stat;
	    }
	else{
	    my($self, $ihash, $id) = @_;
		my($ignoreihashid) = $id . "ignore" . $ihash;
		$self->{$idignoreihash} = $self->{$idignoreihash} ? 0 : 1;
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
	$self->{$idantiignoreihash} = $self->{$idantiignoreihash} ? 0 : 1;
	}

sub get_antiignore
    {
	my($self, $ihash, $id) = @_;
	my($idantiignoreihash) = $id . "antiignore" . $ihash;
	return $self->{$idantiignoreihash};
	}

sub set_data
    {
	my($self, $name, $id, $character, $status, $trip, $ihash, $r, $g, $b, $x, $y, $scl, $attrib) = @_;
	my($idname, $idcharacter, $idstatus, $idtrip, $idihash, $idr, $idg, $idb, $idx, $idy, $idscl, $idattrib) =
	  ($id."name", $id."character", $id."status", $id."trip", $id."ihash", $id."r", $id."g", $id."b", $id."x",
	   $id."y", $id."scl", $id."attrib");
	$self->{$idname}      = $name;
	$self->{$idcharacter} = $character;
	$self->{$idstatus}    = $status;
	$self->{$idtrip}      = $trip;
	$self->{$idihash}     = $ihash;
	$self->{$idr}         = $r;
	$self->{$idg}         = $g;
	$self->{$idb}         = $b;
	$self->{$idx}         = $x;
	$self->{$idy}         = $y;
	$self->{$idscl}       = $scl;
	$self->{$idattrib}    = $attrib;
	}

sub get_data
    {
	my($self, $id) = @_;
	if( $id )
	  {
	  my($idname, $idcharacter, $idstatus, $idtrip, $idihash, $idr, $idg, $idb, $idx, $idy, $idscl, $idattrib) =
	    ($id."name", $id."character", $id."status", $id."trip", $id."ihash", $id."r", $id."g", $id."b",
		 $id."x", $id."y", $id."scl", $id."attrib");
	  return($self->{$idname}, $self->{$idcharacter}, $self->{$idstatus}, $self->{$idtrip}, $self->{$idihash},
	         $self->{$idr}, $self->{$idg}, $self->{$idb}, $self->{$idx}, $self->{$idy}, $self->{$idscl},
			 $self->{$idattrib});
	  }
	else{
	    return($self->{name}, $self->{character}, $self->{status}, $self->{trip}, $self->{ihash}, $self->{r},
		       $self->{g}, $self->{b}, $self->{x}, $self->{y}, $self->{scl}, $self->{attrib});
	    }
	}

sub get_data_by_ihash
    {
	my($self, $ihash) = @_;
	my($ihashid);
	for my $id (1..300)
	    {
		my($idihash) = $id . "ihash";
		if( $self->{$idihash} eq $ihash )
		  { return($self->get_name($id), $id); print "$id\n"; }
		}
	}

sub copy
    {
	my($self, $id, $loginid) = @_;
	my($idname, $idstatus, $idcharacter, $idtrip, $idr, $idg, $idb, $idx, $idy, $idscl, $idattrib) =
	  ($id."name", $id."status", $id."character", $id."trip", $id."r", $id."g", $id."b", $id."x",
	   $id."y", $id."scl", $id."attrib");
	my($loginidname, $loginidstatus, $loginidcharacter, $loginidtrip, $loginidr, $loginidg, $loginidb,
	   $loginidx, $loginidy, $loginidscl, $loginidattrib) =
	  ($loginid."name", $loginid."status", $loginid."character", $loginid."trip", $loginid."r", $loginid."g",
	   $loginid."b", $loginid."x", $loginid."y", $loginid."scl", $loginid."attrib");
	$self->{$loginidname}      = $self->{$idname};
    $self->{$loginidstatus}    = $self->{$idstatus};
    $self->{$loginidcharacter} = $self->{$idcharacter};
    $self->{$loginidtrip}      = $self->{$idtrip};
    $self->{$loginidr}         = $self->{$idr};
    $self->{$loginidg}         = $self->{$idg};
    $self->{$loginidb}         = $self->{$idb};
    $self->{$loginidx}         = $self->{$idx};
    $self->{$loginidy}         = $self->{$idy};
    $self->{$loginidscl}       = $self->{$idscl};
    $self->{$loginidattrib}    = $self->{$idattrib};	
	}

sub default
    {
	my($self, $logindata) = @_;
	my($id) = $logindata->{id};
	my($idname, $idstatus, $idcharacter, $idtrip, $idr, $idg, $idb, $idx, $idy, $idscl, $idattrib) =
	  ($id."name", $id."status", $id."character", $id."trip", $id."r", $id."g", $id."b",
	   $id."x", $id."y", $id."scl", $id."attrib");
	$self->{$idname}      = $logindata->{name};
	$self->{$idstatus}    = $logindata->{status};
	$self->{$idcharacter} = $logindata->{character};
	$self->{$idtrip}      = $logindata->{trip};
	$self->{$idr}         = $logindata->{r};
	$self->{$idg}         = $logindata->{g};
	$self->{$idb}         = $logindata->{b};
	$self->{$idx}         = $logindata->{x};
	$self->{$idy}         = $logindata->{y};
	$self->{$idscl}       = $logindata->{scl};
	$self->{$idattrib}    = $logindata->{attrib};
	}

sub invisible
    {
	my($self, $id) = @_;
	my($idname, $idstatus, $idcharacter, $idtrip, $idr, $idg, $idb, $idx, $idy, $idscl, $idattrib) =
	  ($id."name", $id."status", $id."character", $id."trip", $id."r", $id."g", $id."b",
	   $id."x", $id."y", $id."scl", $id."attrib");
	$self->{$idname}      = undef;
	$self->{$idstatus}    = undef;
	$self->{$idcharacter} = undef;
	$self->{$idtrip}      = undef;
	$self->{$idr}         = undef;
	$self->{$idg}         = undef;
	$self->{$idb}         = undef;
	$self->{$idx}         = undef;
	$self->{$idy}         = undef;
	$self->{$idscl}       = undef;
	$self->{$idattrib}    = undef;
	}

1;
