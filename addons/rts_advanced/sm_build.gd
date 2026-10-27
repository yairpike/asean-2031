class_name SMBuildYard
extends RefCounted
## Three construction styles. State only; the scene supplies the meshes.
## SCAFFOLD drains credits while the frame is vulnerable and unlocks the next
## building in a line. INTERNAL builds inside the hub, then places the finished
## shell inside the radius. MOBILE is an amphibious packer that unpacks.

enum Style { SCAFFOLD, INTERNAL, MOBILE }

var style: int = Style.SCAFFOLD
var team: int = 0
var economy: RTSEconomy
var center: Vector3 = Vector3.ZERO
var radius: float = 12.0
var clearance: int = 1
var drain_per_sec: int = 5
var tech_order: Array[StringName] = []
var building_tier: Dictionary[StringName, int] = {}
var building_time: Dictionary[StringName, float] = {}
var finished: Array[StringName] = []
var scaffold_id: StringName = &""
var scaffold_pos: Vector3 = Vector3.ZERO
var scaffold_progress: float = 0.0
var scaffold_time: float = 0.0
var scaffold_hp: float = 0.0
var scaffold_max_hp: float = 0.0
var scaffold_active: bool = false
var vulnerable: bool = false
var drained: int = 0
var queue: Array[StringName] = []
var queue_progress: float = 0.0
var ready: Array[StringName] = []
var placed: Array[StringName] = []
var packer_pos: Vector3 = Vector3.ZERO
var packer_id: int = 1
var unpacked: bool = false
var factory_tier: Dictionary[StringName, int] = {}
var grid: SMDomainGrid
var structure_hp: Dictionary[StringName, float] = {}
var structure_max: Dictionary[StringName, float] = {}
var structure_pos: Dictionary[StringName, Vector3] = {}

func inside(pos: Vector3) -> bool:
	return Vector2(pos.x, pos.z).distance_to(Vector2(center.x, center.z)) <= radius

func can_build(id: StringName) -> bool:
	if finished.has(id) or scaffold_id == id or queue.has(id) or ready.has(id) or placed.has(id):
		return false
	var tier: int = int(building_tier.get(id, 1))
	if style == Style.INTERNAL and tier > clearance:
		return false
	if style == Style.SCAFFOLD:
		var idx: int = tech_order.find(id)
		if idx < 0:
			return false
		if idx > 0 and not finished.has(tech_order[idx - 1]):
			return false
	return true

func begin_scaffold(id: StringName, pos: Vector3, hp: float) -> bool:
	if style != Style.SCAFFOLD or scaffold_active or not can_build(id) or not inside(pos):
		return false
	scaffold_id = id
	scaffold_pos = pos
	scaffold_time = float(building_time.get(id, 4.0))
	scaffold_progress = 0.0
	scaffold_max_hp = hp
	scaffold_hp = hp
	scaffold_active = true
	vulnerable = true
	return true

func damage_scaffold(amount: float) -> void:
	if not scaffold_active:
		return
	scaffold_hp = maxf(0.0, scaffold_hp - amount)
	if scaffold_hp <= 0.0:
		scaffold_active = false
		vulnerable = false
		scaffold_id = &""

func buy_clearance(level: int, cost: int) -> bool:
	if style != Style.INTERNAL:
		return false
	if level != clearance + 1 or level < 2 or level > 3:
		return false
	if economy == null or not economy.try_spend(team, cost):
		return false
	clearance = level
	radius += 6.0
	return true

func queue_internal(id: StringName) -> bool:
	if style != Style.INTERNAL or not can_build(id):
		return false
	queue.append(id)
	return true

func place_finished(id: StringName, pos: Vector3) -> bool:
	if style != Style.INTERNAL or not ready.has(id) or not inside(pos):
		return false
	ready.erase(id)
	placed.append(id)
	finished.append(id)
	structure_pos[id] = pos
	if not structure_hp.has(id):
		structure_hp[id] = _max_hp(id)
	return true

func move_packer(to: Vector3) -> bool:
	if style != Style.MOBILE or unpacked or grid == null:
		return false
	if not grid.move_unit(packer_id, to, SMDomainGrid.Loco.AMPHIBIOUS):
		return false
	packer_pos = to
	return true

func unpack(factory: StringName) -> bool:
	if style != Style.MOBILE or unpacked:
		return false
	unpacked = true
	factory_tier[factory] = 1
	finished.append(factory)
	structure_pos[factory] = packer_pos
	if not structure_hp.has(factory):
		structure_hp[factory] = _max_hp(factory)
	return true

func upgrade_factory(factory: StringName) -> bool:
	if not unpacked or not factory_tier.has(factory):
		return false
	if int(factory_tier[factory]) >= 3:
		return false
	factory_tier[factory] = int(factory_tier[factory]) + 1
	return true

func factory_level(factory: StringName) -> int:
	return int(factory_tier.get(factory, 0))

func advance(delta: float) -> void:
	if style == Style.SCAFFOLD and scaffold_active:
		_advance_scaffold(delta)
	elif style == Style.INTERNAL and not queue.is_empty():
		queue_progress += delta
		var need: float = float(building_time.get(queue[0], 4.0))
		if queue_progress >= need:
			var id: StringName = queue[0]
			queue.remove_at(0)
			queue_progress = 0.0
			ready.append(id)

func _advance_scaffold(delta: float) -> void:
	if economy == null:
		return
	var cost: int = int(roundf(float(drain_per_sec) * delta))
	if cost > 0:
		if not economy.try_spend(team, cost):
			return
		drained += cost
	scaffold_progress += delta
	if scaffold_progress >= scaffold_time and scaffold_time > 0.0:
		var done: StringName = scaffold_id
		finished.append(done)
		structure_pos[done] = scaffold_pos
		structure_hp[done] = maxf(scaffold_hp, 1.0)
		structure_max[done] = maxf(scaffold_max_hp, structure_hp[done])
		scaffold_id = &""
		scaffold_active = false
		vulnerable = false

func living_count() -> int:
	var total: int = 0
	if scaffold_active and scaffold_hp > 0.0:
		total += 1
	for id: StringName in finished:
		if _stored_hp(id) > 0.0:
			total += 1
	if packer_alive():
		total += 1
	return total

func packer_alive() -> bool:
	if style != Style.MOBILE or unpacked:
		return false
	if not structure_hp.has(&"packer"):
		return true
	return structure_hp[&"packer"] > 0.0

func damage_structure(id: StringName, amount: float) -> void:
	if amount <= 0.0:
		return
	if scaffold_active and id == scaffold_id:
		damage_scaffold(amount)
		return
	if id == &"packer" and style == Style.MOBILE and not unpacked:
		if not structure_hp.has(&"packer"):
			structure_hp[&"packer"] = _max_hp(&"packer")
		structure_hp[&"packer"] = maxf(0.0, structure_hp[&"packer"] - amount)
		return
	if not finished.has(id):
		return
	if not structure_hp.has(id):
		structure_hp[id] = _max_hp(id)
	structure_hp[id] = maxf(0.0, structure_hp[id] - amount)

func nearest_living(from: Vector3) -> StringName:
	var best: StringName = &""
	var best_d: float = INF
	if scaffold_active and scaffold_hp > 0.0:
		var scaffold_d: float = from.distance_to(scaffold_pos)
		if scaffold_d < best_d:
			best_d = scaffold_d
			best = scaffold_id
	for id: StringName in finished:
		if _stored_hp(id) <= 0.0:
			continue
		var built_d: float = from.distance_to(position_of(id))
		if built_d < best_d:
			best_d = built_d
			best = id
	if packer_alive():
		var packer_d: float = from.distance_to(packer_pos)
		if packer_d < best_d:
			best = &"packer"
	return best

func structure_alive(id: StringName) -> bool:
	if id == &"packer":
		return packer_alive()
	if scaffold_active and id == scaffold_id and scaffold_hp > 0.0:
		return true
	if finished.has(id):
		return _stored_hp(id) > 0.0
	return false

func position_of(id: StringName) -> Vector3:
	if scaffold_active and id == scaffold_id:
		return scaffold_pos
	if id == &"packer":
		return packer_pos
	if structure_pos.has(id):
		return structure_pos[id]
	return center

func _stored_hp(id: StringName) -> float:
	if structure_hp.has(id):
		return structure_hp[id]
	return 1.0

func _max_hp(id: StringName) -> float:
	if structure_max.has(id):
		return maxf(structure_max[id], 1.0)
	if id == &"packer":
		return 400.0
	return 200.0
