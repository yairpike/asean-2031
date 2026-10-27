class_name SMCatalog
extends RefCounted
## Loads faction JSON. Meshes are not created here.

static func faction(id: String) -> Dictionary:
	var path: String = "res://data/factions/%s/faction.json" % id
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	return {}

static func units_of(data: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var raw: Variant = data.get("units", [])
	if raw is Array:
		for item: Variant in raw:
			if item is Dictionary:
				out.append(item)
	return out

static func entry_ok(unit: Dictionary) -> bool:
	var weapon: String = str(unit.get("weapon", ""))
	if weapon == "":
		return false
	return SMAbilities.kind_of(str(unit.get("secondary", ""))) >= 0

static func has_tag(unit: Dictionary, tag: String) -> bool:
	var raw: Variant = unit.get("tags", [])
	if raw is Array:
		for item: Variant in raw:
			if str(item) == tag:
				return true
	return false

static func producer(unit: Dictionary) -> String:
	if has_tag(unit, "hero"):
		return "tech"
	if has_tag(unit, "jet"):
		return "air"
	if has_tag(unit, "sub"):
		return "naval"
	return ""

static func mark_unit(u: RTSUnit, unit: Dictionary) -> void:
	var role: String = str(unit.get("role", ""))
	var hero: bool = has_tag(unit, "hero")
	var crush: bool = not hero and (role == "armor" or role == "artillery" or role == "boat" or role == "amphibious" or role == "air" or role == "vehicle" or role == "hauler")
	u.set_meta("hero", hero)
	u.set_meta("jet", has_tag(unit, "jet"))
	u.set_meta("sub", has_tag(unit, "sub"))
	u.set_meta("crusher", crush)

static func support_ids(faction_id: String, already: Array) -> Array[StringName]:
	var have: Dictionary = {}
	for item: Variant in already:
		have[str(item)] = true
	var out: Array[StringName] = []
	for unit: Dictionary in units_of(faction(faction_id)):
		var id: String = str(unit.get("id", ""))
		if id == "" or bool(have.get(id, false)):
			continue
		if has_tag(unit, "hero") or has_tag(unit, "jet") or has_tag(unit, "sub"):
			out.append(StringName(id))
	return out

static func stock_cost(data: Dictionary, building_id: String) -> int:
	var raw: Variant = data.get("buildings", [])
	if raw is Array:
		for item: Variant in raw:
			if item is Dictionary and str(item.get("id", "")) == building_id:
				return int(item.get("rare_earth_cost", 0))
	return 0

static func hex_color(text: String) -> Color:
	return Color.html(text) if text.begins_with("#") else Color.WHITE
