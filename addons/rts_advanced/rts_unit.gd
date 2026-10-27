class_name RTSUnit
extends Node3D
## Minimal RTS unit: team, health, movement along a waypoint path, simple attack.
## Visuals are up to you: add meshes as children. Logic runs in advance(delta)
## (called by RTSWorld, or by _physics_process when auto_tick is true).

signal died(unit: RTSUnit)
signal arrived(unit: RTSUnit)
signal fired(unit: RTSUnit, target: RTSUnit)

@export var team: int = 0
@export var unit_type: StringName = &"unit"
@export var speed: float = 6.0
@export var max_hp: float = 100.0
@export var attack_damage: float = 10.0
@export var attack_range: float = 6.0
@export var attack_interval: float = 1.0
@export var radius: float = 0.6
@export var auto_tick: bool = false

var hp: float = 100.0
var path: PackedVector3Array = PackedVector3Array()
var attack_target: RTSUnit = null
var selected: bool = false
var _cooldown: float = 0.0
## Optional (Pro): any object with height_at(x, z) -> float (RTSTerrain). When
## set, the unit stands on the terrain surface.
var terrain: Object = null
## Optional (Pro): RTSOccupancy-like object with stand(id, cell) / remove_unit(id)
## and a callable mapping world position -> cell.
var occupancy: Object = null
var cell_of: Callable
## Scales movement (e.g. RTSSuppression.speed_mult()).
var speed_scale: float = 1.0
## Multiplies outgoing weapon damage. Status effects can lower it.
var damage_mult: float = 1.0
## Multiplies damage this unit takes. Shrunk and black-hole armor use it.
var incoming_mult: float = 1.0
## Optional filter (unit, target, amount) -> amount. The jammer uses this.
var shot_filter: Callable
## When true an external combat system (RTSCombat) fires; the unit only closes
## to range and holds.
var external_combat: bool = false

func _ready() -> void:
	hp = max_hp

func _physics_process(delta: float) -> void:
	if auto_tick:
		advance(delta)

func is_alive() -> bool:
	return hp > 0.0

func is_moving() -> bool:
	return not path.is_empty()

func set_path(p: PackedVector3Array) -> void:
	path = p

func stop() -> void:
	path = PackedVector3Array()
	attack_target = null

func take_damage(amount: float) -> void:
	if not is_alive():
		return
	hp = maxf(0.0, hp - amount * incoming_mult)
	if hp <= 0.0:
		path = PackedVector3Array()
		if occupancy != null:
			occupancy.call("remove_unit", get_instance_id())
		died.emit(self)

func advance(delta: float) -> void:
	if not is_alive():
		return
	if bool(get_meta("frozen", false)):
		path = PackedVector3Array()
		attack_target = null
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	if attack_target != null and (not is_instance_valid(attack_target) or not attack_target.is_alive()):
		attack_target = null
	if attack_target != null:
		var d: float = _flat(global_position).distance_to(_flat(attack_target.global_position))
		if d <= attack_range:
			path = PackedVector3Array()
			if not external_combat and _cooldown <= 0.0:
				_cooldown = attack_interval
				var dealt: float = attack_damage * damage_mult
				if shot_filter.is_valid():
					dealt = float(shot_filter.call(self, attack_target, dealt))
				fired.emit(self, attack_target)
				if dealt > 0.0:
					attack_target.take_damage(dealt)
			return
		if path.is_empty():   # chase: head straight for a target that moved
			path = PackedVector3Array([attack_target.global_position])
	_move(delta)

func _move(delta: float) -> void:
	var step: float = speed * speed_scale * delta
	while step > 0.0 and not path.is_empty():
		var goal: Vector3 = Vector3(path[0].x, position.y, path[0].z)
		var to: Vector3 = goal - position
		var dist: float = to.length()
		if dist <= step:
			position = goal
			step -= dist
			path.remove_at(0)
			if path.is_empty():
				arrived.emit(self)
		else:
			position += to / dist * step
			look_at_flat(goal)
			step = 0.0
	ground()

## Snaps to the terrain surface and refreshes the standing claim.
func ground() -> void:
	if terrain != null:
		position.y = float(terrain.call("height_at", position.x, position.z))
	if occupancy != null and cell_of.is_valid():
		occupancy.call("stand", get_instance_id(), cell_of.call(position))

func look_at_flat(p: Vector3) -> void:
	var d: Vector3 = Vector3(p.x - position.x, 0.0, p.z - position.z)
	if d.length_squared() > 0.0001:
		rotation.y = atan2(-d.x, -d.z)

static func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)
