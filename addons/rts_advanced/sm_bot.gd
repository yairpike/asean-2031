class_name SMBot
extends RefCounted
## Three personalities. The match applies the plan; this object only describes it.

var personality: StringName = &"bo_mya"
var faction_id: String = "mvd"
var refinery_target: int = 2
var wants_water: bool = true
var wants_gem: bool = true
var tech_kind: StringName = &"arms_bazaar"
var ability: StringName = &"smart_cast"

func _init(p: StringName = &"bo_mya") -> void:
	personality = p
	if p == &"iskandar":
		faction_id = "nmrf"
		tech_kind = &"hydro_radar"
		ability = &"smart_cast"
	elif p == &"tran":
		faction_id = "gtfc"
		tech_kind = &"field_clinic"
		ability = &"channeled_beam"
	else:
		personality = &"bo_mya"
		faction_id = "mvd"
		tech_kind = &"arms_bazaar"
		ability = &"smart_cast"

static func personalities() -> Array[StringName]:
	return [&"bo_mya", &"iskandar", &"tran"]
