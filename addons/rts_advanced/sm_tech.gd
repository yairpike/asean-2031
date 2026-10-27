class_name SMTechNet
extends RefCounted
## Capturable tech. Imports are flags on the bazaar, not unit meshes.

const CYBER: StringName = &"cyber_scam"
const BAZAAR: StringName = &"arms_bazaar"
const CLINIC: StringName = &"field_clinic"
const RADAR: StringName = &"hydro_radar"
const SALVAGE: StringName = &"salvage"
const DERRICK: StringName = &"derrick"
const BRIDGE: StringName = &"bridge"
const GARRISON: StringName = &"garrison"
const VISION_RADIUS: float = 24.0
const BRIDGE_HP: int = 80
const BAZAAR_CUT: float = 0.05

var sites: Array[Dictionary] = []
var import_flags: Dictionary = {}
var skim_frac: float = 0.0

func add_site(id: StringName, kind: StringName, pos: Vector3) -> void:
	sites.append({
		"id": id,
		"kind": kind,
		"pos": pos,
		"owner": -1,
		"income": 0,
		"siphoned": 0,
		"healed": 0.0,
		"hp": BRIDGE_HP if kind == BRIDGE else 0,
	})

func _find(id: StringName) -> int:
	for i: int in sites.size():
		if StringName(str(sites[i]["id"])) == id:
			return i
	return -1

func capture_at(pos: Vector3, team: int, reach: float) -> StringName:
	var best_i: int = -1
	var best_d: float = reach
	for i: int in sites.size():
		if int(sites[i]["owner"]) >= 0:
			continue
		var spot: Vector3 = sites[i]["pos"]
		var dist: float = pos.distance_to(spot)
		if dist <= best_d:
			best_d = dist
			best_i = i
	if best_i < 0:
		return &""
	var id: StringName = StringName(str(sites[best_i]["id"]))
	if capture(id, team):
		return id
	return &""

func capture(id: StringName, team: int) -> bool:
	var i: int = _find(id)
	if i < 0:
		return false
	var site: Dictionary = sites[i]
	site["owner"] = team
	sites[i] = site
	return true

func owner_of(id: StringName) -> int:
	var i: int = _find(id)
	if i < 0:
		return -1
	return int(sites[i]["owner"])

func advance(delta: float, economy: RTSEconomy, enemy: int) -> void:
	for i: int in sites.size():
		var site: Dictionary = sites[i]
		var owner: int = int(site["owner"])
		if owner < 0:
			continue
		var kind: StringName = StringName(str(site["kind"]))
		if kind == CYBER:
			var gain: int = int(roundf(25.0 * delta))
			if gain > 0:
				economy.earn(owner, gain)
				site["income"] = int(site["income"]) + gain
			var steal: int = mini(int(roundf(4.0 * delta)), economy.credits(enemy))
			if steal > 0 and economy.try_spend(enemy, steal):
				economy.earn(owner, steal)
				site["siphoned"] = int(site["siphoned"]) + steal
		elif kind == CLINIC:
			site["healed"] = float(site["healed"]) + 6.0 * delta
		elif kind == GARRISON:
			var pay: int = int(roundf(8.0 * delta))
			if pay > 0:
				economy.earn(owner, pay)
				site["income"] = int(site["income"]) + pay
		sites[i] = site

func income_of(id: StringName) -> int:
	var i: int = _find(id)
	if i < 0:
		return 0
	return int(sites[i]["income"])

func siphon_of(id: StringName) -> int:
	var i: int = _find(id)
	if i < 0:
		return 0
	return int(sites[i]["siphoned"])

func discount(team: int, tag: String) -> float:
	if tag != "drone" and tag != "infantry":
		return 1.0
	for i: int in sites.size():
		if StringName(str(sites[i]["kind"])) == BAZAAR and int(sites[i]["owner"]) == team:
			return 0.8
	return 1.0

func holds(kind: StringName, team: int) -> bool:
	for i: int in sites.size():
		if StringName(str(sites[i]["kind"])) == kind and int(sites[i]["owner"]) == team:
			return true
	return false

func site_pos(id: StringName) -> Vector3:
	var i: int = _find(id)
	if i < 0:
		return Vector3.ZERO
	return sites[i]["pos"] as Vector3

func bridge_hp(id: StringName) -> int:
	var i: int = _find(id)
	if i < 0:
		return 0
	return int(sites[i].get("hp", 0))

func bridge_alive(id: StringName) -> bool:
	var i: int = _find(id)
	if i < 0:
		return false
	if StringName(str(sites[i]["kind"])) != BRIDGE:
		return false
	return int(sites[i].get("hp", 0)) > 0

func nearest_bridge(pos: Vector3, reach: float) -> StringName:
	var best_i: int = -1
	var best_d: float = reach
	var flat: Vector2 = Vector2(pos.x, pos.z)
	for i: int in sites.size():
		if StringName(str(sites[i]["kind"])) != BRIDGE or int(sites[i].get("hp", 0)) <= 0:
			continue
		var spot: Vector3 = sites[i]["pos"] as Vector3
		var dist: float = flat.distance_to(Vector2(spot.x, spot.z))
		if dist <= best_d:
			best_d = dist
			best_i = i
	if best_i < 0:
		return &""
	return StringName(str(sites[best_i]["id"]))

## Returns true when this hit is the one that drops the span.
func harm_bridge(id: StringName, amount: float) -> bool:
	var i: int = _find(id)
	if i < 0 or amount <= 0.0:
		return false
	var site: Dictionary = sites[i]
	if StringName(str(site["kind"])) != BRIDGE:
		return false
	var hp: int = int(site.get("hp", 0))
	if hp <= 0:
		return false
	hp = maxi(0, hp - int(ceil(amount)))
	site["hp"] = hp
	sites[i] = site
	return hp <= 0

## Owning a bazaar skims 5% of the enemy purse into the owner's purse.
func skim_bazaar(owner_purse: RTSEconomy, foe_purse: RTSEconomy, owner: int, foe: int, delta: float) -> int:
	if owner_purse == null or foe_purse == null or owner == foe:
		return 0
	if not holds(BAZAAR, owner):
		return 0
	var pot: int = foe_purse.credits(foe)
	skim_frac += float(pot) * BAZAAR_CUT * delta
	var steal: int = mini(pot, int(floor(skim_frac + 0.0001)))
	if steal <= 0 or not foe_purse.try_spend(foe, steal):
		return 0
	skim_frac -= float(steal)
	owner_purse.earn(owner, steal)
	for i: int in sites.size():
		if StringName(str(sites[i]["kind"])) == BAZAAR and int(sites[i]["owner"]) == owner:
			var site: Dictionary = sites[i]
			site["siphoned"] = int(site["siphoned"]) + steal
			sites[i] = site
			break
	return steal

func reveals_water(team: int) -> bool:
	return not vision_points(team).is_empty()

func vision_points(team: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i: int in sites.size():
		if StringName(str(sites[i]["kind"])) == RADAR and int(sites[i]["owner"]) == team:
			out.append(sites[i]["pos"] as Vector3)
	return out

func clinic_healed(team: int) -> float:
	var total: float = 0.0
	for i: int in sites.size():
		if StringName(str(sites[i]["kind"])) == CLINIC and int(sites[i]["owner"]) == team:
			total += float(sites[i]["healed"])
	return total

func set_import(flag: String, on: bool) -> void:
	import_flags[flag] = on

func import_open(flag: String) -> bool:
	return bool(import_flags.get(flag, false))
