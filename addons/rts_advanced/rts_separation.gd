class_name RTSSeparation
extends RefCounted
## Simple unit separation: overlapping units push each other apart on the XZ
## plane. Idle units yield, moving units push through, two moving units
## ignore each other (so a column on one path never stalls). Optional
## `is_free` Callable(Vector3) -> bool keeps pushes off blocked ground.

## Applies one relaxation pass; returns how many pairs overlapped.
static func apply(units: Array, delta: float, strength: float = 8.0, is_free: Callable = Callable()) -> int:
	var overlaps: int = 0
	var n: int = units.size()
	for i: int in n:
		var a: RTSUnit = units[i] as RTSUnit
		if a == null or not a.is_alive():
			continue
		for j: int in range(i + 1, n):
			var b: RTSUnit = units[j] as RTSUnit
			if b == null or not b.is_alive():
				continue
			var d: Vector2 = Vector2(b.position.x - a.position.x, b.position.z - a.position.z)
			var need: float = a.radius + b.radius
			var dist: float = d.length()
			if dist >= need:
				continue
			overlaps += 1
			if a.is_moving() and b.is_moving():
				continue   # columns on the same path would stall; they part on arrival
			var dir: Vector2 = d / dist if dist > 0.0001 else Vector2.RIGHT.rotated(float(i * 7 + j) * 0.9)
			var push: float = minf(need - dist, strength * delta * need)
			var wa: float = 0.0 if a.is_moving() else 1.0   # moving units never yield
			var wb: float = 0.0 if b.is_moving() else 1.0
			var tot: float = wa + wb
			_nudge(a, -dir * push * wa / tot, is_free)
			_nudge(b, dir * push * wb / tot, is_free)
	return overlaps

static func _nudge(u: RTSUnit, off: Vector2, is_free: Callable) -> void:
	var p: Vector3 = u.position + Vector3(off.x, 0, off.y)
	if is_free.is_valid() and not bool(is_free.call(p)):
		return
	u.position = p
