extends Node3D
## One solo text briefing. The objective button runs the sim system for that mission.

var campaign: SMCampaign = SMCampaign.new()
var field: SMPointer = SMPointer.new()
var roster: SMRoster = SMRoster.new()
var side: SMSide = SMSide.new()
var hud: SMHud = SMHud.new()
var grid: SMDomainGrid
var briefing_text: String = ""
var mission_id: String = ""
var status: Label
var ui_layer: CanvasLayer

func _ready() -> void:
	mission_id = SMCampaign.selected
	if mission_id == "":
		mission_id = "tachileik"
	briefing_text = SMCampaign.briefing_of(mission_id)
	grid = SMDomainGrid.new(18, 12, 2.0, Vector3(-18.0, 0.0, -12.0))
	_world()
	_ui()
	roster.setup("gtfc")
	var rally: Vector3 = Vector3(-6.0, 0.0, -2.0)
	side.prepare(self, status, grid, rally, roster.economy, "gtfc")
	_arm_units()
	var cam: RTSCamera = get_node("Camera") as RTSCamera
	hud.mount(ui_layer, field, roster, side, SMCampaign.title_of(mission_id), rally, Callable(self, "fire_secondary"), grid, cam)

func scripted_playthrough() -> bool:
	return finish_objective()

func finish_objective() -> bool:
	var ok: bool = campaign.play(mission_id)
	_say(campaign.result_text)
	return ok

func fire_secondary() -> int:
	return field.secondary_strike()

func _world() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.06, 0.07, 0.09)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.52, 0.56)
	add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 20, 0)
	add_child(sun)
	_slab("Ground", Vector3(0, -0.1, 0), Vector3(36, 0.2, 24), Color(0.22, 0.24, 0.2))
	var cam: RTSCamera = RTSCamera.new()
	cam.name = "Camera"
	cam.bounds = Rect2(-24, -20, 48, 40)
	cam.distance = 24.0
	cam.edge_pan_px = 16.0
	cam.focus = Vector3(0, 0, 2)
	add_child(cam)
	cam.current = true

func _ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	var title: Label = Label.new()
	title.text = SMCampaign.title_of(mission_id)
	title.position = Vector2(224, 48)
	ui_layer.add_child(title)
	var brief: Label = Label.new()
	brief.name = "Briefing"
	brief.text = briefing_text
	brief.position = Vector2(224, 76)
	brief.custom_minimum_size = Vector2(780, 48)
	brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui_layer.add_child(brief)
	var goal: Button = Button.new()
	goal.name = "ObjectiveButton"
	goal.text = "Complete objective"
	goal.position = Vector2(224, 132)
	goal.pressed.connect(finish_objective)
	ui_layer.add_child(goal)
	var back: Button = Button.new()
	back.text = "Boot menu"
	back.position = Vector2(420, 132)
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://game/boot.tscn")
	)
	ui_layer.add_child(back)
	status = Label.new()
	status.name = "Status"
	status.text = "Read the briefing, then complete the objective."
	status.position = Vector2(224, 176)
	ui_layer.add_child(status)

func _arm_units() -> void:
	var cam: RTSCamera = get_node("Camera") as RTSCamera
	field.bind(self, cam)
	field.use_open(20, 16, 2.0, Vector3(-20.0, 0.0, -16.0))
	field.attach_box(ui_layer)
	var kinds: Array[StringName] = [&"militia", &"ruby_lancer", &"amber_tank"]
	for i: int in kinds.size():
		field.spawn(SMPointer.PLAYER, Vector3(-6.0 + float(i) * 2.4, 0.0, -2.0), kinds[i])
	field.spawn(SMPointer.ENEMY, Vector3(6.0, 0.0, 3.0), &"raider")

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

func _process(delta: float) -> void:
	var cam: RTSCamera = get_node_or_null("Camera") as RTSCamera
	if cam != null:
		var vp: Viewport = get_viewport()
		cam.edge_scroll(vp.get_mouse_position(), vp.get_visible_rect().size, delta)
	field.tick(delta)
	hud.refresh()

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
