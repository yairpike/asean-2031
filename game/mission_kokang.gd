extends Node3D
## GTFC night raid. Scaffold, ruby night shift, one rare-earth node. Text briefing.

var mission: SMMission = SMMission.new()
var briefing_text: String = ""
var status: Label

func _ready() -> void:
	mission.setup()
	briefing_text = mission.briefing
	_world()
	_ui()

func scripted_playthrough() -> bool:
	var ok: bool = mission.playthrough()
	briefing_text = mission.briefing
	_say("Raid complete" if ok else "Raid stalled")
	return ok

func _world() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
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
	_slab("Ground", Vector3(0, -0.1, 0), Vector3(28, 0.2, 18), Color(0.18, 0.2, 0.16))
	_slab("Scaffold", Vector3(2, 1, 0), Vector3(3, 2, 3), Color(0.72, 0.12, 0.18))
	_slab("RubyNode", Vector3(6, 0.4, 2), Vector3(1.5, 0.8, 1.5), Color(0.7, 0.1, 0.2))
	_slab("RareNode", Vector3(-6, 0.4, 4), Vector3(1.5, 0.8, 1.5), Color(0.4, 0.5, 0.32))
	var cam: RTSCamera = RTSCamera.new()
	cam.name = "Camera"
	cam.bounds = Rect2(-20, -16, 40, 32)
	cam.distance = 22.0
	cam.edge_pan_px = 16.0
	cam.focus = Vector3(0, 0, 2)
	add_child(cam)
	cam.current = true

func _ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var brief: Label = Label.new()
	brief.name = "Briefing"
	brief.text = briefing_text
	brief.position = Vector2(24, 20)
	brief.custom_minimum_size = Vector2(720, 70)
	brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layer.add_child(brief)
	var row: HBoxContainer = HBoxContainer.new()
	row.position = Vector2(24, 110)
	row.add_theme_constant_override("separation", 8)
	layer.add_child(row)
	_btn(row, "Raise scaffold", _on_scaffold)
	_btn(row, "Ruby night shift", _on_ruby)
	_btn(row, "Secure rare earth", _on_rare)
	status = Label.new()
	status.name = "Status"
	status.position = Vector2(24, 160)
	status.text = "Golden Slag / Aurum-9 stays in the yard ledger. Ruby and rare earth are the raid."
	layer.add_child(status)

func _btn(row: HBoxContainer, caption: String, fn: Callable) -> void:
	var b: Button = Button.new()
	b.text = caption
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
	if cam == null:
		return
	var vp: Viewport = get_viewport()
	cam.edge_scroll(vp.get_mouse_position(), vp.get_visible_rect().size, delta)

func _unhandled_input(event: InputEvent) -> void:
	var cam: RTSCamera = get_node_or_null("Camera") as RTSCamera
	if cam == null:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		cam.zoom_toward(1.0, cam.ground_at(mb.position))
	elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		cam.zoom_toward(-1.0, cam.ground_at(mb.position))
