extends Node3D
## Phillips Channel. Two land masses, a deep channel, shallow crossings.
## RA3-style sidebar with cameo placeholders. Passive opponent on the far shore.

var sim: SMMatch = SMMatch.new()
var field: SMPointer = SMPointer.new()
var status: Label
var explore_bus: AudioStreamPlayer
var combat_bus: AudioStreamPlayer
var ui_layer: CanvasLayer

func _ready() -> void:
	sim.setup_phillips("gtfc")
	_world()
	_audio()
	_ui()
	_arm_units()

func scripted_playthrough() -> bool:
	return sim.script_phillips()

func _world() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.08, 0.12, 0.16)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.6, 0.66)
	add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 20, 0)
	add_child(sun)
	_slab("WestLand", Vector3(-50, 0, 0), Vector3(60, 0.4, 96), Color(0.34, 0.32, 0.24))
	_slab("EastLand", Vector3(50, 0, 0), Vector3(60, 0.4, 96), Color(0.28, 0.34, 0.26))
	_slab("DeepChannel", Vector3(0, -0.2, 0), Vector3(40, 0.3, 96), Color(0.08, 0.22, 0.42))
	_slab("ShallowNorth", Vector3(0, 0.05, -26), Vector3(40, 0.25, 12), Color(0.2, 0.45, 0.55))
	_slab("ShallowSouth", Vector3(0, 0.05, 26), Vector3(40, 0.25, 12), Color(0.2, 0.45, 0.55))
	_slab("PlayerYard", sim.yard.center + Vector3(0, 1.2, 0), Vector3(4, 2.4, 4), Color(0.72, 0.12, 0.18))
	_slab("EnemyBase", sim.grid.cell_center(Vector2i(32, 12)) + Vector3(0, 1.2, 0), Vector3(4, 2.4, 4), Color(0.16, 0.17, 0.18))
	var slag_pos: Vector3 = sim.goods.nodes[0]["pos"] as Vector3
	_slab("NodeMarker", slag_pos + Vector3(0, 0.5, 0), Vector3(1.6, 0.8, 1.6), Color(0.88, 0.62, 0.12))
	_capsule("Jammer", sim.ew.center + Vector3(0, 1.2, 0), Color(0.15, 0.75, 0.82))
	var cam: RTSCamera = RTSCamera.new()
	cam.name = "Camera"
	cam.bounds = Rect2(-90, -60, 180, 120)
	cam.distance = 48.0
	cam.edge_pan_px = 20.0
	cam.focus = Vector3(-20, 0, 0)
	add_child(cam)
	cam.current = true

func _audio() -> void:
	var silent: AudioStreamWAV = AudioStreamWAV.new()
	silent.format = AudioStreamWAV.FORMAT_16_BITS
	silent.mix_rate = 22050
	silent.stereo = false
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(882)
	silent.data = bytes
	explore_bus = AudioStreamPlayer.new()
	explore_bus.name = "ExploreStem"
	explore_bus.stream = silent
	explore_bus.volume_db = -8.0
	add_child(explore_bus)
	combat_bus = AudioStreamPlayer.new()
	combat_bus.name = "CombatStem"
	combat_bus.stream = silent
	combat_bus.volume_db = -80.0
	add_child(combat_bus)
	explore_bus.play()
	combat_bus.play()

func _ui() -> void:
	ui_layer = CanvasLayer.new()
	var layer: CanvasLayer = ui_layer
	add_child(layer)
	var bar: HBoxContainer = HBoxContainer.new()
	bar.name = "Protocols"
	bar.position = Vector2(16, 12)
	bar.add_theme_constant_override("separation", 8)
	layer.add_child(bar)
	_proto_button(bar, "Logistics", &"logistics")
	_proto_button(bar, "Arsenal", &"arsenal")
	_proto_button(bar, "Oracle", &"oracle")
	var side: VBoxContainer = VBoxContainer.new()
	side.name = "Sidebar"
	side.position = Vector2(1060, 16)
	side.custom_minimum_size = Vector2(200, 640)
	side.add_theme_constant_override("separation", 6)
	layer.add_child(side)
	var title: Label = Label.new()
	title.text = "GTFC  crimson / amber"
	side.add_child(title)
	var data: Dictionary = SMCatalog.faction("gtfc")
	var units: Array[Dictionary] = SMCatalog.units_of(data)
	for i: int in units.size():
		var row: HBoxContainer = HBoxContainer.new()
		row.name = "Cameo%d" % i
		var swatch: ColorRect = ColorRect.new()
		swatch.custom_minimum_size = Vector2(54, 54)
		swatch.color = Color(0.72, 0.12, 0.18) if i % 2 == 0 else Color(0.88, 0.62, 0.12)
		row.add_child(swatch)
		var cap: Label = Label.new()
		cap.text = "%s\n%s" % [str(units[i].get("cameo", "")), str(units[i].get("display_name", ""))]
		row.add_child(cap)
		side.add_child(row)
	_action(side, "Build pipeline", _on_build)
	_action(side, "Cross channel", _on_cross)
	_action(side, "Ability (F)", _on_ability)
	_action(side, "Engage", _on_engage)
	status = Label.new()
	status.name = "Status"
	status.text = "Raise a yard, claim Golden Slag / Aurum-9, cross, then press F."
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(190, 80)
	side.add_child(status)
	var hint: Label = Label.new()
	hint.text = "Left click selects. Drag a box. Right click ground moves. Right click an enemy attacks."
	hint.position = Vector2(16, 680)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(900, 28)
	layer.add_child(hint)

func _arm_units() -> void:
	var cam: RTSCamera = get_node("Camera") as RTSCamera
	field.bind(self, cam)
	field.use_domain(sim.grid)
	field.attach_box(ui_layer)
	for cell: Vector2i in [Vector2i(2, 12), Vector2i(2, 14), Vector2i(3, 15), Vector2i(8, 14)]:
		field.spawn(SMPointer.PLAYER, sim.grid.cell_center(cell), &"militia")
	for cell: Vector2i in [Vector2i(30, 12), Vector2i(31, 14), Vector2i(33, 11)]:
		field.spawn(SMPointer.ENEMY, sim.grid.cell_center(cell), &"raider")

func _proto_button(bar: HBoxContainer, caption: String, branch: StringName) -> void:
	var b: Button = Button.new()
	b.text = caption
	b.pressed.connect(func() -> void:
		var target: int = 10 if sim.abilities.index_of(10) >= 0 else -1
		var ok: bool = sim.protocols.cast(branch, sim.economy, sim.player, sim.abilities, target)
		_say("protocol %s" % str(branch) if ok else "protocol spent")
	)
	bar.add_child(b)

func _action(side: VBoxContainer, caption: String, fn: Callable) -> void:
	var b: Button = Button.new()
	b.text = caption
	b.pressed.connect(fn)
	side.add_child(b)

func _on_build() -> void:
	_say("pipeline ready" if sim.run_player_pipeline() else "pipeline blocked")

func _on_cross() -> void:
	_say("crossed" if sim.cross_channel() else "cannot cross")

func _on_ability() -> void:
	_say("ability fired" if sim.use_f() else "ability not ready")

func _on_engage() -> void:
	_say("channel clear" if sim.fight_passive() else "still fighting")

func _say(text: String) -> void:
	if status != null:
		status.text = text

func _slab(node_name: String, pos: Vector3, size: Vector3, color: Color) -> void:
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

func _capsule(node_name: String, pos: Vector3, color: Color) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = 0.55
	mesh.height = 2.0
	mi.mesh = mesh
	mi.position = pos
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	add_child(mi)

func _process(delta: float) -> void:
	var cam: RTSCamera = get_node_or_null("Camera") as RTSCamera
	if cam != null:
		var vp: Viewport = get_viewport()
		cam.edge_scroll(vp.get_mouse_position(), vp.get_visible_rect().size, delta)
	if explore_bus != null and combat_bus != null and sim.audio != null:
		explore_bus.volume_db = linear_to_db(maxf(sim.audio.exploration, 0.001))
		combat_bus.volume_db = linear_to_db(maxf(sim.audio.combat, 0.001))
	field.tick(delta)

func _unhandled_input(event: InputEvent) -> void:
	var cam: RTSCamera = get_node_or_null("Camera") as RTSCamera
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F:
		_on_ability()
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
