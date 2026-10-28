extends Node3D
## Guest view of the host's company. Clicks send a move order.

const Lan = preload("res://game/lan_link.gd")

var _dots: Array[MeshInstance3D] = []
var _status: Label
var _cam: RTSCamera

func _ready() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.06, 0.07, 0.09)
	add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, 20.0, 0.0)
	add_child(sun)
	var deck: MeshInstance3D = MeshInstance3D.new()
	var slab: BoxMesh = BoxMesh.new()
	slab.size = Vector3(80.0, 0.2, 80.0)
	deck.mesh = slab
	deck.position = Vector3(0.0, -0.1, 0.0)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.18, 0.14)
	deck.material_override = mat
	add_child(deck)
	_cam = RTSCamera.new()
	_cam.name = "Camera"
	_cam.distance = 28.0
	_cam.focus = Vector3.ZERO
	add_child(_cam)
	_cam.current = true
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var title: Label = Label.new()
	title.name = "LanGuest"
	title.text = "LAN guest. Click the ground to move the host's company."
	title.position = Vector2(48.0, 36.0)
	title.size = Vector2(900.0, 28.0)
	title.add_theme_font_size_override("font_size", 18)
	layer.add_child(title)
	_status = Label.new()
	_status.name = "Status"
	_status.text = "Waiting for the host."
	_status.position = Vector2(48.0, 72.0)
	_status.size = Vector2(900.0, 40.0)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layer.add_child(_status)
	var back: Button = Button.new()
	back.name = "MissionBoot"
	back.text = "Boot menu"
	back.position = Vector2(48.0, 120.0)
	back.pressed.connect(func() -> void:
		Lan.close()
		get_tree().change_scene_to_file("res://game/boot.tscn")
	)
	layer.add_child(back)

func _process(_delta: float) -> void:
	Lan.pump()
	var raw: String = Lan.take()
	while raw != "":
		_apply(raw)
		raw = Lan.take()

func _apply(raw: String) -> void:
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var row: Dictionary = parsed
	if str(row.get("k", "")) != "state":
		return
	var xs: Variant = row.get("x", [])
	var zs: Variant = row.get("z", [])
	var ts: Variant = row.get("t", [])
	if typeof(xs) != TYPE_ARRAY or typeof(zs) != TYPE_ARRAY:
		return
	var px: Array = xs
	var pz: Array = zs
	var pt: Array = ts if typeof(ts) == TYPE_ARRAY else []
	var n: int = mini(px.size(), pz.size())
	while _dots.size() < n:
		var dot: MeshInstance3D = MeshInstance3D.new()
		var ball: SphereMesh = SphereMesh.new()
		ball.radius = 0.45
		ball.height = 0.9
		dot.mesh = ball
		dot.material_override = StandardMaterial3D.new()
		add_child(dot)
		_dots.append(dot)
	for i: int in _dots.size():
		var dot_i: MeshInstance3D = _dots[i]
		dot_i.visible = i < n
		if i >= n:
			continue
		dot_i.position = Vector3(float(px[i]), 0.6, float(pz[i]))
		var tint: Color = Color(0.72, 0.12, 0.18)
		if i < pt.size() and int(pt[i]) != 0:
			tint = Color(0.55, 0.22, 0.18)
		var skin: StandardMaterial3D = dot_i.material_override as StandardMaterial3D
		if skin != null:
			skin.albedo_color = tint
	if _status != null:
		_status.text = str(row.get("s", "Linked."))
	if n > 0 and _cam != null:
		_cam.focus = Vector3(float(px[0]), 0.0, float(pz[0]))
		_cam.apply()

func _unhandled_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_RIGHT:
		return
	if _cam == null:
		return
	var ground: Vector3 = _cam.ground_at(mb.position)
	if ground == Vector3.INF:
		return
	Lan.send({"k": "go", "x": ground.x, "z": ground.z})
