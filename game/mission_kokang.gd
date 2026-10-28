extends Node3D

const Fx = preload("res://game/fx_view.gd")
const Ground = preload("res://game/ground_view.gd")
## GTFC night raid. Scaffold, ruby night shift, one rare-earth node. Text briefing.

var mission: SMMission = SMMission.new()
var field: SMPointer = SMPointer.new()
var roster: SMRoster = SMRoster.new()
var side: SMSide = SMSide.new()
var hud: SMHud = SMHud.new()
var grid: SMDomainGrid
var briefing_text: String = ""
var status: Label
var ui_layer: CanvasLayer
var story: SMStory = SMStory.new()

func _ready() -> void:
	preload("res://game/sim_presenter.gd").follow(self)
	mission.setup()
	briefing_text = mission.briefing
	grid = SMDomainGrid.new(14, 9, 2.0, Vector3(-14.0, 0.0, -9.0))
	_world()
	_ui()
	roster.setup("gtfc")
	var rally: Vector3 = Vector3(-6.0, 0.0, -4.0)
	side.prepare(self, status, grid, rally, roster.economy, "gtfc")
	_arm_units()
	var cam: RTSCamera = get_node("Camera") as RTSCamera
	hud.mount(ui_layer, field, roster, side, SMCampaign.title_of("kokang"), rally, Callable(self, "fire_secondary"), grid, cam)
	hud.set_tutorial(SMGuide.tutorial_for("kokang"))
	preload("res://game/match_settings.gd").apply_scene(self)

func scripted_playthrough() -> bool:
	var ok: bool = mission.playthrough()
	briefing_text = mission.briefing
	_say("Raid complete" if ok else "Raid stalled")
	return ok

func _world() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	env.name = "WorldEnvironment"
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.05, 0.06, 0.1)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.35, 0.4, 0.55)
	add_child(env)
	var moon: DirectionalLight3D = DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-35, 40, 0)
	moon.light_color = Color(0.7, 0.75, 0.9)
	add_child(moon)
	Ground.dress(self, grid, "kokang")
	_slab("Scaffold", Vector3(2, 1, 0), Vector3(3, 2, 3), Color(0.72, 0.12, 0.18))
	_slab("RubyNode", Vector3(6, 0.4, 2), Vector3(1.5, 0.8, 1.5), Color(0.7, 0.1, 0.2))
	_slab("RareNode", Vector3(-6, 0.4, 4), Vector3(1.5, 0.8, 1.5), Color(0.4, 0.5, 0.32))
	var cam: RTSCamera = RTSCamera.new()
	cam.name = "Camera"
	cam.bounds = Rect2(-20, -16, 40, 32)
	cam.distance = 18.0
	cam.edge_pan_px = 16.0
	cam.focus = Vector3(0, 0, 2)
	add_child(cam)
	cam.current = true

func _ui() -> void:
	ui_layer = CanvasLayer.new()
	var layer: CanvasLayer = ui_layer
	add_child(layer)
	var brief: Label = Label.new()
	brief.name = "Briefing"
	brief.position = Vector2(220, 42)
	brief.size = Vector2(760, 72)
	brief.custom_minimum_size = Vector2(760, 72)
	brief.clip_text = true
	brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	brief.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brief.text = briefing_text
	layer.add_child(brief)
	var row: HBoxContainer = HBoxContainer.new()
	row.position = Vector2(176, 80)
	row.add_theme_constant_override("separation", 8)
	layer.add_child(row)
	_debug(row, "DebugScaffold", "Raise scaffold", _on_scaffold)
	_debug(row, "DebugRuby", "Ruby night shift", _on_ruby)
	_debug(row, "DebugRare", "Secure rare earth", _on_rare)
	status = Label.new()
	status.name = "Status"
	status.position = Vector2(220, 118)
	status.text = "Golden Slag / Aurum-9 stays in the yard ledger. Ruby and rare earth are the raid."
	status.size = Vector2(760, 44)
	status.custom_minimum_size = Vector2(760, 44)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.clip_text = true
	status.add_theme_font_size_override("font_size", 16)
	status.add_theme_color_override("font_color", Color(0.98, 0.9, 0.55))
	layer.add_child(status)
	var back: Button = Button.new()
	back.name = "MissionBoot"
	back.text = "Boot menu"
	back.position = Vector2(220, 166)
	back.custom_minimum_size = Vector2(160, 36)
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://game/boot.tscn")
	)
	layer.add_child(back)

func _arm_units() -> void:
	var cam: RTSCamera = get_node("Camera") as RTSCamera
	field.bind(self, cam)
	field.use_open(16, 12, 2.0, Vector3(-16.0, 0.0, -12.0))
	field.attach_box(ui_layer)
	var kinds: Array[StringName] = SMPointer.GTFC_KINDS
	for i: int in kinds.size():
		field.spawn(SMPointer.PLAYER, Vector3(-6.0 + float(i) * 2.0, 0.0, -4.0), kinds[i])
	field.spawn(SMPointer.ENEMY, Vector3(8.0, 0.0, -2.0), &"raider")
	field.spawn(SMPointer.ENEMY, Vector3(9.0, 0.0, 3.0), &"raider")
	preload("res://game/match_settings.gd").apply_story(story)
	story.bind_raid(self, mission, field, side)
	story.scale_field()

func fire_secondary() -> int:
	var n: int = field.secondary_strike()
	_say("F ability struck an enemy" if n > 0 else "F ability found no enemy")
	return n

func _debug(row: HBoxContainer, node_name: String, caption: String, fn: Callable) -> void:
	var b: Button = Button.new()
	b.name = node_name
	b.text = caption
	b.visible = false
	b.pressed.connect(fn)
	row.add_child(b)

func _on_scaffold() -> void:
	_say("Scaffold up" if mission.raise_scaffold() else "Scaffold stalled")
	_finish_if_ready()

func _on_ruby() -> void:
	_say("Night shift paying" if mission.run_night_ruby() else "Ruby not paying")
	_finish_if_ready()

func _on_rare() -> void:
	_say("Rare-earth stock secured" if mission.secure_rare() else "No stock yet")
	_finish_if_ready()

func _finish_if_ready() -> void:
	if mission.try_win():
		_say("Raid complete. Scaffold, night ruby, rare-earth stock.")

func _say(text: String) -> void:
	if status != null:
		status.text = text
	(load("res://game/match_audio.gd") as GDScript).call("announce_line", self, "gtfc", text)

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

func _process(delta: float) -> void:
	if hud.guide_blocks():
		return
	var cam: RTSCamera = get_node_or_null("Camera") as RTSCamera
	if cam == null:
		return
	var vp: Viewport = get_viewport()
	cam.edge_scroll(vp.get_mouse_position(), vp.get_visible_rect().size, delta)
	field.tick(delta)
	story.tick(delta)
	Fx.drive(self, field, null, field.ew)
	field.place_beacon(story.beacon())
	if story.lost:
		if status != null and status.text != "Objective failed":
			_say("Objective failed")
		_outro(false)
	elif story.done:
		if status != null and status.text != "Objective complete":
			_say("Objective complete")
			SMSave.mark("kokang")
		_outro(true)
	elif status != null:
		status.text = story.progress()
	hud.refresh()

func _outro(won: bool) -> void:
	preload("res://game/menu_outro.gd").show(ui_layer, won)

func _unhandled_input(event: InputEvent) -> void:
	var cam: RTSCamera = get_node_or_null("Camera") as RTSCamera
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F:
		fire_secondary()
		return
	if cam == null:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		if field.handle_button(mb):
			return
		if hud.column_hovered() and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
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
