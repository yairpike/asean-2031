class_name SMSide
extends RefCounted
## Build-style buttons for the faction chosen on the boot screen.

var faction_id: String = "gtfc"
var yard: SMBuildYard = SMBuildYard.new()
var economy: RTSEconomy = RTSEconomy.new()
var packer_mesh: MeshInstance3D
var hub_mesh: MeshInstance3D
var host: Node3D
var status: Label
var building_hp: Dictionary[StringName, float] = {}

func prepare(p_host: Node3D, p_status: Label, grid: SMDomainGrid, center: Vector3, purse: RTSEconomy, p_faction: String = "") -> void:
	host = p_host
	status = p_status
	faction_id = p_faction if p_faction != "" else SMFront.current()
	economy = purse
	var data: Dictionary = SMCatalog.faction(faction_id)
	yard.team = 0
	yard.economy = purse
	yard.center = center
	yard.radius = float(data.get("yard_radius", 14))
	yard.drain_per_sec = 5
	_load_buildings(data)
	_load_order(data)
	var style_name: String = str(data.get("build_style", "scaffold"))
	if style_name == "internal":
		yard.style = SMBuildYard.Style.INTERNAL
		yard.clearance = 1
		hub_mesh = _slab("HubShell", center + Vector3(4.0, 1.2, 0.0), Vector3(4, 2.4, 4), Color.html("#26BFD1"))
		hub_mesh.visible = false
	elif style_name == "mobile":
		yard.style = SMBuildYard.Style.MOBILE
		yard.grid = grid
		yard.packer_pos = center
		packer_mesh = _slab("PackerCore", center + Vector3(0, 0.8, 0), Vector3(3.2, 1.6, 5.0), Color.html("#1F9E66"))
	else:
		yard.style = SMBuildYard.Style.SCAFFOLD

func order_building(id: StringName) -> String:
	if yard.style == SMBuildYard.Style.SCAFFOLD:
		return _order_scaffold(id)
	if yard.style == SMBuildYard.Style.INTERNAL:
		return _order_internal(id)
	return _order_mobile(id)

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

func _order_scaffold(id: StringName) -> String:
	var pos: Vector3 = yard.center + Vector3(float(yard.finished.size()) * 5.0, 0.0, 0.0)
	if not yard.inside(pos):
		pos = yard.center
	var hp: float = float(building_hp.get(id, 200.0))
	if not yard.begin_scaffold(id, pos, hp):
		_say("build blocked")
		return "build blocked"
	yard.advance(float(yard.building_time.get(id, 4.0)))
	if not yard.finished.has(id):
		_say("scaffold stalled")
		return "scaffold stalled"
	_slab("Built_%s" % str(id), pos + Vector3(0, 1.2, 0), Vector3(3.2, 2.4, 3.2), SMFront.primary())
	_say("%s built" % str(id))
	return "built"

func _order_internal(id: StringName) -> String:
	if not yard.queue_internal(id):
		var tier: int = int(yard.building_tier.get(id, 1))
		if tier > yard.clearance and buy_clearance() and yard.queue_internal(id):
			pass
		else:
			_say("hub not queued")
			return "hub not queued"
	yard.advance(float(yard.building_time.get(id, 4.0)) + 0.1)
	if not yard.ready.has(id):
		_say("hub not queued")
		return "hub not queued"
	var pos: Vector3 = yard.center + Vector3(4.0, 0.0, float(yard.placed.size()) * 4.0)
	if not yard.place_finished(id, pos):
		pos = yard.center
		if not yard.place_finished(id, pos):
			_say("hub not ready")
			return "hub not ready"
	if hub_mesh != null and yard.placed.size() == 1:
		hub_mesh.position = pos + Vector3(0, 1.2, 0)
		hub_mesh.visible = true
	else:
		_slab("Built_%s" % str(id), pos + Vector3(0, 1.2, 0), Vector3(3.2, 2.4, 3.2), SMFront.accent())
	_say("hub placed")
	return "placed"

func _order_mobile(id: StringName) -> String:
	if str(id) == "packer":
		return "packer sailed" if move_packer() else "packer stayed packed"
	if yard.unpacked and yard.factory_level(id) >= 1:
		var raised: bool = upgrade_factory_named(id)
		return "upgraded" if raised else "wharf not ready"
	if yard.unpacked:
		_say("packer already unpacked")
		return "packer already unpacked"
	move_packer()
	var ok: bool = yard.unpack(id)
	if ok:
		_slab("Built_%s" % str(id), yard.packer_pos + Vector3(0, 1.2, 0), Vector3(4.0, 2.2, 6.0), SMFront.accent())
	_say("wharf unpacked" if ok else "already unpacked")
	return "unpacked" if ok else "already unpacked"

func upgrade_factory_named(id: StringName) -> bool:
	if faction_id != "nmrf":
		return false
	var ok: bool = yard.upgrade_factory(id)
	_say("wharf level %d" % yard.factory_level(id) if ok else "wharf not ready")
	return ok

func _load_order(data: Dictionary) -> void:
	var raw: Variant = data.get("tech_order", [])
	if not (raw is Array):
		return
	for step: Variant in raw:
		yard.tech_order.append(StringName(str(step)))

func _load_buildings(data: Dictionary) -> void:
	var raw: Variant = data.get("buildings", [])
	if not (raw is Array):
		return
	for item: Variant in raw:
		if item is Dictionary:
			var id: StringName = StringName(str(item.get("id", "")))
			yard.building_tier[id] = int(item.get("tier", 1))
			yard.building_time[id] = float(item.get("time", 4.0))
			building_hp[id] = float(item.get("hp", 200.0))

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
