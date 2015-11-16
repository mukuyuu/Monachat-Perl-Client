package Userdata;
use threads;
use threads::shared qw(shared_clone);

sub new_login_data
    {
    my($class) = shift;
    my($name, $character, $status, $trip, $r, $g, $b, $x, $y, $scl, $room1, $room2, $attrib) = @_;
    my($self) :shared = shared_clone( {
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
      attrib    => $attrib    || "" } );
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
    my($self, $name, $id) = ($_[0], $_[1]||"", $_[2]||"");
	if( $id =~ /^\d{1,3}$/ )
	  {
      my($idname) = $id."name";
      $self->{$idname} = $name;
	  }
    }

sub get_name
    {
    my($self, $id) = ($_[0], $_[1]||"");
    my($idname) = $id."name";
    return $id =~ /^\d{1,3}$/ ? $self->{$idname} : $self->{name};
	}

sub set_status
    {
    my($self, $status, $id) = ($_[0], $_[1]||"", $_[2]||"");
    if( $id =~ /^\d{1,3}$/ )
	  {
	  my($idstatus) = $id."status";
      $self->{$idstatus} = $status;
	  }
    }

sub get_status
    {
    my($self, $id) = ($_[0], $_[1]||"");
    my($idstatus) = $id."status";
    return $id =~ /^\d{1,3}$/ ? $self->{$idstatus} : $self->{status};
	}

sub set_character
    {
    my($self, $character, $id) = ($_[0], $_[1]||"", $_[2]||"");
	if( $id =~ /^\d{1,3}$/ )
	  {
      my($idcharacter) = $id."character";
      $self->{$idcharacter} = $character;
	  }
    }

sub get_character
    {
    my($self, $id) = ($_[0], $_[1]||"");
    my($idcharacter) = $id."character";
    return $id =~ /^\d{1,3}$/ ? $self->{$idcharacter} : $self->{character};
	}

sub set_id
    {
    my($self, $id) = ($_[0], $_[1]||"");
	if( $id =~ /^\d{1,3}/ ) { $self->{id} = $id; }
    }

sub get_id
    {
    my($self) = shift;
    return $self->{id};
    }

sub set_trip
    {
    my($self, $trip, $id) = ($_[0], $_[1]||"", $_[2]||"");
	if( $id =~ /^\d{1,3}$/ )
	  {
      my($idtrip) = $id."trip";
      $self->{$idtrip} = $trip;
	  }
	else { $self->{trip} = $trip; }
    }

sub get_trip
    {
    my($self, $id) = ($_[0], $_[1]||"");
    my($idtrip) = $id."trip";
	return $id =~ /^\d{1,3}$/ ? $self->{$idtrip} : $self->{trip};
    }

sub set_ihash
    {
    my($self, $ihash, $id) = ($_[0], $_[1]||"", $_[2]||"");
    if( $id =~ /^\d{|,3}$/ )
	  {
	  my($idihash) = $id."ihash";
      $self->{$idihash} = $ihash;
	  }
    }

sub get_ihash
    {
    my($self, $id) = ($_[0], $_[1]||"");
    if( $id =~ /^\d{1,3}$/ )
	  {
	  my($idihash) = $id."ihash";
	  return $id ? $self->{$idihash} : $self->{ihash};
	  }
    }

sub set_room
    {
    my($self, $room) = ($_[0], $_[1]||"");
    $self->{room1} = $room;
    }

sub get_room
    {
    my($self) = shift;
    return $self->{room1};
    }

sub set_room2
    {
    my($self, $room2) = ($_[0], $_[1]||"");
    $self->{room2} = $room2;
    }

sub get_room2
    {
    my($self) = shift;
    return $self->{room2};
    }

sub set_r
    {
    my($self, $r, $id) = ($_[0], $_[1]||"", $_[2]||"");
    if( $id =~ /^\d{1,3}$/ )
	  {
	  my($idr) = $id."r";
      $self->{$idr} = $r;
	  }
    }

sub get_r
    {
    my($self, $id) = ($_[0], $_[1]||"");
    my($idr) = $id."r";
	return $id =~ /^\d{1,3}$/ ? $self->{$idr} : $self->{r};
    }

sub set_g
    {
    my($self, $g, $id) = ($_[0], $_[1]||"", $_[2]||"");
    if( $id =~ /^\d{1,3}$/ )
	  {
	  my($idg) = $id."g";
      $self->{$idg} = $g;
	  }
    }

sub get_g
    {
    my($self, $id) = ($_[0], $_[1]||"");
    my($idg) = $id."g";
	return $id =~ /^\d{1,3}$/ ? $self->{$idg} : $self->{g};
    }

sub set_b
    {
    my($self, $b, $id) = ($_[0], $_[1]||"", $_[2]||"");
    if( $id =~ /^\d{1,3}$/ )
	  {
	  my($idb) = $id."b";
      $self->{$idb} = $b;
	  }
    }

sub get_b
    {
    my($self, $id) = ($_[0], $_[1]||"");
    my($idb) = $id."b";
	return $id =~ /^\d{1,3}$/ ? $self->{$idb} : $self->{b};
    }

sub set_rgb
    {
	my($self, $r, $g, $b, $id) = ($_[0], $_[1]||"", $_[2]||"", $_[3]||"", $_[4]||"");
	if( $id =~ /^\d{1,3}$/ )
	  {
	  my($idr, $idg, $idb) = ($id."r", $id."g", $id."b");
	  $self->{$idr} = $r;
	  $self->{$idg} = $g;
	  $self->{$idb} = $b;
	  }
	}

sub get_rgb
    {
	my($self, $id) = ($_[0], $_[1]||"");
	my($idr, $idg, $idb) = ($id."r", $id."g", $id."b");
	$id =~ /^\d{1,3}$/ ?
	  return($self->{$idr}, $self->{$idg}, $self->{$idb}) :
	  return($self->{r}, $self->{g}, $self->{b});
	}

### Issues:
### - Argument "100" nicms..." isn't numeric in pack at 207
### - Character in 'c' format wrapped in pack at 205
sub set_hex_rgb
    {
	### Why?
	#no warnings;
	my($self, $r, $g, $b, $id) = ($_[0], $_[1], $_[2], $_[3], $_[4]||"");
	if( $id =~ /^\d{1,3}$/ )
	  {
	  my($idhexrgb) = $id."hexrgb";
	  $r = $r =~ /^\d{1,3}$/ ? $r : 0;
	  $g = $g =~ /^\d{1,3}$/ ? $g : 0;
	  $b = $b =~ /^\d{1,3}$/ ? $b : 0;
	  $r = pack("c", $r);
	  $r = unpack("H2", $r);
	  $g = pack("c", $g);
	  $g = unpack("H2", $g);
	  $b = pack("c", $b);
	  $b = unpack("H2", $b);
	  $self->{$idhexrgb} = "#".$r.$g.$b;
	  }
	}

sub get_hex_rgb
    {
	my($self, $id) = ($_[0], $_[1]||"");
	my($idhexrgb) = $id."hexrgb";
	return $id =~ /^\d{1,3}$/ ? $self->{$idhexrgb} : $self->{hexrgb};
	}

sub set_x
    {
    my($self, $x, $id) = ($_[0], $_[1]||"", $_[2]||"");
    if( $id =~ /^\d{1,3}$/ )
	  {
	  my($idx) = $id."x";
      $self->{$idx} = $x;
	  }
    }

sub get_x
    {
    my($self, $id) = ($_[0], $_[1]||"");
    my($idx) = $id."x";
	return $id =~ /^\d{1,3}$/ ? $self->{$idx} : $self->{x};
    }

sub set_y
    {
    my($self, $y, $id) = ($_[0], $_[1]||"", $_[2]||"");
    if( $id =~ /^\d{1,3}$/ )
	  {
	  my($idy) = $id."y";
      $self->{$idy} = $y;
	  }
    }

sub get_y
    {
    my($self, $id) = ($_[0], $_[1]||"");
    my($idy) = $id."y";
	return $id =~ /^\d{1,3}$/ ? $self->{$idy} : $self->{y};
    }

sub set_scl
    {
    my($self, $scl, $id) = ($_[0], $_[1]||"", $_[2]||"");
    if( $id =~ /^\d{1,3}$/ )
	  {
	  my($idscl) = $id."scl";
      $self->{$idscl} = $scl;
	  }
    }

sub get_scl
    {
    my($self, $id) = ($_[0], $_[1]||"");
    my($idscl) = $id."scl";
	return $id =~ /^\d{1,3}$/ ? $self->{$idscl} : $self->{scl};
    }

sub set_x_y_scl
    {
	my($self, $x, $y, $scl) = ($_[0], $_[1]||"", $_[2]||"", $_[3]||"");
	my($idx, $idy, $idscl) = ($id."x", $id."y", $id."scl");
	if( $id =~ /^\d{1,3}$/ )
	  {
	  $self->{$idx}   = $x;
	  $self->{$idy}   = $y;
	  $self->{$idscl} = $scl;
	  }
	}

sub get_x_y_scl
    {
	my($self, $id) = ($_[0], $_[1]||"");
	my($idx, $idy, $idscl) = ($id."x", $id."y", $id."scl");
	$id =~ /^\d{1,3}$/ ?
	  return($self->{$idx}, $self->{$idy}, $self->{$idscl}) :
	  return($self->{x}, $self->{y}, $self->{scl});
	}

sub set_attrib
    {
    my($self, $attrib) = ($_[0], $_[1]||"");
    $self->{attrib} = $attrib;
    }

sub get_attrib
    {
    my($self) = shift;
	return $self->{attrib};
    }

sub set_stalk
    {
	my($self, $id) = ($_[0], $_[1]||"");
	if( $id =~ /^\d{1,3}$/ )
	  {
	  my($stalkihash) = "stalk".$self->get_ihash($id);
	  $self->{$stalkihash} = $self->{$stalkihash} ? 0 : 1;
	  }
	}

sub get_stalk
    {
	my($self, $id) = ($_[0], $_[1]||"");
	if( $id =~ /^\d{1,3}$/ )
	  {
	  my($stalkihash) = "stalk".$self->get_ihash($id);
	  return $self->{$stalkihash};
	  }
	}

sub set_antistalk
    {
	my($self, $id) = ($_[0], $_[1]||"");
	if( $id =~ /^\d{1,3}$/ )
	  {
	  my($antistalkihash) = "antistalk".$self->get_ihash($id);
	  $self->{$antistalkihash} = $self->{$antistalkihash} ? 0 : 1;
	  }
	}

sub get_antistalk
    {
	my($self, $id) = ($_[0], $_[1]||"");
	if( $id =~ /^\d{|.3}$/ )
	  {
	  my($antistalkihash) = "antistalk".$self->get_ihash($id);
	  return $self->{$antistalkihash};
	  }
	}

sub set_ignore
    {
	### Why?
	no warnings;
	my($self, $ihash, $stat, $id) = ($_[0], $_[1]||"", $_[2]||"", $_[3]||"");
	if( $id =~ /^\d{1,3}$/ and $ihash =~ /^.{10}$/ )
	  {
	  my($idignoreihash) = $id."ignore".$ihash;
	  $stat =
	    $stat eq "on"  ? 1 :
	    $stat eq "off" ? 0 : "";
	  $self->{$idignoreihash} = $stat;
	  }
	}

sub get_ignore
    {
	my($self, $ihash, $id) = ($_[0], $_[1]||"", $_[2]||"");
	if( $id =~ /^\d{1,3}$/ and $ihash =~ /^.{10}$/ )
	  {
	  my($idignoreihash) = $id."ignore".$ihash;
	  return $self->{$idignoreihash};
	  }
	}

sub set_antiignore
    {
	my($self, $id) = ($_[0], $_[1]||"");
	if( $id =~ /^\d{1,3}$/ )
	  {
	  my($idantiignore) = $id."antiignore";
	  $self->{$idantiignore} = $self->{$idantiignore} ? 0 : 1;
	  }
	}

sub get_antiignore
    {
	my($self, $id) = ($_[0], $_[1]||"");
	if( $id =~ /^\d{1,3}$/ )
	  {
	  my($idantiignore) = $id."antiignore";
	  return $self->{$idantiignore};
	  }
	}

sub set_data
    {
	my($self, $name, $id, $character, $status, $trip, $ihash, $r, $g, $b, $x, $y, $scl) =
	  ($_[0], $_[1]||"", $_[2]||"", $_[3]||"", $_[4]||"", $_[5]||"", $_[6]|"", $_[7]||0,
	   $_[8]||0, $_[9]||0, $_[10]||"", $_[11]||"", $_[12]||"");
	if( $id =~ /^\d{1,3}$/ )
	  {
	  my($idname, $idcharacter, $idstatus, $idtrip, $idihash, $idr, $idg, $idb, $idhexrgb, $idx, $idy, $idscl) =
	    ($id."name", $id."character", $id."status", $id."trip", $id."ihash", $id."r", $id."g", $id."b", $id."hexrgb",
	     $id."x", $id."y", $id."scl");
	  $self->{$idname}      = $name;
	  $self->{$idcharacter} = $character;
	  $self->{$idstatus}    = $status;
	  $self->{$idtrip}      = $trip;
	  $self->{$idihash}     = $ihash;
	  $self->{$idr}         = $r;
	  $self->{$idg}         = $g;
	  $self->{$idb}         = $b;
	  $self->{$idhexrgb}    = $self->set_hex_rgb($r, $g, $b, $id);
	  $self->{$idx}         = $x;
	  $self->{$idy}         = $y;
	  $self->{$idscl}       = $scl;
	  }
	}

sub get_data
    {
	my($self, $id) = ($_[0], $_[1]||"");
	if( $id =~ /^\d{1,3}$/ )
	  {
	  my($idname, $idcharacter, $idstatus, $idtrip, $idihash, $idr, $idg, $idb, $idx, $idy, $idscl) =
	    ($id."name", $id."character", $id."status", $id."trip", $id."ihash", $id."r", $id."g", $id."b",
		 $id."x", $id."y", $id."scl");
	  return($self->{$idname}, $self->{$idcharacter}, $self->{$idstatus}, $self->{$idtrip}, $self->{$idihash},
	         $self->{$idr}, $self->{$idg}, $self->{$idb}, $self->{$idx}, $self->{$idy}, $self->{$idscl});
	  }
	else {
	     return($self->{name}, $self->{character}, $self->{status}, $self->{trip}, $self->{ihash}, $self->{r},
		        $self->{g}, $self->{b}, $self->{x}, $self->{y}, $self->{scl}, $self->{attrib});
	     }
	}

sub get_data_by_ihash
    {
	### Use of uninitialized value in string eq at 479
	no warnings;
	my($self, $ihash) = ($_[0], $_[1]||"");
	if( $ihash =~ /^.{10}$/ )
	  {
	  for my $id (1..300)
	      {
		  my($idihash) = $id."ihash";
		  if( $self->{$idihash} eq $ihash )
		    { return($self->get_name($id), $id); }
		  }
	  }
	}

sub copy
    {
	my($self, $id, $loginid) = ($_[0], $_[1]||"", $_[2]||"");
	if( $id =~ /^\d{1,3}$/ )
	  {
	  $self->set_data(
	    $self->get_name($id),
	    $loginid,
	    $self->get_character($id),
	    $self->get_status($id),
	    $self->get_trip($id),
	    $self->get_r($id),
	    $self->get_g($id),
	    $self->get_b($id),
	    $self->get_x($id),
	    $self->get_y($id),
	    $self->get_scl($id) );
	  }
	}

sub default
    {
	my($self, $logindata) = @_;
	my($id) = $logindata->{id};
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
	  $logindata->{scl} );
	}

sub invisible
    {
	my($self, $id) = ($_[0], $_[1]||"");
	if( $id =~ /^\d{1,3}$/ ) { $self->set_data("", $id, "", "", "", "", "", "", "", "", ""); }
	}

1;
