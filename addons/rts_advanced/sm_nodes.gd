class_name SMCommodityNet
extends RefCounted
## Five stationary nodes. One refinery per node spawns one collector on a fixed loop.
## Ruby and jade can run a night shift. Rare-earth stock is its own counter.

const KIND_SLAG: StringName = &"precursor_slag"
const KIND_RARE: StringName = &"rare_earth"
const KIND_RUBY: StringName = &"mogok_ruby"
const KIND_JADE: StringName = &"hpakant_jade"
const KIND_BULLION: StringName = &"gold_bullion"

var nodes: Array[Dictionary] = []
var rare_stock: Dictionary[int, int] = {}
var water_harm_per_sec: float = 8.0

static func display_name(kind: StringName) -> String:
	if kind == KIND_SLAG:
		return "Golden Slag / Aurum-9"
	if kind == KIND_RARE:
		return "rare earth"
	if kind == KIND_RUBY:
		return "ruby"
	if kind == KIND_JADE:
		return "jade"
	if kind == KIND_BULLION:
		return "gold bullion"
	return ""

static func all_kinds() -> Array[StringName]:
	return [KIND_SLAG, KIND_RARE, KIND_RUBY, KIND_JADE, KIND_BULLION]

func add_node(id: StringName, kind: StringName, pos: Vector3, rate: int, water_adjacent: bool) -> void:
	nodes.append({
		"id": id,
		"kind": kind,
		"pos": pos,
		"rate": rate,
		"water": water_adjacent,
		"team": -1,
		"collector": false,
		"loop_t": 0.0,
		"loop_time": 4.0,
		"night": false,
		"fog_visible": false,
		"paid": 0,
	})

func find(id: StringName) -> int:
	for i: int in nodes.size():
		if StringName(str(nodes[i]["id"])) == id:
			return i
	return -1

func kind_of(id: StringName) -> StringName:
	var i: int = find(id)
	if i < 0:
		return &""
	return StringName(str(nodes[i]["kind"]))

func claim_at(pos: Vector3, team: int, reach: float) -> StringName:
	var best_i: int = -1
	var best_d: float = reach
	for i: int in nodes.size():
		if int(nodes[i]["team"]) >= 0:
			continue
		var spot: Vector3 = nodes[i]["pos"]
		var dist: float = pos.distance_to(spot)
		if dist <= best_d:
			best_d = dist
			best_i = i
	if best_i < 0:
		return &""
	var id: StringName = StringName(str(nodes[best_i]["id"]))
	if snap_refinery(id, team):
		return id
	return &""

func snap_refinery(id: StringName, team: int) -> bool:
	var i: int = find(id)
	if i < 0:
		return false
	var node: Dictionary = nodes[i]
	if int(node["team"]) >= 0:
		return false
	node["team"] = team
	node["collector"] = true
	nodes[i] = node
	return true

func has_collector(id: StringName) -> bool:
	var i: int = find(id)
	if i < 0:
		return false
	return bool(nodes[i]["collector"])

func release_collector(id: StringName) -> bool:
	var i: int = find(id)
	if i < 0:
		return false
	var node: Dictionary = nodes[i]
	if not bool(node["collector"]):
		return false
	node["team"] = -1
	node["collector"] = false
	node["loop_t"] = 0.0
	nodes[i] = node
	return true

func set_night_shift(id: StringName, on: bool) -> bool:
	var i: int = find(id)
	if i < 0:
		return false
	var node: Dictionary = nodes[i]
	var kind: StringName = StringName(str(node["kind"]))
	if kind != KIND_RUBY and kind != KIND_JADE:
		return false
	node["night"] = on
	node["fog_visible"] = on
	nodes[i] = node
	return true

func night_on(id: StringName) -> bool:
	var i: int = find(id)
	if i < 0:
		return false
	return bool(nodes[i]["night"])

func visible_through_fog(id: StringName) -> bool:
	var i: int = find(id)
	if i < 0:
		return false
	return bool(nodes[i]["fog_visible"])

func advance(delta: float, economy: RTSEconomy) -> int:
	var paid: int = 0
	for i: int in nodes.size():
		var node: Dictionary = nodes[i]
		if not bool(node["collector"]):
			continue
		var speed: float = 2.0 if bool(node["night"]) else 1.0
		var t: float = float(node["loop_t"]) + delta * speed
		var loop: float = float(node["loop_time"])
		var owner: int = int(node["team"])
		var kind: StringName = StringName(str(node["kind"]))
		while t >= loop:
			t -= loop
			if kind == KIND_RARE:
				rare_stock[owner] = rare_stock.get(owner, 0) + 1
			else:
				var amount: int = _credit_payout(kind)
				economy.earn(owner, amount)
				paid += amount
				node["paid"] = int(node["paid"]) + amount
		node["loop_t"] = t
		nodes[i] = node
	return paid

func _credit_payout(kind: StringName) -> int:
	if kind == KIND_BULLION:
		return 400
	return 250

func paid_of(id: StringName) -> int:
	var i: int = find(id)
	if i < 0:
		return 0
	return int(nodes[i]["paid"])

func stock_of(team: int) -> int:
	return rare_stock.get(team, 0)

func try_spend_stock(team: int, amount: int) -> bool:
	if amount < 0 or stock_of(team) < amount:
		return false
	rare_stock[team] = stock_of(team) - amount
	return true

## Unshielded infantry beside a water-adjacent rare-earth node take damage.
func harm_infantry(pos: Vector3, shielded: bool, delta: float) -> float:
	if shielded:
		return 0.0
	for i: int in nodes.size():
		var node: Dictionary = nodes[i]
		if StringName(str(node["kind"])) != KIND_RARE or not bool(node["water"]):
			continue
		var p: Vector3 = node["pos"]
		if Vector2(pos.x, pos.z).distance_to(Vector2(p.x, p.z)) <= 8.0:
			return water_harm_per_sec * delta
	return 0.0
