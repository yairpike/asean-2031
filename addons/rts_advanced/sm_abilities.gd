class_name SMAbilities
extends RefCounted
## Primary weapon plus one secondary: group toggle, smart-cast, or channeled beam.
## Slice statuses: frozen, shrunk, black-hole armor.

const TOGGLE: int = 0
const SMART: int = 1
const BEAM: int = 2
const ST_NONE: int = 0
const ST_FROZEN: int = 1
const ST_SHRUNK: int = 2
const ST_BLACK_HOLE: int = 3

var units: Array[Dictionary] = []

static func kind_of(name: String) -> int:
	if name == "group_toggle":
		return TOGGLE
	if name == "smart_cast":
		return SMART
	if name == "channeled_beam":
		return BEAM
	return -1

func add_unit(id: int, pos: Vector3, secondary: int, cooldown: float, radius: float) -> void:
	units.append({
		"id": id,
		"pos": pos,
		"secondary": secondary,
		"cooldown": cooldown,
		"ready": 0.0,
		"toggle": false,
		"channel": 0.0,
		"channeling": false,
		"channel_target": -1,
		"channel_time": 1.5,
		"status": ST_NONE,
		"status_t": 0.0,
		"radius": radius,
		"base_radius": radius,
		"hp": 100.0,
		"alive": true,
		"fired": 0,
		"beam_done": 0,
		"weapon_damage": 10.0,
	})

func index_of(id: int) -> int:
	for i: int in units.size():
		if int(units[i]["id"]) == id:
			return i
	return -1

func advance(delta: float) -> void:
	for i: int in units.size():
		var u: Dictionary = units[i]
		if not bool(u["alive"]):
			continue
		u["ready"] = maxf(0.0, float(u["ready"]) - delta)
		if int(u["status"]) != ST_NONE:
			u["status_t"] = float(u["status_t"]) - delta
			if float(u["status_t"]) <= 0.0:
				u["status"] = ST_NONE
				u["radius"] = float(u["base_radius"])
		if bool(u["channeling"]):
			if int(u["status"]) == ST_FROZEN:
				u["channeling"] = false
				u["channel"] = 0.0
			else:
				u["channel"] = float(u["channel"]) - delta
				if float(u["channel"]) <= 0.0:
					u["channeling"] = false
					u["beam_done"] = int(u["beam_done"]) + 1
					var target: int = int(u["channel_target"])
					units[i] = u
					if target >= 0:
						apply_status(target, ST_FROZEN, 3.0)
					u = units[i]
		units[i] = u

func group_toggle(ids: Array[int]) -> int:
	var n: int = 0
	for id: int in ids:
		var i: int = index_of(id)
		if i < 0:
			continue
		var u: Dictionary = units[i]
		if int(u["secondary"]) != TOGGLE or not bool(u["alive"]) or int(u["status"]) == ST_FROZEN:
			continue
		u["toggle"] = not bool(u["toggle"])
		units[i] = u
		n += 1
	return n

## Only the closest ready unit with a smart-cast secondary fires.
func smart_cast(ids: Array[int], aim: Vector3) -> int:
	var best: int = -1
	var best_d: float = 1.0e20
	for id: int in ids:
		var i: int = index_of(id)
		if i < 0:
			continue
		var u: Dictionary = units[i]
		if int(u["secondary"]) != SMART or not bool(u["alive"]):
			continue
		if float(u["ready"]) > 0.0 or int(u["status"]) == ST_FROZEN:
			continue
		var p: Vector3 = u["pos"]
		var d: float = Vector2(p.x, p.z).distance_to(Vector2(aim.x, aim.z))
		if d < best_d:
			best_d = d
			best = id
	if best < 0:
		return -1
	var bi: int = index_of(best)
	var bu: Dictionary = units[bi]
	bu["ready"] = float(bu["cooldown"])
	bu["fired"] = int(bu["fired"]) + 1
	units[bi] = bu
	return best

func fired_count(id: int) -> int:
	var i: int = index_of(id)
	if i < 0:
		return 0
	return int(units[i]["fired"])

func begin_beam(id: int, target: int) -> bool:
	var i: int = index_of(id)
	if i < 0:
		return false
	var u: Dictionary = units[i]
	if int(u["secondary"]) != BEAM or int(u["status"]) == ST_FROZEN or not bool(u["alive"]):
		return false
	u["channeling"] = true
	u["channel"] = float(u["channel_time"])
	u["channel_target"] = target
	units[i] = u
	return true

func beam_done(id: int) -> int:
	var i: int = index_of(id)
	if i < 0:
		return 0
	return int(units[i]["beam_done"])

func is_channeling(id: int) -> bool:
	var i: int = index_of(id)
	if i < 0:
		return false
	return bool(units[i]["channeling"])

func apply_status(id: int, status: int, duration: float) -> void:
	var i: int = index_of(id)
	if i < 0:
		return
	var u: Dictionary = units[i]
	u["status"] = status
	u["status_t"] = duration
	if status == ST_SHRUNK:
		u["radius"] = float(u["base_radius"]) * 0.5
	if status == ST_FROZEN:
		u["channeling"] = false
	units[i] = u

func status_of(id: int) -> int:
	var i: int = index_of(id)
	if i < 0:
		return ST_NONE
	return int(units[i]["status"])

func radius_of(id: int) -> float:
	var i: int = index_of(id)
	if i < 0:
		return 0.0
	return float(units[i]["radius"])

func toggle_on(id: int) -> bool:
	var i: int = index_of(id)
	if i < 0:
		return false
	return bool(units[i]["toggle"])

func damage_to(id: int, amount: float) -> float:
	var i: int = index_of(id)
	if i < 0:
		return 0.0
	var u: Dictionary = units[i]
	var dealt: float = amount
	if int(u["status"]) == ST_BLACK_HOLE:
		dealt *= 0.2
	elif int(u["status"]) == ST_SHRUNK:
		dealt *= 0.5
	u["hp"] = maxf(0.0, float(u["hp"]) - dealt)
	if float(u["hp"]) <= 0.0:
		u["alive"] = false
	units[i] = u
	return dealt

func hp_of(id: int) -> float:
	var i: int = index_of(id)
	if i < 0:
		return 0.0
	return float(units[i]["hp"])

func set_ready(id: int, seconds: float) -> void:
	var i: int = index_of(id)
	if i < 0:
		return
	var u: Dictionary = units[i]
	u["ready"] = seconds
	units[i] = u
