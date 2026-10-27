class_name RTSProductionQueue
extends RefCounted
## One producer's build queue. Cost is paid when an item is queued, refunded in full
## on cancel. Only the head item progresses. Emits `produced` with the unit type and
## the rally point; spawning the actual node is up to the caller.

signal produced(unit_type: StringName, rally: Vector3)
signal queue_changed()
## Same as produced, plus the tag given to enqueue() (e.g. a squad id).
signal produced_tagged(unit_type: StringName, rally: Vector3, tag: StringName)

var team: int = 0
var max_items: int = 5
var rally: Vector3 = Vector3.ZERO
var speed: float = 1.0
## unit_type -> {"cost": int, "time": float}
var catalog: Dictionary[StringName, Dictionary] = {}
var items: Array[StringName] = []
var progress: float = 0.0
var tags: Array[StringName] = []
## Paused queues keep their items but make no progress.
var paused: bool = false
## Repeat: a finished item is re-queued (and paid again) if affordable.
var repeat: bool = false
var economy_ref: RTSEconomy = null

func _init(p_team: int = 0, p_catalog: Dictionary[StringName, Dictionary] = {}) -> void:
	team = p_team
	catalog = p_catalog

func can_queue(unit_type: StringName, economy: RTSEconomy) -> String:
	if not catalog.has(unit_type):
		return "unknown unit"
	if items.size() >= max_items:
		return "queue full"
	if not economy.can_afford(team, int(catalog[unit_type]["cost"])):
		return "not enough credits"
	return ""

func enqueue(unit_type: StringName, economy: RTSEconomy, tag: StringName = &"") -> bool:
	if can_queue(unit_type, economy) != "":
		return false
	economy.try_spend(team, int(catalog[unit_type]["cost"]))
	economy_ref = economy
	items.append(unit_type)
	tags.append(tag)
	queue_changed.emit()
	return true

## Cancels item `index` (default: last) and refunds its cost. Returns the refund.
func cancel(economy: RTSEconomy, index: int = -1) -> int:
	if items.is_empty():
		return 0
	var i: int = items.size() - 1 if index < 0 else index
	if i >= items.size():
		return 0
	var refund: int = int(catalog[items[i]]["cost"])
	items.remove_at(i)
	tags.remove_at(i)
	if i == 0:
		progress = 0.0
	economy.earn(team, refund)
	queue_changed.emit()
	return refund

## 0..1 progress of the head item.
func head_ratio() -> float:
	if items.is_empty():
		return 0.0
	return clampf(progress / float(catalog[items[0]]["time"]), 0.0, 1.0)

## Advances the head item; returns the number of units finished this call.
func advance(delta: float) -> int:
	var done: int = 0
	if paused:
		return 0
	var left: float = delta * speed
	while left > 0.0 and not items.is_empty():
		var need: float = float(catalog[items[0]]["time"]) - progress
		if left >= need:
			left -= need
			var t: StringName = items.pop_front()
			var tag: StringName = tags.pop_front()
			progress = 0.0
			done += 1
			produced.emit(t, rally)
			produced_tagged.emit(t, rally, tag)
			if repeat and economy_ref != null:
				enqueue(t, economy_ref)
			queue_changed.emit()
		else:
			progress += left
			left = 0.0
	return done
