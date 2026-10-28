class_name RTSSelection
extends RefCounted
## Selection model: box select (screen rect), click select, shift-add, ctrl-toggle,
## control groups (0-9). Only units of `team` are selectable. Screen projection is
## injected (Callable(Vector3) -> Vector2) so this works headless and in tests.

signal changed(units: Array[RTSUnit])

const MIN_BOX_PX: float = 8.0

var team: int = 0
var units: Array[RTSUnit] = []
var groups: Dictionary[int, Array] = {}

func count() -> int:
	_prune()
	return units.size()

func clear() -> void:
	for u: RTSUnit in units:
		if is_instance_valid(u):
			u.selected = false
	units.clear()
	changed.emit(units)

func is_selectable(u: RTSUnit) -> bool:
	return is_instance_valid(u) and u.is_alive() and u.team == team and not bool(u.get_meta("garrisoned", false))

## Units whose projected position lies inside `rect` (normalised, any drag direction).
func units_in_rect(rect: Rect2, candidates: Array, project: Callable) -> Array[RTSUnit]:
	var r: Rect2 = rect.abs()
	var out: Array[RTSUnit] = []
	for n: Variant in candidates:
		var u: RTSUnit = n as RTSUnit
		if is_selectable(u) and r.has_point(project.call(u.global_position)):
			out.append(u)
	return out

## Live count for a drag box (what the overlay shows while dragging).
func preview_count(rect: Rect2, candidates: Array, project: Callable) -> int:
	return units_in_rect(rect, candidates, project).size() if rect.abs().size.length() >= MIN_BOX_PX else 0

## Replaces (or with add=true extends) the selection with the units in the box.
func select_box(rect: Rect2, candidates: Array, project: Callable, add: bool = false) -> int:
	var found: Array[RTSUnit] = units_in_rect(rect, candidates, project)
	if not add:
		clear()
	for u: RTSUnit in found:
		_add(u)
	changed.emit(units)
	return units.size()

## Click: nearest selectable unit within `pick_px` of the screen point.
func select_at(screen: Vector2, candidates: Array, project: Callable, add: bool = false, toggle: bool = false, pick_px: float = 24.0) -> RTSUnit:
	var best: RTSUnit = null
	var best_d: float = pick_px
	for n: Variant in candidates:
		var u: RTSUnit = n as RTSUnit
		if is_selectable(u):
			var d: float = (project.call(u.global_position) as Vector2).distance_to(screen)
			if d <= best_d:
				best_d = d
				best = u
	if not add and not toggle:
		clear()
	if best != null:
		if toggle and units.has(best):
			best.selected = false
			units.erase(best)
		else:
			_add(best)
	changed.emit(units)
	return best

func save_group(i: int) -> void:
	_prune()
	groups[i] = units.duplicate()

func recall_group(i: int) -> int:
	clear()
	for n: Variant in groups.get(i, []):
		var u: RTSUnit = n as RTSUnit
		if is_selectable(u):
			_add(u)
	changed.emit(units)
	return units.size()

## Counts by unit_type, e.g. {"tank": 3, "scout": 2}, for the selection panel.
func type_counts() -> Dictionary[StringName, int]:
	_prune()
	var out: Dictionary[StringName, int] = {}
	for u: RTSUnit in units:
		out[u.unit_type] = out.get(u.unit_type, 0) + 1
	return out

func _add(u: RTSUnit) -> void:
	if not units.has(u):
		units.append(u)
		u.selected = true

func _prune() -> void:
	units = units.filter(func(u: RTSUnit) -> bool: return is_instance_valid(u) and u.is_alive())
