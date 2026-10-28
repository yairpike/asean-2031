extends RefCounted
## Swaps a procedural mesh for res://game/models/<id>.glb or .gltf when that file exists.
## The procedural mesh stays when the file is missing. See game/models/README.md.

static func apply_unit(body: MeshInstance3D, id: String, accent: Color = Color.WHITE) -> bool:
	if body == null or id == "":
		return false
	var scene: Node3D = _scene(id)
	if scene == null:
		return false
	var footprint: AABB = _merged_aabb(body)
	_mount(body, scene, footprint)
	_paint(body, accent)
	return true

static func apply_structure(host: MeshInstance3D, id: String, accent: Color = Color.WHITE) -> bool:
	if host == null or host.mesh == null or id == "":
		return false
	var scene: Node3D = _scene(id)
	if scene == null:
		return false
	var footprint: AABB = host.mesh.get_aabb()
	_mount(host, scene, footprint)
	_paint(host, accent)
	return true

static func warm(owner: Node) -> void:
	if owner == null or not OS.has_feature("web"):
		return
	_read_index()
	for id: String in _index:
		_fetch(owner, id)

static func model_id_for(node_name: String) -> String:
	var name: String = node_name.to_lower()
	if name.begins_with("built_"):
		return name.trim_prefix("built_")
	return name

static func _scene(id: String) -> Node3D:
	var path: String = _path(id)
	if path == "":
		return null
	if path.begins_with("res://") and ResourceLoader.exists(path):
		var packed: PackedScene = load(path) as PackedScene
		if packed != null:
			var instanced: Node = packed.instantiate()
			return instanced as Node3D
	var file: String = path
	if path.begins_with("res://") or path.begins_with("user://"):
		file = ProjectSettings.globalize_path(path)
	return _from_gltf(file)

static func _path(id: String) -> String:
	if id == "" or id.contains("..") or id.contains("/") or id.contains("\\"):
		return ""
	for ext: String in ["glb", "gltf"]:
		var packed: String = "res://game/models/%s.%s" % [id, ext]
		if ResourceLoader.exists(packed) or FileAccess.file_exists(packed):
			return packed
		var user_path: String = "user://models/%s.%s" % [id, ext]
		if FileAccess.file_exists(user_path):
			return user_path
		var name: String = "%s.%s" % [id, ext]
		var roots: PackedStringArray = PackedStringArray()
		roots.append(ProjectSettings.globalize_path("res://").path_join("game/models"))
		roots.append(ProjectSettings.globalize_path("res://").path_join("build/web/models"))
		roots.append(OS.get_executable_path().get_base_dir().path_join("models"))
		for root: String in roots:
			var found: String = root.path_join(name)
			if FileAccess.file_exists(found):
				return found
	return ""

static var _index: PackedStringArray = PackedStringArray()
static var _index_read: bool = false
static var _inflight: Dictionary = {}

static func _read_index() -> void:
	if _index_read:
		return
	_index_read = true
	var text: String = _index_text()
	for line: String in text.split("\n"):
		var name: String = line.strip_edges()
		if name.ends_with(".glb") or name.ends_with(".gltf"):
			_index.append(name.get_basename())

static func _index_text() -> String:
	var packed: String = "res://game/models/index.txt"
	if FileAccess.file_exists(packed):
		return FileAccess.get_file_as_string(packed)
	var roots: PackedStringArray = PackedStringArray()
	roots.append(ProjectSettings.globalize_path("res://").path_join("build/web/models/index.txt"))
	roots.append(OS.get_executable_path().get_base_dir().path_join("models/index.txt"))
	for path: String in roots:
		if FileAccess.file_exists(path):
			return FileAccess.get_file_as_string(path)
	return ""

static func _fetch(owner: Node, id: String) -> void:
	if owner == null or _inflight.has(id) or id.contains(".."):
		return
	_inflight[id] = true
	var http := HTTPRequest.new()
	http.timeout = 60.0
	http.accept_gzip = false
	owner.add_child(http)
	http.request_completed.connect(_got_model.bind(http, id))
	var href: String = str(JavaScriptBridge.eval("window.location.href", true))
	var cut: int = href.find("?")
	if cut >= 0:
		href = href.substr(0, cut)
	cut = href.find("#")
	if cut >= 0:
		href = href.substr(0, cut)
	var slash: int = href.rfind("/")
	if slash >= 0:
		href = href.substr(0, slash + 1)
	var err: Error = http.request("%smodels/%s.glb" % [href, id])
	if err != OK:
		_inflight.erase(id)
		http.queue_free()

static func _got_model(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, id: String) -> void:
	if is_instance_valid(http):
		http.queue_free()
	_inflight.erase(id)
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or body.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://models"))
	var file := FileAccess.open("user://models/%s.glb" % id, FileAccess.WRITE)
	if file == null:
		return
	file.store_buffer(body)
	file.close()

static func _from_gltf(path: String) -> Node3D:
	var doc: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		return null
	var generated: Node = doc.generate_scene(state)
	return generated as Node3D

static func _paint(body: Node3D, accent: Color) -> void:
	var meshes: Array[MeshInstance3D] = []
	_collect(body, meshes)
	var trimmed: bool = false
	for mesh_node: MeshInstance3D in meshes:
		if _is_trim(mesh_node):
			_tint_mesh(mesh_node, accent)
			trimmed = true
	if trimmed or accent.is_equal_approx(Color.WHITE):
		return
	for mesh_node: MeshInstance3D in meshes:
		_tint_mesh(mesh_node, accent)

static func _collect(node: Node, meshes: Array[MeshInstance3D]) -> void:
	var mesh_node: MeshInstance3D = node as MeshInstance3D
	if mesh_node != null and mesh_node.mesh != null and mesh_node.name != "ContactShadow" and mesh_node.name != "Wake":
		meshes.append(mesh_node)
	for child: Node in node.get_children():
		_collect(child, meshes)

static func _is_trim(mesh_node: MeshInstance3D) -> bool:
	if str(mesh_node.name).to_lower() == "trim":
		return true
	var parent: Node = mesh_node.get_parent()
	if parent != null and str(parent.name).to_lower() == "trim":
		return true
	var active: Material = mesh_node.get_active_material(0)
	if active != null and str(active.resource_name).to_lower() == "trim":
		return true
	if mesh_node.mesh == null:
		return false
	for surface: int in mesh_node.mesh.get_surface_count():
		var surf: Material = mesh_node.mesh.surface_get_material(surface)
		if surf != null and str(surf.resource_name).to_lower() == "trim":
			return true
	return false

static func _tint_mesh(mesh_node: MeshInstance3D, accent: Color) -> void:
	var src: Material = mesh_node.get_active_material(0)
	var mat := StandardMaterial3D.new()
	if src is StandardMaterial3D:
		mat = (src as StandardMaterial3D).duplicate() as StandardMaterial3D
	elif src is BaseMaterial3D:
		mat.albedo_texture = (src as BaseMaterial3D).albedo_texture
	mat.albedo_color = accent
	mat.resource_name = "Trim"
	mesh_node.material_override = mat

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
