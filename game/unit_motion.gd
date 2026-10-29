extends RefCounted
## View-only unit motion. Rigged models play idle, walk, shoot, and die clips; hulls get recoil, bob, and banking.
## Everything here reads RTSUnit state and writes only under the unit's Body node, so the sim stays deterministic.

const FX = preload("res://game/motion_fx.gd")
const DeathFx = preload("res://game/death_fx.gd")

const WALK_PACE: float = 5.0
const SHOT_HOLD: float = 0.7
const BLEND: float = 0.18
const TURRET_RATE: float = 9.0
const LOOPED: PackedStringArray = ["idle", "walk", "shoot", "run"]

## Wires a freshly dressed unit. Safe to call again after the model swaps in.
static func attach(u: RTSUnit, body: MeshInstance3D) -> void:
	if u == null or body == null:
		return
	if not u.fired.is_connected(on_fired):
		u.fired.connect(on_fired)
	if not u.died.is_connected(on_died):
		u.died.connect(on_died)

static func player_of(body: Node) -> AnimationPlayer:
	if body == null:
		return null
	var model: String = str(body.get_meta("model", ""))
	if str(body.get_meta("anim_seen", "-")) == model:
		var cached: Variant = body.get_meta("anim_player", null)
		return cached as AnimationPlayer if is_instance_valid(cached) else null
	body.set_meta("anim_seen", model)
	var found: AnimationPlayer = body.find_child("AnimationPlayer", true, false) as AnimationPlayer
	body.set_meta("anim_player", found)
	if found != null:
		_prime(found)
	return found

static func _prime(player: AnimationPlayer) -> void:
	for clip: StringName in player.get_animation_list():
		var anim: Animation = player.get_animation(clip)
		var key: String = _clip_key(str(clip))
		anim.loop_mode = Animation.LOOP_LINEAR if LOOPED.has(key) else Animation.LOOP_NONE
	player.playback_default_blend_time = BLEND

static func _clip_key(clip: String) -> String:
	return clip.get_slice("/", clip.get_slice_count("/") - 1).to_lower()

static func _find_clip(player: AnimationPlayer, key: String) -> StringName:
	for clip: StringName in player.get_animation_list():
		if _clip_key(str(clip)) == key:
			return clip
	return &""

## Picks the clip a unit should show right now.
static func clip_for(u: RTSUnit, body: Node) -> String:
	if not u.is_alive():
		return "die"
	if u.is_moving():
		return "walk"
	if float(body.get_meta("anim_shot", 0.0)) > 0.0 or engaged(u):
		return "shoot"
	return "idle"

static func engaged(u: RTSUnit) -> bool:
	var foe: RTSUnit = u.attack_target
	if foe == null or not is_instance_valid(foe) or not foe.is_alive():
		return false
	var a: Vector3 = u.global_position
	var b: Vector3 = foe.global_position
	return Vector2(a.x - b.x, a.z - b.z).length() <= u.attack_range * 1.05

static func play(player: AnimationPlayer, key: String, pace: float = 1.0) -> bool:
	var clip: StringName = _find_clip(player, key)
	if clip == &"":
		return false
	if player.current_animation != clip:
		player.play(clip)
	player.speed_scale = pace
	return true

## Called every view frame per unit (SMPointer.unit_posed).
static func pose(u: RTSUnit, delta: float) -> void:
	var body: MeshInstance3D = u.get_node_or_null("Body") as MeshInstance3D
	if body == null:
		return
	var shot: float = maxf(0.0, float(body.get_meta("anim_shot", 0.0)) - delta)
	body.set_meta("anim_shot", shot)
	body.set_meta("anim_t", float(body.get_meta("anim_t", 0.0)) + delta)
	var player: AnimationPlayer = player_of(body)
	if player != null:
		var key: String = clip_for(u, body)
		var pace: float = 1.0
		if key == "walk":
			pace = clampf(u.speed * u.speed_scale / WALK_PACE, 0.6, 1.8)
		play(player, key, pace)
		_face(u, body, delta)
		return
	if str(body.get_meta("form", "")) == "figure":
		_face(u, body, delta)
	_hull(u, body, delta)

## Infantry turn the whole body toward what they shoot; the sim only turns units along their path.
static func _face(u: RTSUnit, body: Node3D, delta: float) -> void:
	var want: float = 0.0
	if engaged(u):
		var dir: Vector3 = u.attack_target.global_position - u.global_position
		want = wrapf(atan2(-dir.x, -dir.z) - u.rotation.y, -PI, PI)
	body.rotation.y = rotate_toward(body.rotation.y, want, TURRET_RATE * 1.6 * delta)

static func _hull(u: RTSUnit, body: MeshInstance3D, delta: float) -> void:
	var form: String = str(body.get_meta("form", ""))
	var t: float = float(body.get_meta("anim_t", 0.0))
	var moving: bool = u.is_moving()
	var turret: Node3D = body.get_node_or_null("Turret") as Node3D
	if turret != null:
		var want: float = 0.0
		var foe: RTSUnit = u.attack_target
		if foe != null and is_instance_valid(foe) and foe.is_alive():
			var dir: Vector3 = foe.global_position - u.global_position
			want = wrapf(atan2(-dir.x, -dir.z) - u.rotation.y, -PI, PI)
		turret.rotation.y = rotate_toward(turret.rotation.y, want, TURRET_RATE * delta)
	var kick: float = float(body.get_meta("anim_kick", 0.0))
	kick = move_toward(kick, 0.0, delta * 5.0)
	body.set_meta("anim_kick", kick)
	var barrel: Node3D = turret.get_node_or_null("Barrel") as Node3D if turret != null else null
	if barrel != null:
		if not barrel.has_meta("anim_rest"):
			barrel.set_meta("anim_rest", barrel.position)
		var rest: Vector3 = barrel.get_meta("anim_rest")
		barrel.position = rest + barrel.basis.z.normalized() * _ease_kick(kick) * 0.45
	var yaw_was: float = float(body.get_meta("anim_yaw", u.rotation.y))
	var turn_rate: float = wrapf(u.rotation.y - yaw_was, -PI, PI) / maxf(delta, 0.0001)
	body.set_meta("anim_yaw", u.rotation.y)
	var lift: float = 0.0
	var pitch: float = 0.0
	var roll: float = 0.0
	if form == "heli" or form == "jet" or form == "airship":
		lift = sin(t * 1.9) * 0.12
		pitch = -0.14 if moving else 0.0
		roll = clampf(-turn_rate * 0.25, -0.5, 0.5)
		var rotor: Node3D = body.get_node_or_null("Rotor") as Node3D
		if rotor != null:
			rotor.rotate_y(delta * 22.0)
	elif form == "boat" or form == "sub":
		lift = sin(t * 1.6) * 0.05
		pitch = (-0.05 if moving else 0.0) + sin(t * 1.1) * 0.02
		roll = sin(t * 1.3) * 0.04 + clampf(-turn_rate * 0.08, -0.15, 0.15)
	elif form == "tank" or form == "tube" or form == "truck" or form == "hero":
		if moving:
			lift = absf(sin(t * 15.0)) * 0.025
			pitch = sin(t * 7.0) * 0.008 - 0.012
		pitch += _ease_kick(kick) * 0.05
	body.position.y = lerpf(body.position.y, lift, minf(1.0, delta * 10.0))
	body.rotation.x = lerpf(body.rotation.x, pitch, minf(1.0, delta * 6.0))
	body.rotation.z = lerpf(body.rotation.z, roll, minf(1.0, delta * 4.0))

static func _ease_kick(k: float) -> float:
	return k * k * (3.0 - 2.0 * k)

static func on_fired(unit: RTSUnit, _target: RTSUnit) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	var body: MeshInstance3D = unit.get_node_or_null("Body") as MeshInstance3D
	if body == null:
		return
	body.set_meta("anim_shot", SHOT_HOLD)
	var stage: Node3D = unit.get_parent() as Node3D
	if stage == null:
		return
	if player_of(body) != null:
		FX.flash(stage, _muzzle(body, null), 0.45)
		return
	body.set_meta("anim_kick", 1.0)
	var turret: Node3D = body.get_node_or_null("Turret") as Node3D
	var barrel: Node3D = turret.get_node_or_null("Barrel") as Node3D if turret != null else null
	var muzzle: Vector3 = _muzzle(body, barrel)
	FX.flash(stage, muzzle, 1.2 if barrel != null else 0.6)

static func _muzzle(body: MeshInstance3D, barrel: Node3D) -> Vector3:
	if barrel != null:
		var box: AABB = _bounds(barrel)
		var tip: Vector3 = Vector3(box.get_center().x, box.get_center().y, box.position.z)
		return barrel.global_transform * tip
	var form: String = "figure" if player_of(body) != null else str(body.get_meta("form", ""))
	var local: Vector3 = (load("res://game/unit_meshes.gd") as GDScript).call("muzzle_pos", form)
	return body.global_transform * local

static func _bounds(node: Node3D) -> AABB:
	var vi: VisualInstance3D = node as VisualInstance3D
	if vi != null:
		return vi.get_aabb()
	for child: Node in node.get_children():
		if child is VisualInstance3D:
			return (child as Node3D).transform * (child as VisualInstance3D).get_aabb()
	return AABB(Vector3(-0.1, -0.1, -1.0), Vector3(0.2, 0.2, 1.0))

## The sim frees a dead unit on its next tick. Lift its Body out first so the death can play on.
static func on_died(unit: RTSUnit) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	var body: MeshInstance3D = unit.get_node_or_null("Body") as MeshInstance3D
	var stage: Node3D = unit.get_parent() as Node3D
	if body == null or stage == null:
		return
	var rig: DeathFx = DeathFx.new()
	rig.name = "Dying_%d" % unit.get_instance_id()
	stage.add_child(rig)
	rig.global_transform = unit.global_transform
	body.reparent(rig, true)
	rig.begin(body, player_of(body))
