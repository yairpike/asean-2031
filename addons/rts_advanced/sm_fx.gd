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
	_place(host, "AegisDome", Vector3(5.0, 1.6, -8.0), bubble, shader_material("res://assets/shaders/aegis_dome_shield.gdshader"))
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
	_place(host, "SlagPool", Vector3(-8.0, 0.12, -4.0), pool, shader_material("res://assets/shaders/slag_corrosion_pool.gdshader"))

static func ice_material() -> ShaderMaterial:
	return shader_material("res://assets/shaders/cryo_freeze_overlay.gdshader")

static func shader_material(path: String) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	var shader: Shader = load(path) as Shader
	mat.shader = shader
	return mat

static func _beam(host: Node3D, node_name: String, at: Vector3, color: Color) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.12, 0.12, 3.2)
	_place(host, node_name, at, mesh, _tint(color))

static func _place(host: Node3D, node_name: String, at: Vector3, mesh: Mesh, mat: Material) -> void:
	if host.get_node_or_null(node_name) != null:
		return
	var body: MeshInstance3D = MeshInstance3D.new()
	body.name = node_name
	body.mesh = mesh
	body.position = at
	body.material_override = mat
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(body)

static func _tint(color: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return mat
