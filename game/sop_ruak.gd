extends Node3D
## Sop Ruak. Three land sectors split by a Y-shaped river.
## GTFC versus one enemy across a Y-shaped river. Same pointer controls as Phillips Channel.

var grid: SMDomainGrid
var sim: SMMatch = SMMatch.new()
var field: SMPointer = SMPointer.new()
var raider: SMRaider = SMRaider.new()
var status: Label
var ui_layer: CanvasLayer

func _ready() -> void:
	grid = SMDomainGrid.sop_ruak_layout()
	_prepare_ability()
	_world()
	_ui()
	_arm_units()

func fire_ability() -> bool:
	var ok: bool = sim.use_f()
	_say("ability fired" if ok else "ability not ready")
	return ok

func _prepare_ability() -> void:
	sim.abilities = SMAbilities.new()
	sim.yard = SMBuildYard.new()
	sim.yard.center = grid.cell_center(Vector2i(8, 22))
	sim.abilities.add_unit(10, sim.yard.center, SMAbilities.TOGGLE, 2.0, 0.6)
	sim.abilities.add_unit(11, sim.yard.center + Vector3(2.0, 0.0, 0.0), SMAbilities.SMART, 3.0, 0.6)
	sim.abilities.add_unit(12, sim.yard.center + Vector3(8.0, 0.0, 0.0), SMAbilities.SMART, 3.0, 0.6)

func _world() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.07, 0.1, 0.13)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.58, 0.62)
	add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 25, 0)
	add_child(sun)
	_slab("WestSector", Vector3(-38, 0, 18), Vector3(48, 0.4, 56), Color(0.36, 0.32, 0.22))
	_slab("EastSector", Vector3(38, 0, 18), Vector3(48, 0.4, 56), Color(0.3, 0.34, 0.24))
	_slab("NorthSector", Vector3(0, 0, -32), Vector3(28, 0.4, 36), Color(0.34, 0.36, 0.26))
	_slab("RiverStem", Vector3(0, -0.25, 34), Vector3(16, 0.3, 52), Color(0.08, 0.24, 0.42))
	_slab("RiverJunction", Vector3(0, -0.25, 0), Vector3(20, 0.3, 20), Color(0.08, 0.22, 0.4))
	var left: MeshInstance3D = _slab("RiverLeft", Vector3(-32, -0.22, -32), Vector3(14, 0.28, 62), Color(0.1, 0.28, 0.46))
	left.rotation_degrees = Vector3(0, 45, 0)
	var right: MeshInstance3D = _slab("RiverRight", Vector3(32, -0.22, -32), Vector3(14, 0.28, 62), Color(0.1, 0.28, 0.46))
	right.rotation_degrees = Vector3(0, -45, 0)
	_slab("FordSouth", Vector3(0, 0.08, 26), Vector3(16, 0.22, 8), Color(0.42, 0.38, 0.26))
	_slab("FordWest", Vector3(-30, 0.08, -30), Vector3(12, 0.22, 12), Color(0.42, 0.38, 0.26))
	_slab("FordEast", Vector3(30, 0.08, -30), Vector3(12, 0.22, 12), Color(0.42, 0.38, 0.26))
	var cam: RTSCamera = RTSCamera.new()
	cam.name = "Camera"
	cam.bounds = Rect2(-80, -80, 160, 160)
	cam.distance = 46.0
	cam.edge_pan_px = 20.0
	cam.focus = Vector3(-36, 0, 16)
	add_child(cam)
	cam.current = true

func _ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	var title: Label = Label.new()
	title.text = "GTFC  crimson / amber    Sop Ruak"
	title.position = Vector2(16, 12)
	ui_layer.add_child(title)
	var ability: Button = Button.new()
	ability.name = "AbilityButton"
	ability.text = "Ability (F)"
	ability.position = Vector2(16, 44)
	ability.pressed.connect(fire_ability)
	ui_layer.add_child(ability)
	status = Label.new()
	status.name = "Status"
	status.text = "The enemy builds, expands, and attacks. Cross a ford to reach them."
	status.position = Vector2(16, 84)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(720, 28)
	ui_layer.add_child(status)
	var hint: Label = Label.new()
	hint.text = "Left click selects. Drag a box. Right click ground moves. Right click an enemy attacks. F fires the ability."
	hint.position = Vector2(16, 680)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(980, 28)
	ui_layer.add_child(hint)

func _arm_units() -> void:
	var cam: RTSCamera = get_node("Camera") as RTSCamera
	field.bind(self, cam)
	field.use_domain(grid)
	field.attach_box(ui_layer)
	var kinds: Array[StringName] = SMPointer.GTFC_KINDS
	var cells: Array[Vector2i] = [Vector2i(6, 22), Vector2i(8, 22), Vector2i(10, 22), Vector2i(6, 26), Vector2i(8, 26), Vector2i(10, 26)]
	for i: int in kinds.size():
		field.spawn(SMPointer.PLAYER, grid.cell_center(cells[i]), kinds[i])
	for cell: Vector2i in [Vector2i(26, 22), Vector2i(28, 22), Vector2i(27, 26)]:
		field.spawn(SMPointer.ENEMY, grid.cell_center(cell), &"raider")
	raider.attach(field, grid.cell_center(Vector2i(26, 22)))

func _say(text: String) -> void:
	if status != null:
		status.text = text

func _slab(node_name: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	add_child(mi)
	return mi

func _process(delta: float) -> void:
	var cam: RTSCamera = get_node_or_null("Camera") as RTSCamera
	if cam != null:
		var vp: Viewport = get_viewport()
		cam.edge_scroll(vp.get_mouse_position(), vp.get_visible_rect().size, delta)
	raider.tick(delta)
	raider.show_markers(self)
	field.tick(delta)

func _unhandled_input(event: InputEvent) -> void:
	var cam: RTSCamera = get_node_or_null("Camera") as RTSCamera
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F:
		fire_ability()
		return
	if cam == null:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		if field.handle_button(mb):
			return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam.zoom_toward(1.0, cam.ground_at(mb.position))
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam.zoom_toward(-1.0, cam.ground_at(mb.position))
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion == null:
		return
	field.handle_motion(motion)
	if (motion.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0:
		cam.orbit(motion.relative.x * 0.25)
