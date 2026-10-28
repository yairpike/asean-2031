extends RefCounted
## Primitive effects: ice, an aegis dome, a slag pool, four beams, a jammer dome, and a ruby cone.

static func dress(host: Node3D) -> void:
	if host == null:
		return
	_beam(host, "BeamPainter", Vector3(-6.0, 1.4, -8.0), Color(1.0, 0.35, 0.2))
	_beam(host, "BeamLeech", Vector3(-3.4, 1.4, -8.0), Color(0.45, 0.9, 0.35))
	_beam(host, "BeamFiber", Vector3(-0.8, 1.4, -8.0), Color(0.92, 0.92, 0.96))
	_beam(host, "BeamPrism", Vector3(1.8, 1.4, -8.0), Color(0.35, 0.75, 1.0))
	var bubble: SphereMesh = SphereMesh.new()
	bubble.radius = 1.5
	bubble.height = 3.0
	_place(host, "AegisDome", Vector3(5.0, 1.6, -8.0), bubble, shader_material("res://game/shaders/aegis_dome_shield.gdshader"))
	var jammer_at: Vector3 = Vector3(8.0, 1.4, -6.0)
	var jammer: Node3D = host.get_node_or_null("Jammer") as Node3D
	if jammer != null:
		jammer_at = jammer.position
	var dome: SphereMesh = SphereMesh.new()
	dome.radius = 1.8
	dome.height = 3.6
	_place(host, "JammerDome", jammer_at, dome, _tint(Color(0.2, 0.85, 0.9, 0.28)))
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 0.05
	cone.bottom_radius = 0.7
	cone.height = 2.6
	_place(host, "RubyCone", Vector3(8.0, 1.3, -4.0), cone, _tint(Color(0.72, 0.1, 0.16, 0.72)))
	var pool: CylinderMesh = CylinderMesh.new()
	pool.top_radius = 1.7
	pool.bottom_radius = 1.7
	pool.height = 0.12
	_place(host, "SlagPool", Vector3(-8.0, 0.12, -4.0), pool, shader_material("res://game/shaders/slag_corrosion_pool.gdshader"))

static func ice_material() -> ShaderMaterial:
	return shader_material("res://game/shaders/cryo_freeze_overlay.gdshader")

static func shader_material(path: String) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	var shader: Shader = load(path) as Shader
	mat.shader = shader
	return mat

static func _beam(host: Node3D, node_name: String, at: Vector3, color: Color) -> void:
	var mat: ShaderMaterial = shader_material("res://game/shaders/laser_ribbon.gdshader")
	mat.set_shader_parameter("beam_color", color)
	_place(host, node_name, at, _ribbon(), mat)

static func _place(host: Node3D, node_name: String, at: Vector3, mesh: Mesh, mat: Material) -> void:
	if host.get_node_or_null(node_name) != null:
		return
	var body: MeshInstance3D = MeshInstance3D.new()
	body.name = node_name
	body.mesh = mesh
	body.position = at
	body.material_override = mat
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.visible = false
	host.add_child(body)

static func drive(host: Node3D, field: SMPointer, goods: SMCommodityNet, ew: SMEwField) -> void:
	if host == null:
		return
	var painter: bool = false
	var leech: bool = false
	var fiber: bool = false
	var prism: bool = false
	var aegis: bool = false
	var slag: bool = false
	var painter_at: Vector3 = Vector3(-6.0, 1.4, -8.0)
	var leech_at: Vector3 = Vector3(-3.4, 1.4, -8.0)
	var fiber_at: Vector3 = Vector3(-0.8, 1.4, -8.0)
	var prism_at: Vector3 = Vector3(1.8, 1.4, -8.0)
	var painter_aim: Vector3 = painter_at + Vector3(0.0, 0.0, -6.0)
	var leech_aim: Vector3 = leech_at + Vector3(0.0, 0.0, -6.0)
	var fiber_aim: Vector3 = fiber_at + Vector3(0.0, 0.0, -6.0)
	var prism_aim: Vector3 = prism_at + Vector3(0.0, 0.0, -6.0)
	var aegis_at: Vector3 = Vector3(5.0, 1.6, -8.0)
	var slag_at: Vector3 = Vector3(-8.0, 0.12, -4.0)
	if field != null:
		for u: RTSUnit in field.units:
			if not is_instance_valid(u) or not u.is_alive():
				continue
			var kind: String = str(u.get_meta("beam_kind", ""))
			var spot: Vector3 = u.global_position + Vector3(0.0, 1.3, 0.0)
			var aim: Vector3 = _beam_aim(u, spot)
			if kind == "painter":
				painter = true
				painter_at = spot
				painter_aim = aim
			elif kind == "leech":
				leech = true
				leech_at = spot
				leech_aim = aim
			elif kind == "fiber":
				fiber = true
				fiber_at = spot
				fiber_aim = aim
			elif kind == "prism":
				prism = true
				prism_at = spot
				prism_aim = aim
			if bool(u.get_meta("aegis", false)):
				aegis = true
				aegis_at = u.global_position + Vector3(0.0, 1.6, 0.0)
			if bool(u.get_meta("slagged", false)):
				slag = true
				slag_at = u.global_position + Vector3(0.0, 0.12, 0.0)
			elif goods != null and field.is_infantry(u) and goods.harm_infantry(u.global_position, bool(u.get_meta("shielded", false)), 1.0) > 0.0:
				slag = true
				slag_at = u.global_position + Vector3(0.0, 0.12, 0.0)
	var night: bool = false
	var night_at: Vector3 = Vector3(8.0, 1.3, -4.0)
	if goods != null:
		for node: Dictionary in goods.nodes:
			if bool(node.get("night", false)):
				night = true
				night_at = (node.get("pos", night_at) as Vector3) + Vector3(0.0, 1.3, 0.0)
	var jam: bool = ew != null and ew.active
	var jam_at: Vector3 = Vector3(8.0, 1.4, -6.0)
	if jam:
		jam_at = ew.center + Vector3(0.0, 1.4, 0.0)
	_aim_beam(host, "BeamPainter", painter, painter_at, painter_aim)
	_aim_beam(host, "BeamLeech", leech, leech_at, leech_aim)
	_aim_beam(host, "BeamFiber", fiber, fiber_at, fiber_aim)
	_aim_beam(host, "BeamPrism", prism, prism_at, prism_aim)
	_show(host, "AegisDome", aegis, aegis_at)
	_show(host, "JammerDome", jam, jam_at)
	_show(host, "RubyCone", night, night_at)
	_show(host, "SlagPool", slag, slag_at)

static func _ribbon() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half: float = 0.16
	var length: float = 6.0
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(Vector3(-half, 0.0, 0.0))
	st.set_uv(Vector2(1.0, 0.0))
	st.add_vertex(Vector3(half, 0.0, 0.0))
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(Vector3(half, 0.0, -length))
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(Vector3(-half, 0.0, 0.0))
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(Vector3(half, 0.0, -length))
	st.set_uv(Vector2(0.0, 1.0))
	st.add_vertex(Vector3(-half, 0.0, -length))
	st.generate_normals()
	return st.commit()

static func _beam_aim(u: RTSUnit, origin: Vector3) -> Vector3:
	var target: RTSUnit = u.attack_target
	if target != null and is_instance_valid(target) and target.is_alive():
		return target.global_position + Vector3(0.0, 1.2, 0.0)
	return origin - u.global_transform.basis.z * 6.0

static func _aim_beam(host: Node3D, node_name: String, on: bool, origin: Vector3, aim_at: Vector3) -> void:
	var body: MeshInstance3D = host.get_node_or_null(node_name) as MeshInstance3D
	if body == null:
		return
	body.visible = on
	if not on:
		return
	var span: float = origin.distance_to(aim_at)
	var aim: Vector3 = aim_at
	if span < 0.4:
		aim = origin + Vector3(0.0, 0.0, -6.0)
		span = 6.0
	body.global_position = origin
	body.look_at(aim, Vector3.UP)
	body.scale = Vector3(1.0, 1.0, clampf(span / 6.0, 0.25, 12.0))

static func _show(host: Node3D, node_name: String, on: bool, at: Vector3) -> void:
	var body: MeshInstance3D = host.get_node_or_null(node_name) as MeshInstance3D
	if body == null:
		return
	body.visible = on
	if on:
		body.global_position = at

static func _tint(color: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return mat
