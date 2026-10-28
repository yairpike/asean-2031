extends RefCounted
## One named F effect per roster ability. The stat bump stays with the caller.

static func apply(field: SMPointer, u: RTSUnit) -> void:
	if field == null or not is_instance_valid(u):
		return
	var ability: String = str(u.get_meta("ability", ""))
	var foe: RTSUnit = field.nearest_enemy(u.global_position, 28.0)
	if ability == "Slag Molotov":
		u.set_meta("slagged", true)
		_hit(foe, 4.0)
	elif ability == "3D-Print Overdrive":
		u.set_meta("overdrive", true)
	elif ability == "Bunker Lock":
		u.set_meta("bunker", true)
	elif ability == "Magnetic Harpoon Grinder":
		u.set_meta("harpoon", true)
		_hit(foe, 6.0)
	elif ability == "Slag Jump Thruster":
		u.set_meta("jump", true)
	elif ability == "Land Legs":
		u.set_meta("locomotion", "ground")
		u.set_meta("legs", true)
	elif ability == "Inflatable Raft and C4":
		u.set_meta("locomotion", "amphibious")
		u.set_meta("raft", true)
		u.set_meta("mine_at", u.global_position)
	elif ability == "Adrenaline Cloud":
		u.set_meta("cloud", true)
	elif ability == "Evacuate and Lay Mines":
		u.set_meta("mine_at", u.global_position)
	elif ability == "Warlord's Bribe" or ability == "Cash Bribe":
		u.set_meta("bribe", true)
	elif ability == "Salvage Leech Beam":
		u.set_meta("beam_kind", "leech")
	elif ability == "Fiber-Optic Tether":
		u.set_meta("fiber_on", true)
		u.set_meta("beam_kind", "fiber")
	elif ability == "Electro-Stasis Tether" or ability == "Artillery Telemetry Link":
		u.set_meta("beam_kind", "prism")
	elif ability == "Cargo Winch Airlift":
		u.set_meta("airlift", true)
	elif ability == "Chemical Afterburner":
		u.set_meta("afterburner", true)
	elif ability == "Overload Barrage" or ability == "Kris Plasma Rush" or ability == "Premature Discharge":
		_hit(foe, 8.0)
	elif ability == "Sonic Howl" or ability == "Pheromone Bark":
		_slow(foe, 0.55)
		_hit(foe, 6.0)
	elif ability == "Last-Stand Ram" or ability == "Magnetic Hull Breach" or ability == "Electro-Latch Detonate":
		u.set_meta("ram", true)
		_hit(foe, 10.0)
	elif ability == "Ramming Hydro-Shield" or ability == "Nano-Deflector Barrier" or ability == "Ballistic Riot Shield":
		u.set_meta("shielded", true)
	elif ability == "Monsoon Bull-Charge" or ability == "Sprint Skates":
		u.set_meta("charge", true)
	elif ability == "Submersible or Sky-Jet":
		u.set_meta("locomotion", "air")
		u.set_meta("sky", true)
	elif ability == "Spider-Hole Ambush":
		u.set_meta("ambush", true)
	elif ability == "Jet Interceptor" or ability == "Chopper Mode" or ability == "Afterburner Return":
		u.set_meta("locomotion", "air")
		u.set_meta("chopper", true)
	elif ability == "Telekinetic Maelstrom":
		_slow(foe, 0.4)
	elif ability == "Torpedo Fan Spread" or ability == "Stand-Off Glide Barrage":
		_hit(foe, 12.0)
	elif ability == "S.H.R.I.N.K. Ray":
		if foe != null:
			field.apply_status(foe, "shrunk", 5.0)
	elif ability == "Eject and Repair" or ability == "Field Medical Tent":
		u.set_meta("tent", true)
	elif ability == "Target Painter" or ability == "Laser Target Lock" or ability == "Satellite Laser Designation":
		u.set_meta("beam_kind", "painter")
	elif ability == "Chrono-Phase Recall" or ability == "Emergency Evasive Return":
		_recall(u)
	elif ability == "Aegis Dome":
		u.set_meta("aegis", true)
	elif ability == "Banyan Hologram":
		u.set_meta("hologram", true)
	elif ability == "Black-Hole Armor":
		field.apply_status(u, "black_hole", 6.0)
	elif ability == "Scrambler" or ability == "Blackout EMP":
		if foe != null:
			foe.set_meta("scrambled", true)
			field.apply_status(foe, "frozen", 1.5)
	elif ability == "Frequency Hop":
		u.set_meta("hop_on", true)
	u.set_meta("f_effect", ability)

static func _hit(foe: RTSUnit, amount: float) -> void:
	if foe != null and is_instance_valid(foe):
		foe.take_damage(amount)

static func _slow(foe: RTSUnit, scale: float) -> void:
	if foe != null and is_instance_valid(foe):
		foe.speed_scale = scale

static func _recall(u: RTSUnit) -> void:
	if u.has_meta("chrono_home"):
		u.global_position = u.get_meta("chrono_home")
	else:
		u.set_meta("chrono_home", u.global_position)
