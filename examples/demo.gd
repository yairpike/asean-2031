extends Node3D
## Lite demo: primitive shapes only (no external art). Two teams, a producer,
## capturable resource points, box selection with live count, formation moves,
## grid pathfinding around blocks, attack orders, one production queue.
## Controls: LMB drag/click select (Shift add, Ctrl toggle), RMB move/attack,
## WASD/edge pan, wheel zoom, B build scout, C cancel, F line formation,
## X stop, E select all, Ctrl+1..9 save group, 1..9 recall, L switch language.

const CATALOG: Dictionary[StringName, Dictionary] = {
	&"scout": {"cost": 50, "time": 3.0, "hp": 60.0, "speed": 8.0, "damage": 6.0},
	&"tank": {"cost": 120, "time": 6.0, "hp": 180.0, "speed": 5.0, "damage": 14.0},
}
const PLAYER: int = 0
const ENEMY: int = 1

var teams: RTSTeams = RTSTeams.new()
var economy: RTSEconomy = RTSEconomy.new()
var nav: RTSGridNav = RTSGridNav.new(40, 40, 2.0, Vector3(-40, 0, -40))
var selection: RTSSelection = RTSSelection.new()
var queue: RTSProductionQueue
var resources: Array[RTSResourceNode] = []
var units: Array[RTSUnit] = []
var cam: RTSCamera
var box: RTSSelectionBox
var hud: Label
var help: Label
var shape: RTSOrders.Shape = RTSOrders.Shape.BOX
## Tests and captures drive the simulation by hand with tick().
var auto_tick: bool = true
var _mats: Dictionary[String, StandardMaterial3D] = {}
var _res_meshes: Array[MeshInstance3D] = []
var _fx: Array[Array] = []        # [node, seconds left]
var shots_fired: int = 0

func _ready() -> void:
	RTSBindings.install()
	teams.add_team(PLAYER, Color(0.25, 0.55, 1.0))
	teams.add_team(ENEMY, Color(0.95, 0.3, 0.25))
	teams.set_relation(PLAYER, ENEMY, RTSTeams.Relation.ENEMY)
	economy.set_credits(PLAYER, 200)
	selection.team = PLAYER
	queue = RTSProductionQueue.new(PLAYER, CATALOG)
	queue.rally = Vector3(-14, 0, 14)
	queue.produced.connect(func(t: StringName, rally: Vector3) -> void:
		var u: RTSUnit = spawn_unit(PLAYER, t, Vector3(-20, 0, 20))
		u.set_path(nav.find_path(u.position, rally)))
	_build_world()
	_build_ui()
	for i: int in 6:
		spawn_unit(PLAYER, &"scout" if i % 2 else &"tank", Vector3(-24 + (i % 3) * 3.0, 0, 6 + (i / 3) * 3.0))
	for i: int in 4:
		spawn_unit(ENEMY, &"tank", Vector3(20 + (i % 2) * 3.0, 0, -18 + (i / 2) * 3.0))

func mat(key: String, c: Color) -> StandardMaterial3D:
	if not _mats.has(key):
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.85
		_mats[key] = m
	return _mats[key]

func _mesh(m: Mesh, at: Vector3, material: Material, parent: Node = self) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = m
	mi.position = at
	mi.material_override = material
	parent.add_child(mi)
	return mi

func _build_world() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.11, 0.13, 0.15)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.58, 0.62)
	add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var ground: PlaneMesh = PlaneMesh.new()
	ground.size = Vector2(80, 80)
	_mesh(ground, Vector3.ZERO, mat("ground", Color(0.36, 0.42, 0.33)))
	# obstacles: a wall with a gap and a few blocks (blocked on the nav grid)
	for r: Rect2i in [Rect2i(18, 8, 2, 14), Rect2i(18, 26, 2, 6), Rect2i(8, 4, 5, 3), Rect2i(26, 24, 4, 4)]:
		nav.block_rect(r)
		var size: Vector3 = Vector3(r.size.x * nav.cell_size, 2.5, r.size.y * nav.cell_size)
		var bm: BoxMesh = BoxMesh.new()
		bm.size = size
		var c: Vector3 = nav.origin + Vector3((r.position.x + r.size.x / 2.0) * nav.cell_size, 1.25, (r.position.y + r.size.y / 2.0) * nav.cell_size)
		_mesh(bm, c, mat("rock", Color(0.5, 0.5, 0.52)))
	# producer building
	var hq: BoxMesh = BoxMesh.new()
	hq.size = Vector3(6, 3, 6)
	_mesh(hq, Vector3(-26, 1.5, 26), mat("hq", Color(0.3, 0.45, 0.75)))
	nav.block_rect(Rect2i(5, 31, 3, 3))
	# resource points
	for p: Vector3 in [Vector3(-10, 0, -6), Vector3(4, 0, 22), Vector3(12, 0, -26)]:
		resources.append(RTSResourceNode.new(p, 10, 2.0, -1))
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.top_radius = 1.4
		cyl.bottom_radius = 1.6
		cyl.height = 0.6
		_res_meshes.append(_mesh(cyl, p + Vector3(0, 0.3, 0), mat("res_free", Color(0.85, 0.75, 0.3))))
	cam = RTSCamera.new()
	cam.bounds = Rect2(-36, -36, 72, 72)
	cam.distance = 40.0
	cam.focus = Vector3(-6, 0, 8)   # frames the producer (bottom-left) and the enemy base
	add_child(cam)

func _build_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	box = RTSSelectionBox.new()
	box.count_provider = func(r: Rect2) -> int: return selection.preview_count(r, units, project)
	layer.add_child(box)
	hud = Label.new()
	hud.position = Vector2(16, 12)
	hud.add_theme_font_size_override("font_size", 18)
	hud.add_theme_constant_override("outline_size", 5)
	hud.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	layer.add_child(hud)
	help = Label.new()
	help.position = Vector2(16, 690)
	help.add_theme_font_size_override("font_size", 14)
	help.add_theme_constant_override("outline_size", 4)
	help.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	RTSLoc.bind(help, "UI_HELP", {"produce": RTSBindings.label(&"rts_produce"), "line": RTSBindings.label(&"rts_formation_line")})
	layer.add_child(help)

func project(p: Vector3) -> Vector2:
	return cam.unproject_position(p)

func spawn_unit(team: int, t: StringName, at: Vector3) -> RTSUnit:
	var d: Dictionary = CATALOG[t]
	var u: RTSUnit = RTSUnit.new()
	u.team = team
	u.unit_type = t
	u.max_hp = float(d["hp"])
	u.speed = float(d["speed"])
	u.attack_damage = float(d["damage"])
	u.position = at
	var col: Color = teams.color_of(team)
	if t == &"tank":
		var b: BoxMesh = BoxMesh.new()
		b.size = Vector3(1.6, 0.9, 2.2)
		_mesh(b, Vector3(0, 0.45, 0), mat("t%d" % team, col), u)
		var tur: CylinderMesh = CylinderMesh.new()
		tur.top_radius = 0.45
		tur.bottom_radius = 0.55
		tur.height = 0.5
		_mesh(tur, Vector3(0, 1.1, 0), mat("t%d" % team, col), u)
	else:
		var c: CapsuleMesh = CapsuleMesh.new()
		c.radius = 0.45
		c.height = 1.6
		_mesh(c, Vector3(0, 0.8, 0), mat("s%d" % team, col.lightened(0.2)), u)
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = 1.05
	ring.outer_radius = 1.25
	var rm: MeshInstance3D = _mesh(ring, Vector3(0, 0.05, 0), mat("ring", Color(0.4, 1.0, 0.5)), u)
	rm.name = "Ring"
	rm.visible = false
	var bar: QuadMesh = QuadMesh.new()
	bar.size = Vector2(1.6, 0.18)
	var hb: MeshInstance3D = _mesh(bar, Vector3(0, 2.4, 0), _bar_mat(), u)
	hb.name = "HealthBar"
	u.fired.connect(_on_fired)
	u.died.connect(_on_died)
	add_child(u)
	units.append(u)
	return u

func _bar_mat() -> StandardMaterial3D:
	if not _mats.has("bar"):
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.vertex_color_use_as_albedo = false
		m.albedo_color = Color(0.4, 1.0, 0.45)
		m.no_depth_test = true
		_mats["bar"] = m
	return _mats["bar"]

## Tracer + muzzle flash for one shot (short-lived meshes).
func _on_fired(u: RTSUnit, target: RTSUnit) -> void:
	shots_fired += 1
	var a: Vector3 = u.position + Vector3(0, 1.0, 0)
	var b: Vector3 = target.position + Vector3(0, 0.8, 0)
	var tr: BoxMesh = BoxMesh.new()
	tr.size = Vector3(0.08, 0.08, a.distance_to(b))
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.85, 0.4) if u.team == PLAYER else Color(1.0, 0.5, 0.35)
	var mi: MeshInstance3D = _mesh(tr, a.lerp(b, 0.5), m)
	if a.distance_squared_to(b) > 0.01:
		mi.look_at_from_position(a.lerp(b, 0.5), b, Vector3.UP)
	var fl: SphereMesh = SphereMesh.new()
	fl.radius = 0.35
	fl.height = 0.7
	var flash: MeshInstance3D = _mesh(fl, a, m)
	_fx.append([mi, 0.12])
	_fx.append([flash, 0.08])

func _on_died(u: RTSUnit) -> void:
	units.erase(u)
	u.queue_free()

func produce(t: StringName = &"scout") -> bool:
	return queue.enqueue(t, economy)

func command_at(ground: Vector3) -> void:
	var target: RTSUnit = null
	for u: RTSUnit in units:
		if teams.are_enemies(PLAYER, u.team) and Vector2(u.position.x, u.position.z).distance_to(Vector2(ground.x, ground.z)) < 2.0:
			target = u
	if target != null:
		RTSOrders.attack(selection.units, target, nav, teams)
	else:
		RTSOrders.move(selection.units, ground, nav, shape, 2.2)

func tick(delta: float) -> void:
	queue.advance(delta)
	for i: int in resources.size():
		var r: RTSResourceNode = resources[i]
		for u: RTSUnit in units:
			if u.is_alive() and Vector2(u.position.x, u.position.z).distance_to(Vector2(r.position.x, r.position.z)) < 3.0:
				r.owner_team = u.team
		r.advance(delta, economy)
		_res_meshes[i].material_override = mat("res_free", Color(0.85, 0.75, 0.3)) if r.owner_team < 0 else mat("res%d" % r.owner_team, teams.color_of(r.owner_team).lerp(Color(0.85, 0.75, 0.3), 0.4))
	for u: RTSUnit in units.duplicate():
		if u.attack_target == null and not u.is_moving():
			for o: RTSUnit in units:
				if teams.are_enemies(u.team, o.team) and o.is_alive() and u.position.distance_to(o.position) <= u.attack_range:
					u.attack_target = o
					break
		u.advance(delta)
	RTSSeparation.apply(units, delta, 8.0, func(p: Vector3) -> bool: return not nav.is_blocked(nav.cell_at(p)))

func _process(delta: float) -> void:
	if auto_tick:
		tick(delta)
	var pan: Vector2 = Vector2(Input.get_axis(&"rts_pan_left", &"rts_pan_right"), Input.get_axis(&"rts_pan_down", &"rts_pan_up"))
	if pan != Vector2.ZERO:
		cam.pan(pan, delta)
	for u: RTSUnit in units:
		(u.get_node("Ring") as Node3D).visible = u.selected
		var hb: Node3D = u.get_node("HealthBar")
		var ratio: float = clampf(u.hp / u.max_hp, 0.0, 1.0)
		hb.scale = Vector3(maxf(ratio, 0.02), 1, 1)
		hb.visible = ratio < 1.0 or u.selected
	for i: int in range(_fx.size() - 1, -1, -1):
		_fx[i][1] = float(_fx[i][1]) - delta
		if float(_fx[i][1]) <= 0.0:
			(_fx[i][0] as Node).queue_free()
			_fx.remove_at(i)
	var names: PackedStringArray = PackedStringArray()
	for t: StringName in queue.items:
		names.append(str(t))
	hud.text = "%s     %s     %s" % [RTSLoc.t("UI_CREDITS", {"credits": economy.credits(PLAYER)}),
		RTSLoc.t("UI_SELECTED", {"count": selection.count()}),
		RTSLoc.t("UI_QUEUE", {"items": ("%s %d%%" % [", ".join(names), int(queue.head_ratio() * 100)]) if not names.is_empty() else "-"})]

func _unhandled_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				box.begin(mb.position)
			else:
				if box.is_box():
					selection.select_box(box.rect(), units, project, mb.shift_pressed)
				else:
					selection.select_at(mb.position, units, project, mb.shift_pressed, mb.ctrl_pressed)
				box.end()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			var g: Vector3 = cam.ground_at(mb.position)
			if g != Vector3.INF:
				command_at(g)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			cam.zoom(1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			cam.zoom(-1)
		return
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		box.update_drag(mm.position)
		return
	if event.is_action_pressed(&"rts_produce"):
		produce()
	elif event.is_action_pressed(&"rts_cancel_production"):
		queue.cancel(economy)
	elif event.is_action_pressed(&"rts_formation_line"):
		shape = RTSOrders.Shape.LINE if shape == RTSOrders.Shape.BOX else RTSOrders.Shape.BOX
	elif event.is_action_pressed(&"rts_stop"):
		RTSOrders.stop(selection.units)
	elif event.is_action_pressed(&"rts_select_all"):
		selection.select_box(Rect2(Vector2(-1e6, -1e6), Vector2(2e6, 2e6)), units, project)
	var k: InputEventKey = event as InputEventKey
	if k != null and k.pressed and not k.echo:
		if k.keycode == KEY_L:
			RTSLoc.set_language("fr" if TranslationServer.get_locale().begins_with("en") else "en", self)
		var n: int = k.keycode - KEY_0
		if n >= 1 and n <= 9:
			if k.ctrl_pressed:
				selection.save_group(n)
			else:
				selection.recall_group(n)
