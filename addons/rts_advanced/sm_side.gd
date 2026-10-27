class_name SMSide
extends RefCounted
## Build-style buttons for the faction chosen on the boot screen.

var faction_id: String = "gtfc"
var yard: SMBuildYard = SMBuildYard.new()
var economy: RTSEconomy = RTSEconomy.new()
var packer_mesh: MeshInstance3D
var hub_mesh: MeshInstance3D
var host: Node3D
var layer: CanvasLayer
var status: Label

func prepare(p_host: Node3D, p_layer: CanvasLayer, p_status: Label, grid: SMDomainGrid, center: Vector3) -> void:
	host = p_host
	layer = p_layer
	status = p_status
	faction_id = SMFront.current()
	if faction_id == "gtfc":
		return
	economy.set_credits(0, 4000)
	var data: Dictionary = SMCatalog.faction(faction_id)
	yard.team = 0
	yard.economy = economy
	yard.center = center
	yard.radius = float(data.get("yard_radius", 14))
	_load_buildings(data)
	if faction_id == "mvd":
		yard.style = SMBuildYard.Style.INTERNAL
		yard.clearance = 1
		hub_mesh = _slab("HubShell", center + Vector3(4.0, 1.2, 0.0), Vector3(4, 2.4, 4), Color.html("#26BFD1"))
		hub_mesh.visible = false
		_button("QueueHub", "Queue hub", Vector2(16, 128), Callable(self, "queue_hub"))
		_button("BuyClearance", "Buy clearance", Vector2(180, 128), Callable(self, "buy_clearance"))
		_button("PlaceHub", "Place hub", Vector2(380, 128), Callable(self, "place_hub"))
	else:
		yard.style = SMBuildYard.Style.MOBILE
		yard.grid = grid
		yard.packer_pos = center
		packer_mesh = _slab("PackerCore", center + Vector3(0, 0.8, 0), Vector3(3.2, 1.6, 5.0), Color.html("#1F9E66"))
		_button("MovePacker", "Move packer", Vector2(16, 128), Callable(self, "move_packer"))
		_button("UnpackCore", "Unpack", Vector2(180, 128), Callable(self, "unpack_core"))
		_button("UpgradeWharf", "Upgrade wharf", Vector2(320, 128), Callable(self, "upgrade_wharf"))

func move_packer() -> bool:
	if faction_id != "nmrf":
		return false
	var dest: Vector3 = yard.packer_pos + Vector3(8.0, 0.0, 0.0)
	var ok: bool = yard.move_packer(dest)
	if ok and packer_mesh != null:
		packer_mesh.position = dest + Vector3(0, 0.8, 0)
	_say("packer sailed" if ok else "packer stayed packed")
	return ok

func unpack_core() -> bool:
	if faction_id != "nmrf":
		return false
	var ok: bool = yard.unpack(&"gun_wharf")
	_say("wharf unpacked" if ok else "already unpacked")
	return ok

func upgrade_wharf() -> bool:
	if faction_id != "nmrf":
		return false
	var ok: bool = yard.upgrade_factory(&"gun_wharf")
	_say("wharf level %d" % yard.factory_level(&"gun_wharf") if ok else "wharf not ready")
	return ok

func queue_hub() -> bool:
	if faction_id != "mvd":
		return false
	var ok: bool = yard.queue_internal(&"command_hub")
	if ok:
		yard.advance(5.0)
	_say("hub ready to place" if ok and yard.ready.has(&"command_hub") else "hub not queued")
	return ok and yard.ready.has(&"command_hub")

func buy_clearance() -> bool:
	if faction_id != "mvd":
		return false
	var level: int = yard.clearance + 1
	var ok: bool = yard.buy_clearance(level, 200)
	_say("clearance %d" % yard.clearance if ok else "clearance refused")
	return ok

func place_hub() -> bool:
	if faction_id != "mvd":
		return false
	var pos: Vector3 = yard.center + Vector3(4.0, 0.0, 0.0)
	var ok: bool = yard.place_finished(&"command_hub", pos)
	if ok and hub_mesh != null:
		hub_mesh.position = pos + Vector3(0, 1.2, 0)
		hub_mesh.visible = true
	_say("hub placed" if ok else "hub not ready")
	return ok

func _load_buildings(data: Dictionary) -> void:
	var raw: Variant = data.get("buildings", [])
	if not (raw is Array):
		return
	for item: Variant in raw:
		if item is Dictionary:
			var id: StringName = StringName(str(item.get("id", "")))
			yard.building_tier[id] = int(item.get("tier", 1))
			yard.building_time[id] = float(item.get("time", 4.0))

func _button(node_name: String, caption: String, pos: Vector2, fn: Callable) -> void:
	var b: Button = Button.new()
	b.name = node_name
	b.text = caption
	b.position = pos
	b.pressed.connect(fn)
	layer.add_child(b)

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
	host.add_child(mi)
	return mi
