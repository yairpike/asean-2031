extends Node3D
## Shared GTFC skirmish. The map id picks the terrain. Controls match Sop Ruak.

@export var map_id: String = "burma_road"

var grid: SMDomainGrid
var sim: SMMatch = SMMatch.new()
var field: SMPointer = SMPointer.new()
var status: Label
var ui_layer: CanvasLayer

func _ready() -> void:
	grid = _grid_for(map_id)
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
	sim.yard.center = grid.cell_center(_player_cells()[0])
	sim.abilities.add_unit(10, sim.yard.center, SMAbilities.TOGGLE, 2.0, 0.6)
	sim.abilities.add_unit(11, sim.yard.center + Vector3(2.0, 0.0, 0.0), SMAbilities.SMART, 3.0, 0.6)
	sim.abilities.add_unit(12, sim.yard.center + Vector3(8.0, 0.0, 0.0), SMAbilities.SMART, 3.0, 0.6)

func _grid_for(id: String) -> SMDomainGrid:
	if id == "ten_degree_atolls":
		return SMDomainGrid.ten_degree_atolls_layout()
	if id == "mekong_delta":
		return SMDomainGrid.mekong_delta_layout()
	if id == "chiang_rai":
		return SMDomainGrid.chiang_rai_layout()
	return SMDomainGrid.burma_road_layout()

func _player_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if map_id == "ten_degree_atolls":
		cells = [Vector2i(3, 16), Vector2i(5, 16), Vector2i(7, 16), Vector2i(3, 19), Vector2i(5, 19), Vector2i(7, 19)]
	elif map_id == "mekong_delta":
		cells = [Vector2i(3, 15), Vector2i(5, 15), Vector2i(7, 15), Vector2i(3, 18), Vector2i(5, 18), Vector2i(7, 18)]
	elif map_id == "chiang_rai":
		cells = [Vector2i(4, 33), Vector2i(6, 33), Vector2i(8, 33), Vector2i(4, 36), Vector2i(6, 36), Vector2i(8, 36)]
	else:
		cells = [Vector2i(3, 13), Vector2i(5, 13), Vector2i(7, 13), Vector2i(3, 16), Vector2i(5, 16), Vector2i(7, 16)]
	return cells

func _enemy_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if map_id == "ten_degree_atolls":
		cells = [Vector2i(27, 16), Vector2i(29, 16), Vector2i(28, 19)]
	elif map_id == "mekong_delta":
		cells = [Vector2i(32, 15), Vector2i(34, 15), Vector2i(33, 18)]
	elif map_id == "chiang_rai":
		cells = [Vector2i(44, 6), Vector2i(46, 6), Vector2i(48, 6), Vector2i(44, 9), Vector2i(46, 9), Vector2i(48, 9)]
	else:
		cells = [Vector2i(32, 13), Vector2i(34, 13), Vector2i(33, 16)]
	return cells

func _move_cell() -> Vector2i:
	if map_id == "ten_degree_atolls":
		return Vector2i(6, 18)
	if map_id == "mekong_delta":
		return Vector2i(6, 20)
	if map_id == "chiang_rai":
		return Vector2i(10, 34)
	return Vector2i(10, 20)

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
	if map_id == "ten_degree_atolls":
		_atoll_world()
	elif map_id == "mekong_delta":
		_mekong_world()
	elif map_id == "chiang_rai":
		_chiang_world()
	else:
		_burma_world()
	var cam: RTSCamera = RTSCamera.new()
	cam.name = "Camera"
	var span: Vector2 = Vector2(float(grid.cols) * grid.cell_size, float(grid.rows) * grid.cell_size)
	cam.bounds = Rect2(grid.origin.x - 8.0, grid.origin.z - 8.0, span.x + 16.0, span.y + 16.0)
	cam.distance = 52.0 if map_id == "chiang_rai" else 46.0
	cam.edge_pan_px = 20.0
	cam.focus = grid.cell_center(_player_cells()[0])
	add_child(cam)
	cam.current = true

func _burma_world() -> void:
	_slab("HighlandWest", Vector3(-56, 1.4, -40), Vector3(48, 2.8, 32), Color(0.38, 0.34, 0.3))
	_slab("HighlandEast", Vector3(56, 1.4, 36), Vector3(48, 2.8, 32), Color(0.34, 0.3, 0.26))
	_slab("CliffWall", Vector3(0, 2.2, 8), Vector3(32, 4.4, 80), Color(0.42, 0.4, 0.36))
	_slab("Road", Vector3(0, 0.2, -2), Vector3(32, 0.35, 16), Color(0.46, 0.4, 0.28))

func _atoll_world() -> void:
	_slab("Sea", Vector3(0, -0.4, 0), Vector3(144, 0.3, 144), Color(0.05, 0.16, 0.32))
	_slab("WestIsle", Vector3(-52, 0.2, 2), Vector3(32, 0.5, 32), Color(0.72, 0.66, 0.42))
	_slab("EastIsle", Vector3(52, 0.2, 2), Vector3(32, 0.5, 32), Color(0.7, 0.64, 0.4))
	_slab("NorthIsle", Vector3(0, 0.2, -56), Vector3(32, 0.5, 24), Color(0.74, 0.68, 0.44))
	_slab("Shoal", Vector3(0, -0.05, 2), Vector3(64, 0.2, 16), Color(0.2, 0.45, 0.55))

func _mekong_world() -> void:
	_slab("Paddy", Vector3(0, 0, 0), Vector3(160, 0.3, 128), Color(0.28, 0.38, 0.2))
	_slab("CanalWest", Vector3(-26, -0.2, 0), Vector3(12, 0.25, 128), Color(0.08, 0.24, 0.4))
	_slab("CanalEast", Vector3(30, -0.2, 0), Vector3(12, 0.25, 128), Color(0.08, 0.24, 0.4))
	_slab("BridgeWest", Vector3(-26, 0.15, 0), Vector3(14, 0.28, 16), Color(0.45, 0.4, 0.3))
	_slab("BridgeEast", Vector3(30, 0.15, 0), Vector3(14, 0.28, 16), Color(0.45, 0.4, 0.3))

func _chiang_world() -> void:
	_slab("Plain", Vector3(0, 0, 0), Vector3(224, 0.3, 160), Color(0.32, 0.36, 0.24))
	_slab("SiegeRiver", Vector3(0, -0.25, 0), Vector3(16, 0.28, 160), Color(0.08, 0.22, 0.4))
	_slab("FordNorth", Vector3(0, 0.08, -36), Vector3(16, 0.22, 16), Color(0.42, 0.38, 0.26))
	_slab("FordSouth", Vector3(0, 0.08, 44), Vector3(16, 0.22, 16), Color(0.42, 0.38, 0.26))
	_slab("WallWest", Vector3(-72, 1.6, -50), Vector3(32, 3.2, 12), Color(0.4, 0.38, 0.34))

func _ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	var title: Label = Label.new()
	title.text = _title()
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
	status.text = _blurb()
	status.position = Vector2(16, 84)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(860, 28)
	ui_layer.add_child(status)
	var hint: Label = Label.new()
	hint.text = "Left click selects. Drag a box. Right click ground moves. Right click an enemy attacks. F fires the ability."
	hint.position = Vector2(16, 680)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(980, 28)
	ui_layer.add_child(hint)

func _title() -> String:
	if map_id == "ten_degree_atolls":
		return "GTFC  crimson / amber    Ten Degree Atolls"
	if map_id == "mekong_delta":
		return "GTFC  crimson / amber    Mekong Delta"
	if map_id == "chiang_rai":
		return "GTFC  crimson / amber    Siege of Chiang Rai"
	return "GTFC  crimson / amber    Burma Road"

func _blurb() -> String:
	if map_id == "ten_degree_atolls":
		return "Islands in deep water. Shoals are the crossings. One enemy holds the east isle."
	if map_id == "mekong_delta":
		return "Canals cut the paddies. Bridges are the crossings. One enemy holds the far bank."
	if map_id == "chiang_rai":
		return "A larger field. One enemy holds the far bank. Fords cross the river."
	return "Highland cliffs block the climb. The road is open ground. One enemy holds the east side."

func _arm_units() -> void:
	var cam: RTSCamera = get_node("Camera") as RTSCamera
	field.bind(self, cam)
	field.use_domain(grid)
	field.attach_box(ui_layer)
	var kinds: Array[StringName] = SMPointer.GTFC_KINDS
	var cells: Array[Vector2i] = _player_cells()
	for i: int in kinds.size():
		field.spawn(SMPointer.PLAYER, grid.cell_center(cells[i]), kinds[i])
	for cell: Vector2i in _enemy_cells():
		field.spawn(SMPointer.ENEMY, grid.cell_center(cell), &"raider")

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
