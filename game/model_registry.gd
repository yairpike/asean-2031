extends RefCounted
## Swaps a procedural mesh for res://game/models/<id>.glb or .gltf when that file exists.
## The procedural mesh stays when the file is missing. See game/models/README.md.

static func apply_unit(body: MeshInstance3D, id: String) -> bool:
	if body == null or id == "":
		return false
	var scene: Node3D = _scene(id)
	if scene == null:
		return false
	var footprint: AABB = _merged_aabb(body)
	_mount(body, scene, footprint)
	return true

static func apply_structure(host: MeshInstance3D, id: String) -> bool:
	if host == null or host.mesh == null or id == "":
		return false
	var scene: Node3D = _scene(id)
	if scene == null:
		return false
	var footprint: AABB = host.mesh.get_aabb()
	_mount(host, scene, footprint)
	return true

static func model_id_for(node_name: String) -> String:
	var name: String = node_name.to_lower()
	if name.begins_with("built_"):
		return name.trim_prefix("built_")
	return name

static func _scene(id: String) -> Node3D:
	var path: String = _path(id)
	if path == "":
		return null
	if ResourceLoader.exists(path):
		var packed: PackedScene = load(path) as PackedScene
		if packed != null:
			var instanced: Node = packed.instantiate()
			return instanced as Node3D
	return _from_gltf(path)

static func _path(id: String) -> String:
	if id == "" or id.contains("..") or id.contains("/"):
		return ""
	var glb: String = "res://game/models/%s.glb" % id
	if FileAccess.file_exists(glb):
		return glb
	var gltf: String = "res://game/models/%s.gltf" % id
	if FileAccess.file_exists(gltf):
		return gltf
	return ""

static func _from_gltf(path: String) -> Node3D:
	var doc: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		return null
	var generated: Node = doc.generate_scene(state)
	return generated as Node3D

static func _mount(body: MeshInstance3D, scene: Node3D, footprint: AABB) -> void:
	scene.name = "Model"
	body.add_child(scene)
	_fit(scene, footprint)
	_hoist(body, scene, "Turret")
	_hoist(body, scene, "Rotor")
	_hoist(body, scene, "Wake")
	var barrel: Node3D = scene.find_child("Barrel", true, false) as Node3D
	var turret: Node3D = body.get_node_or_null("Turret") as Node3D
	if barrel != null and turret != null and barrel.get_parent() != turret:
		var barrel_xf: Transform3D = barrel.global_transform
		barrel.reparent(turret)
		barrel.global_transform = barrel_xf
	body.mesh = null
	body.material_override = null
	body.set_meta("model", scene.name)

static func _hoist(body: MeshInstance3D, scene: Node3D, node_name: String) -> void:
	var found: Node3D = scene.find_child(node_name, true, false) as Node3D
	if found == null:
		return
	var previous: Node = body.get_node_or_null(node_name)
	if previous != null:
		previous.free()
	var kept: Transform3D = found.global_transform
	found.reparent(body)
	found.global_transform = kept

static func _fit(model: Node3D, footprint: AABB) -> void:
	var bounds: AABB = _merged_aabb(model)
	if bounds.size.x < 0.001 and bounds.size.z < 0.001:
		return
	var sx: float = footprint.size.x / maxf(bounds.size.x, 0.001)
	var sz: float = footprint.size.z / maxf(bounds.size.z, 0.001)
	var scale: float = minf(sx, sz)
	if scale <= 0.0 or is_inf(scale) or is_nan(scale):
		return
	model.scale = Vector3.ONE * scale
	var fitted: AABB = _merged_aabb(model)
	model.position += Vector3(
		footprint.get_center().x - fitted.get_center().x,
		footprint.position.y - fitted.position.y,
		footprint.get_center().z - fitted.get_center().z
	)

static func _merged_aabb(root: Node3D) -> AABB:
	var box: AABB = AABB()
	var started: bool = false
	var meshes: Array[MeshInstance3D] = []
	var own: MeshInstance3D = root as MeshInstance3D
	if own != null and own.mesh != null:
		meshes.append(own)
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_node: MeshInstance3D = node as MeshInstance3D
		if mesh_node != null and mesh_node.mesh != null:
			meshes.append(mesh_node)
	for mesh_node: MeshInstance3D in meshes:
		var local: AABB = mesh_node.mesh.get_aabb()
		var to_root: Transform3D = root.global_transform.affine_inverse() * mesh_node.global_transform
		var placed: AABB = to_root * local
		if not started:
			box = placed
			started = true
		else:
			box = box.merge(placed)
	return box
