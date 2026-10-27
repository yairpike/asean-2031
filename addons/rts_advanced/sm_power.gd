extends RefCounted
## Buildings draw power. A plant covers the draw. Low power stops production.

const PLANT: int = 100
const DRAW: int = 30

static func tally(yard: SMBuildYard) -> Vector2i:
	var gen: int = 0
	var use: int = 0
	if yard == null:
		return Vector2i(gen, use)
	for id: StringName in yard.finished:
		var role: String = str(yard.building_role.get(id, ""))
		if role == "power":
			gen += PLANT
		elif role != "" and role != "yard":
			use += DRAW
	return Vector2i(gen, use)

static func online(yard: SMBuildYard) -> bool:
	var pair: Vector2i = tally(yard)
	return pair.x >= pair.y

static func readout(yard: SMBuildYard) -> String:
	var pair: Vector2i = tally(yard)
	return "Power %d/%d" % [pair.x, pair.y]

static func allows(yard: SMBuildYard, role: String) -> bool:
	if role == "power" or role == "yard":
		return true
	return online(yard)
