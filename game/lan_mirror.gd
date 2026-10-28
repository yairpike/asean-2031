extends Node3D
## Guest view of the host's match. Orders go to the guest's own side.

const Lan = preload("res://game/lan_link.gd")
const Seat = preload("res://game/lan_seat.gd")

var _dots: Dictionary = {}
var _blocks: Dictionary = {}
var _status: Label
var _purse: Label
var _cam: RTSCamera
var _picked: Array[int] = []
var _train: String = ""
var _build: String = ""
var _sell: String = ""
var _proto: String = "cash_bounty"
var _home: Vector3 = Vector3.ZERO
var _fog: PackedByteArray = PackedByteArray()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	slab.size = Vector3(160.0, 0.2, 120.0)
	deck.mesh = slab
	deck.position = Vector3(0.0, -0.1, 0.0)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.18, 0.14)
	deck.material_override = mat
	add_child(deck)
	_cam = RTSCamera.new()
	_cam.name = "Camera"
	_cam.distance = 32.0
	_cam.focus = Vector3.ZERO
	add_child(_cam)
	_cam.current = true
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var title: Label = Label.new()
	title.name = "LanGuest"
	title.text = "LAN guest. Your company, your base."
	title.position = Vector2(48.0, 24.0)
	title.size = Vector2(900.0, 28.0)
	title.add_theme_font_size_override("font_size", 18)
	layer.add_child(title)
	_status = Label.new()
	_status.name = "Status"
	_status.text = "Waiting for the host."
	_status.position = Vector2(48.0, 56.0)
	_status.size = Vector2(900.0, 36.0)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layer.add_child(_status)
	_purse = Label.new()
	_purse.name = "LanPurse"
	_purse.text = "Credits 0    Power 0/0"
	_purse.position = Vector2(48.0, 96.0)
	_purse.size = Vector2(900.0, 28.0)
	layer.add_child(_purse)
	_orders(layer)
	var back: Button = Button.new()
	back.name = "MissionBoot"
	back.text = "Boot menu"
	back.position = Vector2(48.0, 168.0)
	back.pressed.connect(func() -> void:
		Lan.close()
		get_tree().change_scene_to_file("res://game/boot.tscn")
	)
	layer.add_child(back)

func _orders(layer: CanvasLayer) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "LanOrders"
	row.position = Vector2(220.0, 168.0)
	row.add_theme_constant_override("separation", 6)
	layer.add_child(row)
	_order(row, "LanTrain", "Train", _send_train)
	_order(row, "LanBuild", "Build", _send_build)
	_order(row, "LanPlace", "Place", _send_place)
	_order(row, "LanSell", "Sell", _send_sell)
	_order(row, "LanRepair", "Repair", _send_repair)
	_order(row, "LanAbility", "Ability", _send_ability)
	_order(row, "LanProtocol", "Protocol", _send_protocol)

func _order(row: HBoxContainer, node_name: String, caption: String, fn: Callable) -> void:
	var b: Button = Button.new()
	b.name = node_name
	b.text = caption
	b.pressed.connect(fn)
	row.add_child(b)

func _process(delta: float) -> void:
	var seat: Seat = Lan.seat()
	Lan.pump()
	Lan.pulse(delta)
	var raw: String = Lan.take()
	while raw != "":
		var kind: String = seat.ingest(raw)
		if kind == "state":
			_apply(raw)
		raw = Lan.take()
	Lan.watch(delta)
	if seat.winner == "guest":
		_status.text = "Opponent left. Victory."
	elif seat.winner == "host":
		_status.text = "Opponent left. Defeat."
	elif seat.paused:
		_status.text = "Paused. Waiting for the other player."

func _apply(raw: String) -> void:
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var row: Dictionary = parsed
	if str(row.get("k", "")) != "state":
		return
	if bool(row.get("full", false)):
		_clear_dots()
		_train = str(row.get("train", _train))
		_build = str(row.get("build", _build))
		_sell = str(row.get("sell", _sell))
		_proto = str(row.get("proto", _proto))
		var home: Variant = row.get("home", [])
		if typeof(home) == TYPE_ARRAY and (home as Array).size() >= 2:
			var pair: Array = home
			_home = Vector3(float(pair[0]), 0.0, float(pair[1]))
		var fog: Variant = row.get("fog", "")
		if typeof(fog) == TYPE_STRING and str(fog) != "":
			_fog = str(fog).to_ascii_buffer()
			for i: int in _fog.size():
				_fog[i] = maxi(0, int(_fog[i]) - 48)
	_merge_fog(row)
	var gone: Variant = row.get("gone", [])
	if typeof(gone) == TYPE_ARRAY:
		for item: Variant in gone:
			_drop_dot(int(item))
	var units: Variant = row.get("u", [])
	if typeof(units) == TYPE_ARRAY:
		for item_u: Variant in units:
			if typeof(item_u) != TYPE_ARRAY:
				continue
			var bits: Array = item_u
			if bits.size() < 6:
				continue
			_move_dot(int(bits[0]), float(bits[1]), float(bits[2]), int(bits[4]))
	_blocks(row.get("b", []))
	if _purse != null and row.has("credits"):
		var names: String = ""
		var q: Variant = row.get("q", [])
		if typeof(q) == TYPE_ARRAY and not (q as Array).is_empty():
			names = "    " + str((q as Array)[0])
		_purse.text = "Credits %d    Power %d/%d%s" % [int(row.get("credits", 0)), int(row.get("gen", 0)), int(row.get("use", 0)), names]
	if _status != null and str(row.get("winner", "")) == "" and not bool(row.get("pause", false)):
		_status.text = "Linked. %d units." % int(row.get("n", 0))
	if _cam != null and _home != Vector3.ZERO:
		_cam.focus = _home
		_cam.apply()

func _send_train() -> void:
	if _train != "":
		Lan.send({"k": "cmd", "op": "train", "id": _train})

func _send_build() -> void:
	if _build != "":
		Lan.send({"k": "cmd", "op": "build", "id": _build})

func _send_place() -> void:
	if _build != "":
		Lan.send({"k": "cmd", "op": "place", "id": _build, "x": _home.x, "z": _home.z})

func _send_sell() -> void:
	if _sell != "":
		Lan.send({"k": "cmd", "op": "sell", "id": _sell})

func _send_repair() -> void:
	if _sell != "":
		Lan.send({"k": "cmd", "op": "repair", "id": _sell})

func _send_ability() -> void:
	Lan.send({"k": "cmd", "op": "ability", "ids": _picked_or_own(), "x": _home.x + 4.0, "z": _home.z})

func _send_protocol() -> void:
	Lan.send({"k": "cmd", "op": "protocol", "id": _proto})

func _picked_or_own() -> Array:
	var ids: Array = []
	if not _picked.is_empty():
		for uid: int in _picked:
			ids.append(uid)
		return ids
	for key: Variant in _dots.keys():
		ids.append(int(key))
	return ids

func _unhandled_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_RIGHT:
		return
	if _cam == null:
		return
	var ground: Vector3 = _cam.ground_at(mb.position)
	if ground == Vector3.INF:
		return
	var ids: Array = _picked_or_own()
	if ids.is_empty():
		return
	Lan.send({"k": "cmd", "op": "move", "ids": ids, "x": ground.x, "z": ground.z})

func _move_dot(uid: int, x: float, z: float, team: int) -> void:
	var dot: MeshInstance3D = _dots.get(uid, null) as MeshInstance3D
	if dot == null:
		dot = MeshInstance3D.new()
		var ball: SphereMesh = SphereMesh.new()
		ball.radius = 0.45
		ball.height = 0.9
		dot.mesh = ball
		dot.material_override = StandardMaterial3D.new()
		add_child(dot)
		_dots[uid] = dot
	dot.position = Vector3(x, 0.6, z)
	var skin: StandardMaterial3D = dot.material_override as StandardMaterial3D
	if skin != null:
		skin.albedo_color = Color(0.12, 0.62, 0.7) if team == 1 else Color(0.72, 0.12, 0.18)

func _drop_dot(uid: int) -> void:
	var dot: MeshInstance3D = _dots.get(uid, null) as MeshInstance3D
	if dot != null:
		dot.queue_free()
	_dots.erase(uid)

func _clear_dots() -> void:
	for key: Variant in _dots.keys():
		var dot: MeshInstance3D = _dots[key] as MeshInstance3D
		if dot != null:
			dot.queue_free()
	_dots.clear()

func _blocks(raw: Variant) -> void:
	if typeof(raw) != TYPE_ARRAY:
		return
	var rows: Array = raw
	var seen: Dictionary = {}
	for item: Variant in rows:
		if typeof(item) != TYPE_ARRAY:
			continue
		var bits: Array = item
		if bits.size() < 5:
			continue
		var id: String = str(bits[0])
		seen[id] = true
		var block: MeshInstance3D = _blocks.get(id, null) as MeshInstance3D
		if block == null:
			block = MeshInstance3D.new()
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3(2.4, 1.4, 2.4)
			block.mesh = box
			block.material_override = StandardMaterial3D.new()
			add_child(block)
			_blocks[id] = block
		block.position = Vector3(float(bits[1]), 0.7, float(bits[2]))
		var skin: StandardMaterial3D = block.material_override as StandardMaterial3D
		if skin != null:
			skin.albedo_color = Color(0.15, 0.55, 0.62) if int(bits[4]) == 1 else Color(0.55, 0.16, 0.18)
	var drop: Array = []
	for key: Variant in _blocks.keys():
		if not seen.has(key):
			drop.append(key)
	for key_drop: Variant in drop:
		var old: MeshInstance3D = _blocks[key_drop] as MeshInstance3D
		if old != null:
			old.queue_free()
		_blocks.erase(key_drop)

func _merge_fog(row: Dictionary) -> void:
	var fi: Variant = row.get("fi", [])
	var fv: Variant = row.get("fv", [])
	if typeof(fi) != TYPE_ARRAY or typeof(fv) != TYPE_ARRAY:
		return
	var idx: Array = fi
	var vals: Array = fv
	var n: int = mini(idx.size(), vals.size())
	for i: int in n:
		var at: int = int(idx[i])
		if at >= 0 and at < _fog.size():
			_fog[at] = int(vals[i])
