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

static func stock_cost(data: Dictionary, building_id: String) -> int:
	var raw: Variant = data.get("buildings", [])
	if raw is Array:
		for item: Variant in raw:
			if item is Dictionary and str(item.get("id", "")) == building_id:
				return int(item.get("rare_earth_cost", 0))
	return 0

static func hex_color(text: String) -> Color:
	return Color.html(text) if text.begins_with("#") else Color.WHITE
