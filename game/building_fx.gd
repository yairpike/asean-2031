extends Node3D
## View-only life of one structure: rises out of a scaffold when placed, smokes and burns as it loses health,
## and collapses into rubble when the sim hides it. The sim never reads anything this node writes.

const FX = preload("res://game/motion_fx.gd")

enum Phase { RAISE, STAND, COLLAPSE, RUBBLE }

const RAISE_TIME: float = 2.8
const COLLAPSE_TIME: float = 1.8
const RUBBLE_TIME: float = 14.0
const SMOKE_AT: float = 0.66
const FIRE_AT: float = 0.33

var phase: int = Phase.RAISE
var age: float = 0.0
var target: Node3D
var rest: Transform3D
var box: AABB
var cage: Node3D
var health: float = 1.0
var smoke_fx: CPUParticles3D
var fire_fx: CPUParticles3D
var proxy: Node3D
var debris: Node3D
var lean: Vector3 = Vector3.ZERO

## Hooks a structure node. `raise` false skips the construction rise (buildings present at load).
static func attach(structure: Node3D, raise: bool = true) -> Node3D:
	if structure == null or structure.get_node_or_null("BuildingFx") != null:
		return null
	var fx: Node3D = (load("res://game/building_fx.gd") as GDScript).new() as Node3D
	fx.name = "BuildingFx"
	fx.set("phase", Phase.RAISE if raise else Phase.STAND)
	structure.add_child(fx)
	return fx

static func set_health(structure: Node3D, fraction: float) -> void:
	if structure == null:
		return
	var fx: Node = structure.get_node_or_null("BuildingFx")
	if fx != null:
		fx.call("show_health", fraction)

func _ready() -> void:
	target = get_parent() as Node3D
	if target == null:
		return
	rest = target.transform
	box = _bounds(target)
	target.visibility_changed.connect(_on_visibility)
	if phase == Phase.RAISE:
		_apply_rise(0.0)
		_start_raise.call_deferred()

func _bounds(root: Node3D) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	var inv: Transform3D = root.global_transform.affine_inverse()
	for node: Node in root.find_children("*", "VisualInstance3D", true, false):
		if node is CPUParticles3D or node.name == "ContactShadow":
			continue
		var vi: VisualInstance3D = node as VisualInstance3D
		var b: AABB = inv * vi.global_transform * vi.get_aabb()
		out = b if first else out.merge(b)
		first = false
	var own: VisualInstance3D = root as VisualInstance3D
	if own != null and (root as MeshInstance3D).mesh != null:
		out = own.get_aabb() if first else out.merge(own.get_aabb())
		first = false
	if first:
		out = AABB(Vector3(-2, 0, -2), Vector3(4, 3, 4))
	return out

func _stage() -> Node3D:
	return target.get_parent() as Node3D

func _start_raise() -> void:
	var stage: Node3D = _stage()
	if stage == null:
		phase = Phase.STAND
		return
	cage = _scaffold(box)
	cage.name = "Scaffold_%s" % target.name
	stage.add_child(cage)
	cage.transform = rest
	cage.scale = Vector3(1.0, 0.01, 1.0)
	FX.dust(stage, rest.origin + Vector3(0, 0.1, 0), maxf(box.size.x, box.size.z) * 0.6, 20)

func _apply_rise(k: float) -> void:
	var h: float = box.size.y
	var eased: float = 1.0 - pow(1.0 - clampf(k, 0.0, 1.0), 3.0)
	var xf: Transform3D = rest
	xf.origin.y = rest.origin.y - h * (1.0 - eased)
	target.transform = xf

func _process(delta: float) -> void:
	if target == null:
		return
	age += delta
	if phase == Phase.RAISE:
		_step_raise()
	elif phase == Phase.COLLAPSE or phase == Phase.RUBBLE:
		_step_collapse(delta)

func _step_raise() -> void:
	var cage_k: float = clampf(age / 0.45, 0.0, 1.0)
	if cage != null:
		cage.scale = Vector3(1.0, maxf(cage_k, 0.01), 1.0)
	_apply_rise((age - 0.3) / (RAISE_TIME - 0.8))
	if age >= RAISE_TIME - 0.5 and cage != null:
		var fade: float = clampf((RAISE_TIME - age) / 0.5, 0.0, 1.0)
		cage.scale = Vector3(1.0 + (1.0 - fade) * 0.04, maxf(fade, 0.01), 1.0 + (1.0 - fade) * 0.04)
	if age >= RAISE_TIME:
		target.transform = rest
		if cage != null:
			cage.queue_free()
			cage = null
		FX.dust(_stage(), rest.origin + Vector3(0, 0.1, 0), maxf(box.size.x, box.size.z) * 0.7, 26)
		phase = Phase.STAND
		age = 0.0

func show_health(fraction: float) -> void:
	health = clampf(fraction, 0.0, 1.0)
	var roof: Vector3 = Vector3(box.get_center().x, box.end.y * 0.85, box.get_center().z)
	var span: float = clampf(maxf(box.size.x, box.size.z) * 0.22, 0.8, 3.0)
	if health < SMOKE_AT and smoke_fx == null:
		smoke_fx = FX.smoke(self, roof + Vector3(box.size.x * 0.18, 0, 0), span, 18)
		smoke_fx.emitting = true
	if health < FIRE_AT and fire_fx == null:
		fire_fx = FX.fire(self, roof - Vector3(box.size.x * 0.15, box.size.y * 0.2, 0), span * 0.8, 20)
		fire_fx.emitting = true
	if smoke_fx != null:
		smoke_fx.emitting = health < SMOKE_AT
	if fire_fx != null:
		fire_fx.emitting = health < FIRE_AT

func _on_visibility() -> void:
	if target.visible or phase == Phase.COLLAPSE or phase == Phase.RUBBLE:
		return
	if not is_inside_tree() or _stage() == null:
		return
	collapse()

## Leaves a falling copy of the structure in its place. The original stays hidden for the sim.
func collapse() -> void:
	var stage: Node3D = _stage()
	if stage == null:
		return
	if phase == Phase.RAISE:
		target.transform = rest
		if cage != null:
			cage.queue_free()
			cage = null
	var husk: Node3D = Node3D.new()
	husk.name = "Ruin_%s" % target.name
	stage.add_child(husk)
	husk.transform = rest
	proxy = target.duplicate() as Node3D
	for child: Node in proxy.get_children():
		if child.name == "BuildingFx" or child is CPUParticles3D:
			proxy.remove_child(child)
			child.free()
	proxy.transform = Transform3D.IDENTITY
	proxy.visible = true
	husk.add_child(proxy)
	var r: RandomNumberGenerator = FX.rng()
	lean = Vector3(r.randf_range(-0.12, 0.12), 0.0, r.randf_range(-0.12, 0.12))
	var span: float = maxf(box.size.x, box.size.z)
	FX.blast(husk, Vector3(0, box.size.y * 0.5, 0), clampf(span * 0.28, 1.0, 3.0))
	FX.dust(husk, Vector3(0, 0.2, 0), span * 0.8, 32)
	FX.fire(husk, Vector3(0, box.size.y * 0.25, 0), clampf(span * 0.25, 0.8, 2.4), 22).emitting = true
	FX.smoke(husk, Vector3(0, box.size.y * 0.4, 0), clampf(span * 0.3, 1.0, 3.0), 22).emitting = true
	debris = FX.debris(husk, Vector3.ZERO, span * 0.6, 14, Color(0.3, 0.27, 0.24))
	var coat: StandardMaterial3D = FX.char_coat(0.0)
	FX.coat(proxy, coat)
	proxy.set_meta("coat", coat)
	reparent(husk, false)
	position = Vector3.ZERO
	target = husk
	phase = Phase.COLLAPSE
	age = 0.0

func _step_collapse(delta: float) -> void:
	FX.step_debris(debris, delta)
	if proxy == null:
		return
	var k: float = clampf(age / COLLAPSE_TIME, 0.0, 1.0)
	var fall: float = k * k
	var shake: float = (1.0 - k) * 0.06 * sin(age * 55.0)
	proxy.position = Vector3(shake, -box.size.y * 0.55 * fall, shake * 0.6)
	proxy.rotation = lean * fall
	proxy.scale = Vector3(1.0 + 0.08 * fall, 1.0 - 0.55 * fall, 1.0 + 0.08 * fall)
	var coat: StandardMaterial3D = proxy.get_meta("coat") as StandardMaterial3D
	if coat != null:
		coat.albedo_color.a = 0.7 * k
	if phase == Phase.COLLAPSE and age >= COLLAPSE_TIME:
		phase = Phase.RUBBLE
	if phase == Phase.RUBBLE and age >= COLLAPSE_TIME + RUBBLE_TIME:
		target.queue_free()

## Bamboo-and-pipe scaffold drawn as thin bars around the footprint.
func _scaffold(b: AABB) -> Node3D:
	var root: Node3D = Node3D.new()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.52, 0.3)
	mat.roughness = 0.9
	var pad: float = 0.25
	var x0: float = b.position.x - pad
	var x1: float = b.end.x + pad
	var z0: float = b.position.z - pad
	var z1: float = b.end.z + pad
	var top: float = b.end.y + 0.3
	var bar: float = clampf(maxf(b.size.x, b.size.z) * 0.012, 0.05, 0.16)
	var cols: int = 4
	for i: int in cols + 1:
		var f: float = float(i) / float(cols)
		for z: float in [z0, z1]:
			_bar(root, mat, Vector3(lerpf(x0, x1, f), top * 0.5, z), Vector3(bar, top, bar))
		for x: float in [x0, x1]:
			_bar(root, mat, Vector3(x, top * 0.5, lerpf(z0, z1, f)), Vector3(bar, top, bar))
	var decks: int = maxi(2, int(top / 1.6))
	for j: int in decks + 1:
		var y: float = top * float(j) / float(decks)
		_bar(root, mat, Vector3((x0 + x1) * 0.5, y, z0), Vector3(x1 - x0, bar, bar))
		_bar(root, mat, Vector3((x0 + x1) * 0.5, y, z1), Vector3(x1 - x0, bar, bar))
		_bar(root, mat, Vector3(x0, y, (z0 + z1) * 0.5), Vector3(bar, bar, z1 - z0))
		_bar(root, mat, Vector3(x1, y, (z0 + z1) * 0.5), Vector3(bar, bar, z1 - z0))
	return root

func _bar(root: Node3D, mat: Material, at: Vector3, size: Vector3) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	root.add_child(mi)
