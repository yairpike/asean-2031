extends RefCounted
## Low-poly silhouettes made from boxes and cylinders. No imported assets.
## One shared vertex-color material. Turrets, rotors, and wakes are the only extra draws.

const METAL: Color = Color(0.22, 0.23, 0.26)
const RUBBER: Color = Color(0.12, 0.12, 0.13)
const GLASS: Color = Color(0.55, 0.75, 0.85)

static var _ink: StandardMaterial3D
static var _foam: StandardMaterial3D
static var _cache: Dictionary = {}

static func dress_unit(kind: String, role: String, loco: String, accent: Color) -> MeshInstance3D:
	var form: String = unit_form(kind, role, loco)
	var body: MeshInstance3D = MeshInstance3D.new()
	body.name = "Body"
	body.mesh = unit_mesh(form, accent)
	body.set_meta("form", form)
	body.set_meta("paint", accent)
	if form == "tank":
		_part(body, "Turret", "tank_top", accent, Vector3(0.0, 0.98, -0.1))
	elif form == "tube":
		_part(body, "Turret", "tube_top", accent, Vector3(0.0, 0.82, 0.35))
	elif form == "heli":
		_part(body, "Rotor", "rotor", accent, Vector3(0.0, 1.28, -0.1))
	elif form == "boat":
		var wake: MeshInstance3D = _part(body, "Wake", "wake", accent, Vector3(0.0, 0.05, 1.85))
		wake.visible = false
		wake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return body

static func dress_structure(mi: MeshInstance3D, size: Vector3, accent: Color) -> bool:
	var form: String = structure_form(str(mi.name))
	if form == "":
		return false
	mi.mesh = structure_mesh(form, accent, size.y)
	mi.material_override = null
	mi.set_meta("form", form)
	mi.set_meta("paint", accent)
	return true

static func animate(u: RTSUnit, delta: float) -> void:
	var body: MeshInstance3D = u.get_node_or_null("Body") as MeshInstance3D
	if body == null:
		return
	var turret: MeshInstance3D = body.get_node_or_null("Turret") as MeshInstance3D
	if turret != null:
		var yaw: float = 0.0
		var target: RTSUnit = u.attack_target
		if target != null and is_instance_valid(target) and target.is_alive():
			var dir: Vector3 = target.global_position - u.global_position
			yaw = wrapf(atan2(-dir.x, -dir.z) - u.rotation.y, -PI, PI)
		turret.rotation.y = yaw
	var rotor: MeshInstance3D = body.get_node_or_null("Rotor") as MeshInstance3D
	if rotor != null:
		rotor.rotate_y(delta * 14.0)
	var wake: MeshInstance3D = body.get_node_or_null("Wake") as MeshInstance3D
	if wake != null:
		wake.visible = u.is_moving()

static func paint_status(body: MeshInstance3D, mat: Material) -> void:
	if body == null:
		return
	body.material_override = mat
	var turret: MeshInstance3D = body.get_node_or_null("Turret") as MeshInstance3D
	if turret != null:
		turret.material_override = mat
	var rotor: MeshInstance3D = body.get_node_or_null("Rotor") as MeshInstance3D
	if rotor != null:
		rotor.material_override = mat

static func unit_form(kind: String, role: String, loco: String) -> String:
	var id: String = kind.to_lower()
	if role == "infantry":
		return "figure"
	if role == "air" or role == "drone" or loco == "air":
		if id.contains("su30") or id.contains("jet") or id.contains("bomber") or id.contains("siege_tube") or id.contains("scaffold_rig") or id.contains("bullion"):
			return "jet"
		return "heli"
	if role == "core" or id == "packer":
		return "truck"
	if role == "armor":
		return "tank"
	if role == "artillery":
		return "tube"
	if role == "boat" or loco == "naval" or role == "amphibious":
		return "boat"
	return "truck"

static func structure_form(node_name: String) -> String:
	var n: String = node_name.to_lower()
	if n.begins_with("super_"):
		return "super"
	if n == "hubshell" or n == "packercore" or n == "playeryard" or n == "enemyyard" or n == "enemybase":
		return "yard"
	if n.begins_with("built_"):
		return _building_form(n.trim_prefix("built_"))
	return ""

static func muzzle_pos(form: String) -> Vector3:
	if form == "figure":
		return Vector3(0.32, 1.22, -0.9)
	if form == "tank" or form == "tube":
		return Vector3(0.0, 1.25, -1.85)
	if form == "boat":
		return Vector3(0.0, 0.9, -1.6)
	if form == "heli":
		return Vector3(0.0, 0.9, -1.25)
	if form == "jet":
		return Vector3(0.0, 0.72, -2.0)
	return Vector3(0.0, 0.95, -1.6)

static func unit_mesh(form: String, accent: Color) -> ArrayMesh:
	var key: String = "%s|%s|0" % [form, accent.to_html(false)]
	if _cache.has(key):
		return _cache[key] as ArrayMesh
	var st: SurfaceTool = _begin(_opaque())
	if form == "figure":
		_figure(st, accent)
	elif form == "truck":
		_truck(st, accent)
	elif form == "tank":
		_tank_hull(st, accent)
	elif form == "tank_top":
		_tank_top(st, accent)
	elif form == "tube":
		_tube_hull(st, accent)
	elif form == "tube_top":
		_tube_top(st, accent)
	elif form == "boat":
		_boat(st, accent)
	elif form == "wake":
		st = _begin(_foam_ink())
		_wake(st)
	elif form == "heli":
		_heli(st, accent)
	elif form == "rotor":
		_rotor(st)
	else:
		_jet(st, accent)
	var mesh: ArrayMesh = _commit(st)
	_cache[key] = mesh
	return mesh

static func structure_mesh(form: String, accent: Color, height: float) -> ArrayMesh:
	var key: String = "%s|%s|%.2f" % [form, accent.to_html(false), height]
	if _cache.has(key):
		return _cache[key] as ArrayMesh
	var st: SurfaceTool = _begin(_opaque())
	var ground: float = -height * 0.5
	if form == "power":
		_power(st, ground, accent)
	elif form == "refinery":
		_refinery(st, ground, accent)
	elif form == "barracks":
		_barracks(st, ground, accent)
	elif form == "factory":
		_factory(st, ground, accent)
	elif form == "naval":
		_naval(st, ground, accent)
	elif form == "airfield":
		_airfield(st, ground, accent)
	elif form == "defense":
		_bunker(st, ground, accent)
	elif form == "mast":
		_mast(st, ground, accent)
	elif form == "tech":
		_radar(st, ground, accent)
	elif form == "super":
		_needle(st, ground, accent, height)
	else:
		_yard(st, ground, accent, height)
	var mesh: ArrayMesh = _commit(st)
	_cache[key] = mesh
	return mesh

static func _building_form(id: String) -> String:
	if id.contains("mast") or id.contains("flak") or id.contains("prism") or id.contains("multigunner"):
		return "mast"
	var role: String = _catalog_role(id)
	if role == "power":
		return "power"
	if role == "refinery":
		return "refinery"
	if role == "barracks":
		return "barracks"
	if role == "factory":
		return "factory"
	if role == "naval":
		return "naval"
	if role == "air":
		return "airfield"
	if role == "defense":
		return "defense"
	if role == "tech":
		return "tech"
	return "yard"

static func _catalog_role(id: String) -> String:
	var factions: PackedStringArray = PackedStringArray(["gtfc", "mvd", "nmrf"])
	for faction: String in factions:
		var data: Dictionary = SMCatalog.faction(faction)
		var raw: Variant = data.get("buildings", [])
		if raw is Array:
			for item: Variant in raw:
				if item is Dictionary and str((item as Dictionary).get("id", "")) == id:
					return str((item as Dictionary).get("role", ""))
	return ""

static func _part(body: MeshInstance3D, node_name: String, form: String, accent: Color, at: Vector3) -> MeshInstance3D:
	var part: MeshInstance3D = MeshInstance3D.new()
	part.name = node_name
	part.mesh = unit_mesh(form, accent)
	part.position = at
	body.add_child(part)
	return part

static func _opaque() -> StandardMaterial3D:
	if _ink == null:
		_ink = StandardMaterial3D.new()
		_ink.vertex_color_use_as_albedo = true
		_ink.roughness = 0.78
		_ink.metallic = 0.06
		_ink.cull_mode = BaseMaterial3D.CULL_BACK
	return _ink

static func _foam_ink() -> StandardMaterial3D:
	if _foam == null:
		_foam = StandardMaterial3D.new()
		_foam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_foam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_foam.albedo_color = Color(0.78, 0.9, 0.96, 0.45)
		_foam.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _foam

static func _begin(mat: Material) -> SurfaceTool:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat)
	return st

static func _commit(st: SurfaceTool) -> ArrayMesh:
	st.generate_normals()
	return st.commit()

static func _box(st: SurfaceTool, c: Vector3, s: Vector3, color: Color) -> void:
	var hx: float = s.x * 0.5
	var hy: float = s.y * 0.5
	var hz: float = s.z * 0.5
	var x0: float = c.x - hx
	var x1: float = c.x + hx
	var y0: float = c.y - hy
	var y1: float = c.y + hy
	var z0: float = c.z - hz
	var z1: float = c.z + hz
	_quad(st, Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1), color)
	_quad(st, Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0), color)
	_quad(st, Vector3(x0, y1, z0), Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), color)
	_quad(st, Vector3(x0, y0, z1), Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), color)
	_quad(st, Vector3(x1, y0, z1), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), color)
	_quad(st, Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0), color)

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	st.set_color(color)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(d)

static func _wheel(st: SurfaceTool, c: Vector3, radius: float, length: float) -> void:
	var sides: int = 6
	var hx: float = length * 0.5
	for i: int in sides:
		var a0: float = TAU * float(i) / float(sides)
		var a1: float = TAU * float(i + 1) / float(sides)
		var y0: float = cos(a0) * radius
		var z0: float = sin(a0) * radius
		var y1: float = cos(a1) * radius
		var z1: float = sin(a1) * radius
		var p0: Vector3 = c + Vector3(-hx, y0, z0)
		var p1: Vector3 = c + Vector3(hx, y0, z0)
		var q1: Vector3 = c + Vector3(hx, y1, z1)
		var q0: Vector3 = c + Vector3(-hx, y1, z1)
		_quad(st, p0, q0, q1, p1, RUBBER)
		_tri(st, c + Vector3(hx, 0.0, 0.0), p1, q1, RUBBER)
		_tri(st, c + Vector3(-hx, 0.0, 0.0), q0, p0, RUBBER)

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	st.set_color(color)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)

static func _figure(st: SurfaceTool, accent: Color) -> void:
	_box(st, Vector3(-0.16, 0.42, 0.0), Vector3(0.22, 0.84, 0.24), METAL)
	_box(st, Vector3(0.16, 0.42, 0.0), Vector3(0.22, 0.84, 0.24), METAL)
	_box(st, Vector3(0.0, 1.18, 0.0), Vector3(0.62, 0.72, 0.34), accent)
	_box(st, Vector3(0.0, 1.74, -0.02), Vector3(0.3, 0.3, 0.3), Color(0.55, 0.42, 0.34))
	_box(st, Vector3(-0.42, 1.2, -0.05), Vector3(0.16, 0.52, 0.16), METAL)
	_box(st, Vector3(0.4, 1.16, -0.2), Vector3(0.16, 0.16, 0.55), METAL)
	_box(st, Vector3(0.4, 1.16, -0.62), Vector3(0.08, 0.08, 0.55), RUBBER)

static func _truck(st: SurfaceTool, accent: Color) -> void:
	_box(st, Vector3(0.0, 0.46, 0.15), Vector3(1.55, 0.36, 3.3), METAL)
	_box(st, Vector3(0.0, 1.05, -0.95), Vector3(1.45, 0.85, 1.15), accent)
	_box(st, Vector3(0.0, 1.22, -1.48), Vector3(1.15, 0.38, 0.08), GLASS)
	_box(st, Vector3(0.0, 0.88, 0.85), Vector3(1.5, 0.5, 1.65), METAL)
	_wheel(st, Vector3(-0.78, 0.32, -1.05), 0.32, 0.22)
	_wheel(st, Vector3(0.78, 0.32, -1.05), 0.32, 0.22)
	_wheel(st, Vector3(-0.78, 0.32, 1.15), 0.32, 0.22)
	_wheel(st, Vector3(0.78, 0.32, 1.15), 0.32, 0.22)

static func _tank_hull(st: SurfaceTool, accent: Color) -> void:
	_box(st, Vector3(0.0, 0.4, 0.05), Vector3(1.55, 0.42, 2.7), METAL)
	_box(st, Vector3(0.0, 0.72, 0.05), Vector3(1.25, 0.28, 1.9), accent)
	_box(st, Vector3(-0.95, 0.36, 0.05), Vector3(0.32, 0.5, 3.05), RUBBER)
	_box(st, Vector3(0.95, 0.36, 0.05), Vector3(0.32, 0.5, 3.05), RUBBER)

static func _tank_top(st: SurfaceTool, accent: Color) -> void:
	_box(st, Vector3(0.0, 0.22, 0.05), Vector3(0.95, 0.42, 1.15), accent)
	_box(st, Vector3(0.0, 0.24, -1.05), Vector3(0.16, 0.16, 1.55), METAL)

static func _tube_hull(st: SurfaceTool, accent: Color) -> void:
	_box(st, Vector3(0.0, 0.42, 0.2), Vector3(1.4, 0.36, 2.9), METAL)
	_box(st, Vector3(0.0, 0.88, -0.95), Vector3(1.25, 0.62, 0.85), accent)
	_box(st, Vector3(0.0, 1.02, -1.32), Vector3(0.9, 0.28, 0.08), GLASS)
	_wheel(st, Vector3(-0.72, 0.3, -0.85), 0.3, 0.2)
	_wheel(st, Vector3(0.72, 0.3, -0.85), 0.3, 0.2)
	_wheel(st, Vector3(-0.72, 0.3, 1.15), 0.3, 0.2)
	_wheel(st, Vector3(0.72, 0.3, 1.15), 0.3, 0.2)

static func _tube_top(st: SurfaceTool, accent: Color) -> void:
	_box(st, Vector3(0.0, 0.16, 0.0), Vector3(0.4, 0.28, 0.55), accent)
	_box(st, Vector3(0.0, 0.34, -1.35), Vector3(0.18, 0.18, 2.5), METAL)

static func _boat(st: SurfaceTool, accent: Color) -> void:
	_box(st, Vector3(0.0, 0.28, 0.1), Vector3(1.2, 0.32, 3.5), accent)
	_box(st, Vector3(0.0, 0.5, 0.25), Vector3(0.95, 0.18, 2.5), METAL)
	_box(st, Vector3(0.0, 0.32, -1.7), Vector3(0.62, 0.22, 0.7), accent)
	_box(st, Vector3(0.0, 0.86, -0.25), Vector3(0.72, 0.48, 0.9), METAL)
	_box(st, Vector3(0.0, 1.0, -0.68), Vector3(0.6, 0.22, 0.08), GLASS)

static func _wake(st: SurfaceTool) -> void:
	_box(st, Vector3(0.0, 0.0, 0.35), Vector3(0.35, 0.04, 0.9), Color.WHITE)
	_box(st, Vector3(0.0, 0.0, 1.15), Vector3(0.9, 0.04, 0.7), Color.WHITE)

static func _heli(st: SurfaceTool, accent: Color) -> void:
	_box(st, Vector3(0.0, 0.82, 0.05), Vector3(0.72, 0.48, 1.7), accent)
	_box(st, Vector3(0.0, 0.9, -0.85), Vector3(0.58, 0.38, 0.7), GLASS)
	_box(st, Vector3(0.0, 0.88, 1.35), Vector3(0.18, 0.16, 1.35), METAL)
	_box(st, Vector3(0.0, 1.15, 1.9), Vector3(0.08, 0.42, 0.32), accent)
	_box(st, Vector3(-0.28, 0.38, 0.1), Vector3(0.08, 0.1, 1.3), RUBBER)
	_box(st, Vector3(0.28, 0.38, 0.1), Vector3(0.08, 0.1, 1.3), RUBBER)

static func _rotor(st: SurfaceTool) -> void:
	_box(st, Vector3(0.0, 0.06, 0.0), Vector3(2.7, 0.05, 0.16), METAL)
	_box(st, Vector3(0.0, 0.06, 0.0), Vector3(0.16, 0.05, 2.7), METAL)
	_box(st, Vector3(0.0, 0.02, 0.0), Vector3(0.22, 0.1, 0.22), RUBBER)

static func _jet(st: SurfaceTool, accent: Color) -> void:
	_box(st, Vector3(0.0, 0.72, 0.05), Vector3(0.42, 0.32, 3.1), accent)
	_box(st, Vector3(0.0, 0.72, -1.7), Vector3(0.26, 0.2, 0.55), METAL)
	_box(st, Vector3(0.0, 0.78, -1.15), Vector3(0.28, 0.16, 0.35), GLASS)
	_box(st, Vector3(0.0, 0.7, 0.05), Vector3(2.9, 0.07, 0.85), METAL)
	_box(st, Vector3(0.0, 0.95, 1.35), Vector3(1.15, 0.06, 0.32), METAL)
	_box(st, Vector3(0.0, 1.05, 1.3), Vector3(0.08, 0.48, 0.38), accent)

static func _yard(st: SurfaceTool, ground: float, accent: Color, height: float) -> void:
	var h: float = height * 0.9
	var posts: Array[Vector3] = [Vector3(-0.62, 0.0, -0.62), Vector3(0.62, 0.0, -0.62), Vector3(-0.62, 0.0, 0.62), Vector3(0.62, 0.0, 0.62)]
	for p: Vector3 in posts:
		_box(st, Vector3(p.x, ground + h * 0.5, p.z), Vector3(0.16, h, 0.16), METAL)
	_box(st, Vector3(0.0, ground + 0.85, 0.0), Vector3(1.35, 0.12, 1.35), accent)
	_box(st, Vector3(0.4, ground + h * 0.62, 0.0), Vector3(0.14, h * 0.7, 0.14), accent)
	_box(st, Vector3(0.0, ground + h * 0.96, 0.0), Vector3(1.2, 0.08, 0.12), METAL)

static func _power(st: SurfaceTool, ground: float, accent: Color) -> void:
	_box(st, Vector3(-0.25, ground + 0.7, 0.0), Vector3(2.2, 1.3, 1.7), METAL)
	_box(st, Vector3(0.85, ground + 2.15, 0.15), Vector3(0.55, 3.5, 0.55), accent)
	_box(st, Vector3(0.85, ground + 3.95, 0.15), Vector3(0.7, 0.12, 0.7), RUBBER)

static func _refinery(st: SurfaceTool, ground: float, accent: Color) -> void:
	_box(st, Vector3(0.0, ground + 0.55, -0.48), Vector3(3.3, 0.7, 0.7), METAL)
	_box(st, Vector3(0.0, ground + 0.55, 0.48), Vector3(3.3, 0.7, 0.7), accent)
	_box(st, Vector3(0.0, ground + 1.15, 0.0), Vector3(0.22, 0.55, 1.3), METAL)
	_box(st, Vector3(1.35, ground + 1.05, 0.0), Vector3(0.35, 0.7, 0.35), accent)

static func _barracks(st: SurfaceTool, ground: float, accent: Color) -> void:
	_box(st, Vector3(0.0, ground + 0.55, 0.0), Vector3(3.6, 1.0, 1.45), METAL)
	_box(st, Vector3(0.0, ground + 1.15, 0.0), Vector3(3.8, 0.18, 1.65), accent)
	_box(st, Vector3(0.0, ground + 0.4, -0.74), Vector3(0.45, 0.7, 0.08), accent)

static func _factory(st: SurfaceTool, ground: float, accent: Color) -> void:
	_box(st, Vector3(0.0, ground + 0.55, 0.0), Vector3(3.0, 1.0, 2.1), METAL)
	_box(st, Vector3(-0.85, ground + 1.25, 0.0), Vector3(0.7, 0.45, 2.0), accent)
	_box(st, Vector3(0.05, ground + 1.5, 0.0), Vector3(0.7, 0.7, 2.0), METAL)
	_box(st, Vector3(0.95, ground + 1.25, 0.0), Vector3(0.7, 0.45, 2.0), accent)

static func _naval(st: SurfaceTool, ground: float, accent: Color) -> void:
	_box(st, Vector3(0.0, ground + 0.22, 0.0), Vector3(1.15, 0.28, 4.4), METAL)
	_box(st, Vector3(-0.75, ground + 0.45, -0.3), Vector3(0.14, 0.5, 2.4), accent)
	_box(st, Vector3(0.75, ground + 0.45, -0.3), Vector3(0.14, 0.5, 2.4), accent)
	_box(st, Vector3(0.0, ground + 0.7, 1.45), Vector3(1.35, 0.7, 0.9), accent)

static func _airfield(st: SurfaceTool, ground: float, accent: Color) -> void:
	_box(st, Vector3(0.0, ground + 0.08, 0.0), Vector3(5.4, 0.12, 1.15), RUBBER)
	_box(st, Vector3(0.0, ground + 0.1, 0.0), Vector3(0.12, 0.04, 1.05), Color(0.85, 0.82, 0.7))
	_box(st, Vector3(1.7, ground + 1.05, 0.85), Vector3(0.4, 1.9, 0.4), METAL)
	_box(st, Vector3(1.7, ground + 2.1, 0.85), Vector3(0.75, 0.32, 0.75), GLASS)
	_box(st, Vector3(1.7, ground + 2.28, 0.85), Vector3(0.9, 0.08, 0.9), accent)

static func _bunker(st: SurfaceTool, ground: float, accent: Color) -> void:
	_box(st, Vector3(0.0, ground + 0.4, 0.15), Vector3(2.2, 0.75, 1.55), METAL)
	_box(st, Vector3(0.0, ground + 0.95, -0.25), Vector3(0.5, 0.38, 0.55), accent)
	_box(st, Vector3(0.0, ground + 1.0, -0.95), Vector3(0.12, 0.12, 0.95), RUBBER)

static func _mast(st: SurfaceTool, ground: float, accent: Color) -> void:
	_box(st, Vector3(0.0, ground + 2.15, 0.0), Vector3(0.2, 4.2, 0.2), METAL)
	_box(st, Vector3(0.0, ground + 3.7, 0.0), Vector3(1.15, 0.1, 1.15), accent)
	_box(st, Vector3(-0.35, ground + 3.85, 0.0), Vector3(0.35, 0.12, 0.12), RUBBER)
	_box(st, Vector3(0.35, ground + 3.85, 0.0), Vector3(0.12, 0.12, 0.35), RUBBER)

static func _radar(st: SurfaceTool, ground: float, accent: Color) -> void:
	_box(st, Vector3(0.0, ground + 0.35, 0.0), Vector3(1.6, 0.6, 1.6), METAL)
	_box(st, Vector3(0.0, ground + 1.35, 0.0), Vector3(0.16, 1.5, 0.16), METAL)
	_box(st, Vector3(0.0, ground + 2.15, 0.15), Vector3(1.7, 0.1, 1.7), accent)
	_box(st, Vector3(0.0, ground + 2.0, -0.55), Vector3(0.12, 0.35, 0.12), RUBBER)

static func _needle(st: SurfaceTool, ground: float, accent: Color, height: float) -> void:
	_box(st, Vector3(0.0, ground + 0.28, 0.0), Vector3(1.35, 0.4, 1.35), METAL)
	_box(st, Vector3(0.0, ground + height * 0.46, 0.0), Vector3(0.32, height * 0.78, 0.32), accent)
	_box(st, Vector3(0.0, ground + height * 0.9, 0.0), Vector3(0.14, height * 0.12, 0.14), Color(0.95, 0.55, 0.2))
