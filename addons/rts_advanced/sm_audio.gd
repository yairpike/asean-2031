class_name SMAudioDirector
extends RefCounted
## Crossfades exploration and combat stems. The clips are silent placeholders.

signal crossed(from_stem: StringName, to_stem: StringName)

var exploration: float = 1.0
var combat: float = 0.0
var stem: StringName = &"exploration"
var silent_placeholder: bool = true
var fade_seconds: float = 1.0
var _target_combat: bool = false

func set_combat(active: bool) -> void:
	_target_combat = active

func advance(delta: float) -> void:
	var step: float = delta / maxf(fade_seconds, 0.001)
	var before: StringName = stem
	if _target_combat:
		combat = minf(1.0, combat + step)
		exploration = maxf(0.0, exploration - step)
	else:
		exploration = minf(1.0, exploration + step)
		combat = maxf(0.0, combat - step)
	stem = &"combat" if combat > exploration else &"exploration"
	if stem != before:
		crossed.emit(before, stem)
