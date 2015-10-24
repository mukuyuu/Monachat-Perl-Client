package Userdata;
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
    my($idx) = $id . "xposition";
    $self->{$idx} = $x;
    }

sub get_x
    {
    my($self, $id) = @_;
    my($idx) = $id . "xposition";
	return $id ? $self->{$idx} : $self->{xposition};
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
	return $id ? $self->{$idy} : $self->{yposition};
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

sub get_data
    {
	my($self, $id) = @_;
	if( $id )
	  {
	  my($idname, $idstatus, $idcharacter, $idtrip, $idihash, $idr, $idg, $idb, $idx, $idy, $idscl, $idattrib) =
	    ($id."name", $id."status", $id."character", $id."trip", $id."ihash", $id."r", $id."g", $id."b",
		 $id."xposition", $id."yposition", $id."scl", $id."attrib");
	  return($self->{$idname}, $self->{$idstatus}, $self->{$idcharacter}, $self->{$idtrip}, $self->{$idihash},
	         $self->{$idr}, $self->{$idg}, $self->{$idb}, $self->{$idx}, $self->{$idy}, $self->{$idscl},
			 $self->{$idattrib});
	  }
	else{
	    return($self->{name}, $self->{status}, $self->{character}, $self->{trip}, $self->{ihash}, $self->{r},
		       $self->{g}, $self->{b}, $self->{xposition}, $self->{yposition}, $self->{scl}, $self->{attrib});
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

1;
