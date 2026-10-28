extends RefCounted
## Swaps a procedural mesh for res://game/models/<id>.glb or .gltf when that file exists.
## The procedural mesh stays when the file is missing. See game/models/README.md.

static func apply_unit(body: MeshInstance3D, id: String, primary: Color = Color.WHITE, accent: Color = Color.WHITE) -> bool:
	if body == null or id == "":
		return false
	if _mount_unit(body, id, primary, accent):
		return true
	_queue(body, id, primary, accent, "unit")
	return false

static func apply_structure(host: MeshInstance3D, id: String, primary: Color = Color.WHITE, accent: Color = Color.WHITE) -> bool:
	if host == null or host.mesh == null or id == "":
		return false
	if _mount_structure(host, id, primary, accent):
		return true
	_queue(host, id, primary, accent, "structure")
	return false

static func _mount_unit(body: MeshInstance3D, id: String, primary: Color, accent: Color) -> bool:
	if str(body.get_meta("model", "")) != "":
		return true
	var scene: Node3D = _scene(id)
	if scene == null:
		return false
	var footprint: AABB = _merged_aabb(body)
	_mount(body, scene, footprint)
	_paint(body, primary, accent)
	return true

static func _mount_structure(host: MeshInstance3D, id: String, primary: Color, accent: Color) -> bool:
	if str(host.get_meta("model", "")) != "":
		return true
	if host.mesh == null:
		return false
	var scene: Node3D = _scene(id)
	if scene == null:
		return false
	var footprint: AABB = host.mesh.get_aabb()
	_mount(host, scene, footprint)
	_paint(host, primary, accent)
	return true

## Near-black primaries would multiply the grey palette down to plain metal.
static func body_ink(primary: Color) -> Color:
	var peak: float = maxf(primary.r, maxf(primary.g, primary.b))
	var ink: Color = primary
	if peak < 0.45:
		var gain: float = 0.45 / maxf(peak, 0.04)
		ink = Color(minf(primary.r * gain, 1.0), minf(primary.g * gain, 1.0), minf(primary.b * gain, 1.0), primary.a)
	var hi: float = maxf(ink.r, maxf(ink.g, ink.b))
	var lo: float = minf(ink.r, minf(ink.g, ink.b))
	if hi - lo < 0.05:
		ink = ink.lerp(Color(0.62, 0.46, 0.30), 0.4)
	return ink

## About 60% of the lifted faction colour, mixed into a dark ground so the palette stays shaded.
static func body_shade(primary: Color) -> Color:
	return body_ink(primary).lerp(Color(0.16, 0.15, 0.13), 0.4)

static func warm(owner: Node) -> void:
	if owner == null or not OS.has_feature("web"):
		return
	var listed: String = _index_text()
	if listed != "":
		_arm_index(owner, listed)
		return
	_pull_index(owner)

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
	if path.begins_with("user://") or path.begins_with("res://"):
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		if not bytes.is_empty():
			var parsed: Node3D = _from_buffer(bytes)
			if parsed != null:
				return parsed
	var file: String = path
	if path.begins_with("res://") or path.begins_with("user://"):
		file = ProjectSettings.globalize_path(path)
	return _from_gltf(file)

static func _from_buffer(bytes: PackedByteArray) -> Node3D:
	if bytes.is_empty():
		return null
	var doc: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	if doc.append_from_buffer(bytes, "", state) != OK:
		return null
	var generated: Node = doc.generate_scene(state)
	return generated as Node3D

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
static var _waiting: Array[MeshInstance3D] = []

static func _queue(body: MeshInstance3D, id: String, primary: Color, accent: Color, kind: String) -> void:
	if body == null or not OS.has_feature("web"):
		return
	body.set_meta("model_id", id)
	body.set_meta("model_primary", primary)
	body.set_meta("model_accent", accent)
	body.set_meta("model_kind", kind)
	if not _waiting.has(body):
		_waiting.append(body)

static func _redress(id: String) -> void:
	var still: Array[MeshInstance3D] = []
	for body: MeshInstance3D in _waiting:
		if not is_instance_valid(body):
			continue
		if str(body.get_meta("model_id", "")) != id:
			still.append(body)
			continue
		var primary: Color = body.get_meta("model_primary", Color.WHITE)
		var accent: Color = body.get_meta("model_accent", Color.WHITE)
		var ok: bool = false
		if str(body.get_meta("model_kind", "unit")) == "structure":
			ok = _mount_structure(body, id, primary, accent)
		else:
			ok = _mount_unit(body, id, primary, accent)
		if not ok:
			still.append(body)
	_waiting = still

static func _arm_index(owner: Node, text: String) -> void:
	if _index_read:
		return
	_index_read = true
	for line: String in text.split("\n"):
		var name: String = line.strip_edges()
		if name.ends_with(".glb") or name.ends_with(".gltf"):
			var id: String = name.get_basename()
			_index.append(id)
			_fetch(owner, id)

static func _pull_index(owner: Node) -> void:
	if owner == null or _index_read:
		return
	var http := HTTPRequest.new()
	http.timeout = 20.0
	http.accept_gzip = false
	owner.add_child(http)
	http.request_completed.connect(_got_index.bind(http, owner))
	var err: Error = http.request(_page() + "models/index.txt")
	if err != OK:
		http.queue_free()

static func _got_index(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, owner: Node) -> void:
	if is_instance_valid(http):
		http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or body.is_empty():
		return
	_arm_index(owner, body.get_string_from_utf8())

static func _page() -> String:
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
	return href

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
	if FileAccess.file_exists("user://models/%s.glb" % id) or FileAccess.file_exists("user://models/%s.gltf" % id):
		_redress(id)
		return
	_inflight[id] = true
	var http := HTTPRequest.new()
	http.timeout = 60.0
	http.accept_gzip = false
	owner.add_child(http)
	http.request_completed.connect(_got_model.bind(http, id))
	var err: Error = http.request("%smodels/%s.glb" % [_page(), id])
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
	_redress(id)

static func _from_gltf(path: String) -> Node3D:
	var doc: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		return null
	var generated: Node = doc.generate_scene(state)
	return generated as Node3D

static func _paint(root: Node3D, primary: Color, accent: Color) -> void:
	var ink: Color = body_shade(primary)
	_paint_node(root, ink, accent)

static func _paint_node(node: Node, primary: Color, accent: Color) -> void:
	if str(node.name) == "Wake" or str(node.name) == "ContactShadow":
		return
	var mesh_node: MeshInstance3D = node as MeshInstance3D
	if mesh_node != null and mesh_node.mesh != null:
		_paint_surfaces(mesh_node, primary, accent)
	for child: Node in node.get_children():
		_paint_node(child, primary, accent)

static func _paint_surfaces(mesh_node: MeshInstance3D, primary: Color, accent: Color) -> void:
	mesh_node.material_override = null
	for surface: int in mesh_node.mesh.get_surface_count():
		var src: Material = mesh_node.mesh.surface_get_material(surface)
		var name: String = ""
		if src != null:
			name = str(src.resource_name).to_lower()
		if name == "wake":
			continue
		var mat: StandardMaterial3D = _copy_mat(src)
		if name == "trim" or str(mesh_node.name).to_lower() == "trim":
			mat.albedo_color = accent
			mat.albedo_texture = null
			mat.roughness = 0.55
			mat.metallic = 0.0
			mat.resource_name = "Trim"
		else:
			mat.albedo_color = primary
			mat.roughness = 0.84
			mat.metallic = 0.0
			mat.resource_name = "Body"
			if src is BaseMaterial3D and mat.albedo_texture == null:
				mat.albedo_texture = (src as BaseMaterial3D).albedo_texture
		mesh_node.set_surface_override_material(surface, mat)

static func _copy_mat(src: Material) -> StandardMaterial3D:
	if src is StandardMaterial3D:
		return (src as StandardMaterial3D).duplicate() as StandardMaterial3D
	var mat := StandardMaterial3D.new()
	if src is BaseMaterial3D:
		mat.albedo_texture = (src as BaseMaterial3D).albedo_texture
	return mat

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
		var barrel_xf: Transform3D = _to_root(turret, barrel)
		var barrel_parent: Node = barrel.get_parent()
		if barrel_parent != null:
			barrel_parent.remove_child(barrel)
		barrel.owner = null
		turret.add_child(barrel)
		barrel.transform = barrel_xf
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
	var kept: Transform3D = _to_root(body, found)
	var parent: Node = found.get_parent()
	if parent != null:
		parent.remove_child(found)
	found.owner = null
	body.add_child(found)
	found.transform = kept

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
		if _under_wake(mesh_node, root):
			continue
		var local: AABB = mesh_node.mesh.get_aabb()
		var placed: AABB = _to_root(root, mesh_node) * local
		if not started:
			box = placed
			started = true
		else:
			box = box.merge(placed)
	return box

static func _to_root(root: Node3D, mesh_node: Node3D) -> Transform3D:
	var xf: Transform3D = Transform3D.IDENTITY
	var node: Node3D = mesh_node
	while node != null and node != root:
		xf = node.transform * xf
		var parent: Node = node.get_parent()
		node = parent as Node3D
	return xf

static func _under_wake(mesh_node: Node, root: Node) -> bool:
	var node: Node = mesh_node
	while node != null and node != root:
		if str(node.name) == "Wake":
			return true
		node = node.get_parent()
	return str(root.name) == "Wake"
