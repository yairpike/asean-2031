class_name SMSight
extends RefCounted
## Fog for a skirmish. Explored ground stays dim. Current sight is clear.

const UNIT_RADIUS: float = 18.0
const CYCLE: float = 24.0
const HAZE_AT: float = 12.0
const HAZE_SIGHT: float = 0.35
const HIDDEN: int = 0
const DIM: int = 1
const CLEAR: int = 2

var grid: SMDomainGrid
var seers: Array[Vector3] = []
var radii: Array[float] = []
var posts: Array[Vector3] = []
var explored: PackedByteArray = PackedByteArray()
var veil: MeshInstance3D
var weather_t: float = 0.0
var hazy: bool = false
var weather_name: String = "Clear"

func bind(p_grid: SMDomainGrid) -> void:
	grid = p_grid
	explored = PackedByteArray()
	explored.resize(grid.cols * grid.rows)
	explored.fill(0)

func advance_weather(delta: float) -> void:
	weather_t += delta
	hazy = fmod(weather_t, CYCLE) >= HAZE_AT
	weather_name = "Strait Haze" if hazy else "Clear"

func force_weather(p_hazy: bool) -> void:
	hazy = p_hazy
	weather_name = "Strait Haze" if hazy else "Clear"

func unit_radius(radar_held: bool) -> float:
	if hazy and not radar_held:
		return UNIT_RADIUS * HAZE_SIGHT
	return UNIT_RADIUS

func begin() -> void:
	seers.clear()
	radii.clear()
	posts.clear()

func add_seer(at: Vector3, radius: float) -> void:
	seers.append(at)
	radii.append(radius)

func note_post(at: Vector3) -> void:
	posts.append(at)

func commit() -> void:
	if grid == null:
		return
	for y: int in grid.rows:
		for x: int in grid.cols:
			if sees(grid.cell_center(Vector2i(x, y))):
				explored[_index(Vector2i(x, y))] = 1

func sees(at: Vector3) -> bool:
	for i: int in seers.size():
		if _flat(at, seers[i]) <= radii[i]:
			return true
	return false

func cell_state(cell: Vector2i) -> int:
	if grid == null or not grid.in_bounds(cell):
		return HIDDEN
	if sees(grid.cell_center(cell)):
		return CLEAR
	if explored[_index(cell)] == 1:
		return DIM
	return HIDDEN

func conceal(field: SMPointer, host: Node3D) -> void:
	if field != null:
		for u: RTSUnit in field.units:
			if not is_instance_valid(u):
				continue
			if u.team == SMPointer.PLAYER:
				u.visible = true
			else:
				u.visible = sees(u.global_position)
	_hide_marker(host, "EnemyYard")
	_hide_marker(host, "EnemyClaim")
	paint(host)

func paint(host: Node3D) -> void:
	if host == null or grid == null:
		return
	if veil == null or not is_instance_valid(veil):
		veil = host.get_node_or_null("FogVeil") as MeshInstance3D
	if veil == null:
		veil = MeshInstance3D.new()
		veil.name = "FogVeil"
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.vertex_color_use_as_albedo = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_color = Color.WHITE
		veil.material_override = mat
		veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		host.add_child(veil)
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hidden: Color = Color(0.03, 0.04, 0.05, 0.92)
	var dim: Color = Color(0.04, 0.05, 0.07, 0.42)
	var y: float = 0.42
	var half: float = grid.cell_size * 0.49
	for row: int in grid.rows:
		for col: int in grid.cols:
			var state: int = cell_state(Vector2i(col, row))
			if state == CLEAR:
				continue
			var ink: Color = hidden if state == HIDDEN else dim
			var center: Vector3 = grid.cell_center(Vector2i(col, row))
			_quad(tool, center, half, y, ink)
	veil.mesh = tool.commit()

static func update_match(sight: SMSight, field: SMPointer, host: Node3D, tech: SMTechNet, raider: SMRaider) -> void:
	if sight == null or field == null:
		return
	sight.begin()
	var radar_held: bool = tech != null and tech.reveals_water(SMPointer.PLAYER)
	var reach: float = sight.unit_radius(radar_held)
	for u: RTSUnit in field.units_of(SMPointer.PLAYER):
		sight.add_seer(u.global_position, reach)
	if radar_held:
		for at: Vector3 in tech.vision_points(SMPointer.PLAYER):
			sight.add_seer(at, SMTechNet.VISION_RADIUS)
	if raider != null and raider.yard != null and raider.yard.living_count() > 0:
		sight.note_post(raider.yard.center)
	sight.commit()
	sight.conceal(field, host)

func _hide_marker(host: Node3D, node_name: String) -> void:
	if host == null:
		return
	var node: Node3D = host.get_node_or_null(node_name) as Node3D
	if node == null:
		return
	node.visible = sees(node.global_position)

func _index(cell: Vector2i) -> int:
	return cell.y * grid.cols + cell.x

func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))

func _quad(tool: SurfaceTool, center: Vector3, half: float, y: float, ink: Color) -> void:
	var a: Vector3 = Vector3(center.x - half, y, center.z - half)
	var b: Vector3 = Vector3(center.x + half, y, center.z - half)
	var c: Vector3 = Vector3(center.x + half, y, center.z + half)
	var d: Vector3 = Vector3(center.x - half, y, center.z + half)
	tool.set_color(ink)
	tool.add_vertex(a)
	tool.set_color(ink)
	tool.add_vertex(b)
	tool.set_color(ink)
	tool.add_vertex(c)
	tool.set_color(ink)
	tool.add_vertex(a)
	tool.set_color(ink)
	tool.add_vertex(c)
	tool.set_color(ink)
	tool.add_vertex(d)
