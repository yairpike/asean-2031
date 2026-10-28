class_name SMBark
extends RefCounted
## Short radio lines for select, move, attack, ability, and under fire.

static func line(kind: StringName, cue: String) -> String:
	var named: String = _named(kind, cue)
	if named != "":
		return named
	return _fallback(cue)

static func _fallback(cue: String) -> String:
	if cue == "move":
		return "Moving."
	if cue == "attack":
		return "Engaging."
	if cue == "ability":
		return "Ability."
	if cue == "hurt":
		return "Under fire."
	return "Ready."

static func _named(kind: StringName, cue: String) -> String:
	if kind == &"militia":
		if cue == "move":
			return "Militia moving."
		if cue == "attack":
			return "Throwing into them."
		if cue == "ability":
			return "Slag Molotov."
		if cue == "hurt":
			return "Militia under fire."
		return "Militia holding."
	if kind == &"slag_hauler":
		if cue == "move":
			return "Truck rolling."
		if cue == "attack":
			return "Drones on the target."
		if cue == "ability":
			return "Print overdrive."
		if cue == "hurt":
			return "Truck taking hits."
		return "Drone truck standing by."
	if kind == &"slag_dozer":
		if cue == "move":
			return "Dozer advancing."
		if cue == "attack":
			return "Leech beam on."
		if cue == "ability":
			return "Salvage leech."
		if cue == "hurt":
			return "Dozer under fire."
		return "Dozer ready."
	if kind == &"jade_mortar":
		if cue == "move":
			return "Skimming out."
		if cue == "attack":
			return "Jets on the target."
		if cue == "ability":
			return "Interceptor up."
		if cue == "hurt":
			return "Technical under fire."
		return "Hover-technical set."
	if kind == &"hub_drone":
		if cue == "move":
			return "Copter shifting."
		if cue == "attack":
			return "Cryo on the target."
		if cue == "ability":
			return "Shrink ray."
		if cue == "hurt":
			return "Copter under fire."
		return "Cryo-copter airborne."
	return ""
