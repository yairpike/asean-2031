extends Node3D
## Placeholder capsules and boxes: one of each build style, each node, one jammer.

func _ready() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.12, 0.13, 0.15)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.62, 0.66)
	add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -25, 0)
	add_child(sun)
	var ground: MeshInstance3D = _box("Ground", Vector3(0, -0.2, 0), Vector3(40, 0.2, 28), Color(0.32, 0.36, 0.3))
	ground.rotation = Vector3.ZERO
	_capsule("BuildScaffold", Vector3(-8, 1.1, 0), Color(0.72, 0.12, 0.18))
	_box("BuildInternal", Vector3(0, 1.0, 0), Vector3(2.2, 2.0, 2.2), Color(0.16, 0.17, 0.18))
	_capsule("BuildMobile", Vector3(8, 1.1, 0), Color(0.35, 0.42, 0.16))
	_node_box("NodeSlag", Vector3(-8, 0.45, 6), Color(0.72, 0.55, 0.12), "Golden Slag / Aurum-9")
	_node_box("NodeRare", Vector3(-4, 0.45, 6), Color(0.45, 0.55, 0.35), "rare earth")
	_node_box("NodeRuby", Vector3(0, 0.45, 6), Color(0.7, 0.12, 0.22), "ruby")
	_node_box("NodeJade", Vector3(4, 0.45, 6), Color(0.15, 0.62, 0.4), "jade")
	_node_box("NodeBullion", Vector3(8, 0.45, 6), Color(0.85, 0.72, 0.25), "gold bullion")
	_capsule("Jammer", Vector3(0, 1.4, -6), Color(0.15, 0.75, 0.82))
	var cam: RTSCamera = RTSCamera.new()
	cam.name = "Camera"
	cam.bounds = Rect2(-30, -20, 60, 40)
	cam.distance = 20.0
	cam.edge_pan_px = 18.0
	cam.focus = Vector3(0, 0, 1)
	add_child(cam)
	cam.current = true
	var label: Label = Label.new()
	label.name = "Caption"
	label.text = "Greybox: scaffold, internal queue, mobile core, five nodes, jammer"
	label.position = Vector2(16, 12)
	var layer: CanvasLayer = CanvasLayer.new()
	layer.add_child(label)
	add_child(layer)
	preload("res://game/settings_panel.gd").attach(layer)
	preload("res://game/match_settings.gd").apply_scene(self)
	var fitter: Node = Node.new()
	fitter.name = "CameraFit"
	fitter.set_script(preload("res://game/camera_fit.gd"))
	add_child(fitter)

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
	if mb != null and mb.pressed:
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam.zoom_toward(1.0, cam.ground_at(mb.position))
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam.zoom_toward(-1.0, cam.ground_at(mb.position))
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			cam.orbit(8.0 if mb.shift_pressed else 0.0)
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and (motion.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0:
		cam.orbit(motion.relative.x * 0.25)

func _box(node_name: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = _mat(color)
	add_child(mi)
	return mi

func _capsule(node_name: String, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = 0.7
	mesh.height = 2.2
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = _mat(color)
	add_child(mi)
	return mi

func _node_box(node_name: String, pos: Vector3, color: Color, caption: String) -> void:
	_box(node_name, pos, Vector3(1.4, 0.7, 1.4), color)
	var lab: Label3D = Label3D.new()
	lab.text = caption
	lab.font_size = 28
	lab.position = pos + Vector3(0, 1.1, 0)
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(lab)

func _mat(color: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	return mat
