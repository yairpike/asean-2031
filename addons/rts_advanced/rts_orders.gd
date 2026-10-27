class_name RTSOrders
extends RefCounted
## Turns player intent into unit state: move in formation (pathfinding each unit to
## its slot), attack a target, stop. Pure logic; returns what it assigned.

enum Shape { BOX, LINE }

## Moves `units` to `target` in formation. Returns the slot each unit was sent to.
static func move(units: Array[RTSUnit], target: Vector3, nav: RTSGridNav, shape: Shape = Shape.BOX, spacing: float = 2.0) -> Array[Vector3]:
	var live: Array[RTSUnit] = units.filter(func(u: RTSUnit) -> bool: return is_instance_valid(u) and u.is_alive())
	var sent: Array[Vector3] = []
	if live.is_empty():
		return sent
	var center: Vector3 = Vector3.ZERO
	var positions: Array[Vector3] = []
	for u: RTSUnit in live:
		center += u.global_position
		positions.append(u.global_position)
	center /= live.size()
	var slots: Array[Vector3] = RTSFormation.box(center, target, live.size(), spacing) if shape == Shape.BOX else RTSFormation.line(center, target, live.size(), spacing)
	var pick: Array[int] = RTSFormation.assign(positions, slots)
	for i: int in live.size():
		var u: RTSUnit = live[i]
		u.attack_target = null
		var slot: Vector3 = slots[pick[i]]
		var p: PackedVector3Array = nav.find_path(u.global_position, slot) if nav != null else PackedVector3Array([slot])
		u.set_path(p)
		sent.append(p[p.size() - 1] if not p.is_empty() else u.global_position)
	return sent

## Orders every unit to chase and attack `target` (ignored for allies/self).
static func attack(units: Array[RTSUnit], target: RTSUnit, nav: RTSGridNav, teams: RTSTeams) -> int:
	var n: int = 0
	for u: RTSUnit in units:
		if not is_instance_valid(u) or not u.is_alive() or not teams.are_enemies(u.team, target.team):
			continue
		u.attack_target = target
		u.set_path(nav.find_path(u.global_position, target.global_position) if nav != null else PackedVector3Array([target.global_position]))
		n += 1
	return n

static func stop(units: Array[RTSUnit]) -> void:
	for u: RTSUnit in units:
		if is_instance_valid(u):
			u.stop()
