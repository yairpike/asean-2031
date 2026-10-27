extends RTSUnit
## Shatter and black-hole pull live here so the core unit stays on the plain path.
## A shot still reports the unit it was aimed at. The filter moves the damage.

func take_damage(amount: float) -> void:
	if not is_alive():
		return
	if bool(get_meta("frozen", false)) and amount >= 8.0:
		set_meta("shattered", true)
		hp = 0.0
		path = PackedVector3Array()
		if occupancy != null:
			occupancy.call("remove_unit", get_instance_id())
		died.emit(self)
		return
	super.take_damage(amount)

## Jammer scale first, then a black-hole teammate within 10m takes the hit.
func guard_shot(shooter: RTSUnit, target: RTSUnit, amount: float) -> float:
	var scaled: float = amount
	if has_meta("jammer"):
		var jammer: Callable = get_meta("jammer")
		if jammer.is_valid():
			scaled = float(jammer.call(shooter, target, amount))
	var pulled: RTSUnit = _pull(target)
	if pulled != target and scaled > 0.0:
		pulled.take_damage(scaled)
		return 0.0
	return scaled

func _pull(victim: RTSUnit) -> RTSUnit:
	if victim == null or not is_instance_valid(victim):
		return victim
	if str(victim.get_meta("status", "")) == "black_hole":
		return victim
	var parent_node: Node = victim.get_parent()
	if parent_node == null:
		return victim
	var best: RTSUnit = null
	var best_d: float = 10.0
	for child: Node in parent_node.get_children():
		var other: RTSUnit = child as RTSUnit
		if other == null or other == victim or not other.is_alive():
			continue
		if other.team != victim.team:
			continue
		if str(other.get_meta("status", "")) != "black_hole":
			continue
		var dist: float = Vector2(victim.global_position.x, victim.global_position.z).distance_to(Vector2(other.global_position.x, other.global_position.z))
		if dist <= best_d:
			best_d = dist
			best = other
	if best == null:
		return victim
	return best
