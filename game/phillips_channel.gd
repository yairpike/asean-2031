extends Node3D
## Phillips Channel. Two land masses, a deep channel, shallow crossings.
## RA3-style sidebar with cameo placeholders. The far shore builds, expands, and attacks.

var sim: SMMatch = SMMatch.new()
var field: SMPointer = SMPointer.new()
var raider: SMRaider = SMRaider.new()
var roster: SMRoster = SMRoster.new()
var side: SMSide = SMSide.new()
var hud: SMHud = SMHud.new()
var outcome: SMOutcome = SMOutcome.new()
var sight: SMSight = SMSight.new()
var status: Label
var explore_bus: AudioStreamPlayer
var combat_bus: AudioStreamPlayer
var ui_layer: CanvasLayer

func _ready() -> void:
	sim.setup_phillips("gtfc")
	roster.setup(SMFront.current())
	roster.price_scale = Callable(self, "_price_scale")
	_world()
	_audio()
	_ui()
	side.prepare(self, status, sim.grid, sim.yard.center, roster.economy)
	_arm_units()
	var cam: RTSCamera = get_node("Camera") as RTSCamera
	hud.mount(ui_layer, field, roster, side, "Phillips Channel", sim.yard.center, Callable(self, "fire_ability"), sim.grid, cam)
	hud.use_goods(sim.goods)
	outcome.mount(self, ui_layer)
	sight.bind(sim.grid)
	hud.use_sight(sight)
	SMSight.update_match(sight, field, self, sim.tech, raider)

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
	_slab("PlayerYard", SMPointer.building_at(sim.yard.center), SMPointer.BUILDING_SIZE, SMFront.primary())
	_slab("EnemyBase", SMPointer.building_at(sim.grid.cell_center(Vector2i(32, 12))), SMPointer.BUILDING_SIZE, Color(0.16, 0.17, 0.18))
	sim.paint_sites(self)
	_capsule("Jammer", sim.ew.center + Vector3(0, 1.2, 0), Color(0.15, 0.75, 0.82))
	var cam: RTSCamera = RTSCamera.new()
	cam.name = "Camera"
	cam.bounds = Rect2(-90, -60, 180, 120)
	cam.distance = 48.0
	cam.edge_pan_px = 20.0
	cam.focus = Vector3(-58, 0, -12)
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
	bar.position = Vector2(250, 48)
	bar.add_theme_constant_override("separation", 8)
	layer.add_child(bar)
	_proto_button(bar, "Logistics", &"logistics")
	_proto_button(bar, "Arsenal", &"arsenal")
	_proto_button(bar, "Oracle", &"oracle")
	var actions: HBoxContainer = HBoxContainer.new()
	actions.name = "MatchActions"
	actions.position = Vector2(250, 88)
	actions.add_theme_constant_override("separation", 8)
	layer.add_child(actions)
	_action(actions, "Train unit", _on_train)
	_action(actions, "Build pipeline", _on_build)
	_action(actions, "Cross channel", _on_cross)
	_action(actions, "Engage", _on_engage)
	status = Label.new()
	status.name = "Status"
	status.text = "Raise a yard, claim Golden Slag / Aurum-9, cross, then press F."
	status.position = Vector2(250, 608)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(740, 24)
	layer.add_child(status)

func _arm_units() -> void:
	var cam: RTSCamera = get_node("Camera") as RTSCamera
	field.bind_faction(self, cam, SMFront.current())
	field.ew = sim.ew
	field.use_domain(sim.grid)
	field.attach_box(ui_layer)
	var kinds: Array[StringName] = SMFront.kinds()
	var cells: Array[Vector2i] = [Vector2i(1, 8), Vector2i(3, 8), Vector2i(5, 8), Vector2i(8, 8), Vector2i(10, 8), Vector2i(12, 8)]
	for i: int in kinds.size():
		field.spawn(SMPointer.PLAYER, sim.grid.cell_center(cells[i]), kinds[i])
	for cell: Vector2i in [Vector2i(30, 12), Vector2i(31, 14), Vector2i(33, 11)]:
		field.spawn(SMPointer.ENEMY, sim.grid.cell_center(cell), &"raider")
	raider.attach(field, sim.grid.cell_center(Vector2i(30, 12)))

func _proto_button(bar: HBoxContainer, caption: String, branch: StringName) -> void:
	var b: Button = Button.new()
	b.text = caption
	b.pressed.connect(func() -> void:
		var target: int = 10 if sim.abilities.index_of(10) >= 0 else -1
		var ok: bool = sim.protocols.cast(branch, sim.economy, sim.player, sim.abilities, target)
		_say("protocol %s" % str(branch) if ok else "protocol spent")
	)
	bar.add_child(b)

func _action(row: HBoxContainer, caption: String, fn: Callable) -> void:
	var b: Button = Button.new()
	b.text = caption
	b.pressed.connect(fn)
	row.add_child(b)

func train_unit() -> String:
	var done: StringName = roster.train_and_finish(SMFront.train_kind())
	if done == &"":
		return ""
	var at: Vector3 = sim.grid.cell_center(Vector2i(1, 6))
	var u: RTSUnit = field.spawn(SMPointer.PLAYER, at, done)
	var label: String = field.name_of(u)
	_say(label)
	return label

func _on_train() -> void:
	train_unit()

func _on_build() -> void:
	_say("pipeline ready" if sim.run_player_pipeline() else "pipeline blocked")

func _on_cross() -> void:
	_say("crossed" if sim.cross_channel() else "cannot cross")

func fire_ability() -> bool:
	var cam: RTSCamera = get_node_or_null("Camera") as RTSCamera
	var cast: String = field.cast_f(field.aim_from_camera(cam, get_viewport().get_mouse_position()))
	var ok: bool = cast != "" or sim.use_f()
	_say("ability fired" if ok else "ability not ready")
	return ok

func _on_ability() -> void:
	fire_ability()

func _price_scale(id: StringName) -> float:
	return sim.tech.discount(SMPointer.PLAYER, roster.unit_tag(id))

## Income, night shift, rare-earth stock, water harm, cyber siphon, and clinic healing.
func tick_world(delta: float) -> void:
	sim.tick_live(delta, roster.economy, field)
	sim.show_collectors(self)
	side.yard.cool_super(delta)

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
	raider.tick(delta)
	raider.show_markers(self)
	field.tick(delta)
	tick_world(delta)
	sight.advance_weather(delta)
	SMSight.update_match(sight, field, self, sim.tech, raider)
	hud.refresh()
	var players: Array[SMBuildYard] = [side.yard, sim.yard]
	var foes: Array[SMBuildYard] = [raider.yard]
	outcome.tick(field, players, foes, delta)

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
