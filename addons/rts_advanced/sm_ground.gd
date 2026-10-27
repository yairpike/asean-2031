extends RefCounted
## Terrain from a domain grid. Pathing flags are not changed.
## Land is one mesh, water is one shaded mesh, plants and houses are MultiMeshes.

const WATER_SHADER = preload("res://assets/shaders/channel_water.gdshader")
const RAIN_SHADER = preload("res://assets/shaders/monsoon_rain.gdshader")

const GRASS: Color = Color(0.3, 0.46, 0.22)
const MUD: Color = Color(0.38, 0.29, 0.18)
const SAND: Color = Color(0.74, 0.66, 0.42)
const DIRT: Color = Color(0.5, 0.39, 0.24)
const ROCK: Color = Color(0.46, 0.44, 0.4)
const WOOD: Color = Color(0.42, 0.3, 0.18)
const LEAF: Color = Color(0.18, 0.4, 0.16)
const PADDY: Color = Color(0.42, 0.58, 0.28)

static var _land_ink: StandardMaterial3D
static var _water_ink: ShaderMaterial
static var _rain_ink: ShaderMaterial
static var _site_ink: StandardMaterial3D
static var _prop_cache: Dictionary = {}

static func dress(host: Node3D, grid: SMDomainGrid, profile: String) -> void:
	if host == null or grid == null:
		return
	var land: SurfaceTool = _begin(_land_material())
	var road: SurfaceTool = _begin(_land_material())
	var water: SurfaceTool = _begin(_water_material())
	var paddy: SurfaceTool = _begin(_land_material())
	var trees: Array[Transform3D] = []
	var palms: Array[Transform3D] = []
	var houses: Array[Transform3D] = []
	var stilts: Array[Transform3D] = []
	var land_n: int = 0
	var road_n: int = 0
	var water_n: int = 0
	var paddy_n: int = 0
	for y: int in grid.rows:
		for x: int in grid.cols:
			var cell: Vector2i = Vector2i(x, y)
			var domain: int = grid.domain_at_cell(cell)
			if _wet(domain):
				var deep: float = 1.0 if domain != SMDomainGrid.Domain.SHALLOW else 0.0
				_flat(water, grid, cell, -0.2 if deep > 0.5 else -0.08, Color(deep, 0.0, 0.0), 0.5)
				water_n += 1
				continue
			var high: float = 1.55 if domain == SMDomainGrid.Domain.CLIFF else 0.22
			var bank: bool = _bank(grid, cell)
			var track: bool = domain == SMDomainGrid.Domain.LAND and _track(profile, cell)
			var cut: bool = profile == "burma" and _burma_cut(cell)
			var tint: Color = _tint(profile, cell, domain, bank, track or cut)
			if cut:
				_sloped(road, grid, cell, high, tint)
				road_n += 1
			else:
				_sloped(land, grid, cell, high, tint)
				land_n += 1
			if domain != SMDomainGrid.Domain.LAND or _busy(profile, cell) or cut:
				continue
			var roll: int = _hash(x, y)
			if bank and roll % 7 == 0 and palms.size() < 48:
				palms.append(_xf(grid, cell, high, roll))
			elif not bank and roll % 9 == 0 and trees.size() < 90:
				trees.append(_xf(grid, cell, high, roll))
			if bank and roll % 17 == 3 and stilts.size() < 18:
				stilts.append(_xf(grid, cell, high, roll))
			elif not bank and not track and roll % 29 == 4 and houses.size() < 28:
				houses.append(_xf(grid, cell, high, roll))
			var rice: bool = profile == "mekong" and roll % 3 == 0 or roll % 23 == 1
			if rice and not track and not bank and paddy_n < 48 and not _bridge_cell(cell):
				_flat(paddy, grid, cell, high + 0.05, PADDY)
				paddy_n += 1
	_commit(host, _land_name(profile), land, land_n > 0)
	_commit(host, _water_name(profile), water, water_n > 0)
	if profile == "burma":
		_commit(host, "Road", road, road_n > 0)
	if paddy_n > 0:
		_commit(host, "Paddy", paddy, true)
	_multi(host, "JungleTrees", _prop("tree"), trees)
	_multi(host, "Palms", _prop("palm"), palms)
	_multi(host, "Houses", _prop("house"), houses)
	_multi(host, "Stilts", _prop("stilt"), stilts)
	_markers(host, profile)

static func dress_site(mi: MeshInstance3D, form: String, accent: Color) -> void:
	mi.mesh = _site(form, accent)
	mi.material_override = null
	mi.set_meta("form", form)

static func apply_sky(host: Node3D, sight: SMSight) -> void:
	if host == null or sight == null:
		return
	var env: WorldEnvironment = host.find_child("WorldEnvironment", false, false) as WorldEnvironment
	if env != null and env.environment != null:
		_fog(env.environment, sight)
	var rain: MeshInstance3D = host.get_node_or_null("Rain") as MeshInstance3D
	if rain == null:
		rain = _rain(sight)
		host.add_child(rain)
	rain.visible = sight.monsoon

static func _fog(env: Environment, sight: SMSight) -> void:
	if sight.hazy:
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
		env.fog_density = 0.032
		env.fog_light_color = Color(0.72, 0.66, 0.52)
		env.fog_aerial_perspective = 0.4
	elif sight.monsoon:
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
		env.fog_density = 0.012
		env.fog_light_color = Color(0.55, 0.58, 0.62)
		env.fog_aerial_perspective = 0.2
	else:
		env.fog_enabled = false

static func _land_name(profile: String) -> String:
	if profile == "sop":
		return "WestSector"
	if profile == "burma":
		return "HighlandWest"
	if profile == "atolls":
		return "WestIsle"
	if profile == "chiang":
		return "Plain"
	if profile == "mvd":
		return "CharcoalPad"
	if profile == "nmrf":
		return "OliveGround"
	if profile == "mission" or profile == "kokang":
		return "Ground"
	return "TerrainLand"

static func _water_name(profile: String) -> String:
	if profile == "sop":
		return "RiverStem"
	if profile == "atolls":
		return "Sea"
	if profile == "mekong":
		return "CanalWest"
	if profile == "chiang":
		return "SiegeRiver"
	if profile == "mvd":
		return "CyanRing"
	if profile == "nmrf":
		return "EmeraldWater"
	return "TerrainWater"

static func _markers(host: Node3D, profile: String) -> void:
	if profile == "sop":
		_ghost(host, "EastSector")
		_ghost(host, "NorthSector")
	elif profile == "chiang":
		_ghost(host, "WallWest")
	elif profile == "mekong":
		_ghost(host, "CanalEast")

static func _ghost(host: Node3D, node_name: String) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	mi.visible = false
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.2, 0.2, 0.2)
	mi.mesh = box
	host.add_child(mi)

static func _wet(domain: int) -> bool:
	return domain == SMDomainGrid.Domain.SHALLOW or domain == SMDomainGrid.Domain.DEEP or domain == SMDomainGrid.Domain.AIR

static func _bank(grid: SMDomainGrid, cell: Vector2i) -> bool:
	return _touches_water(grid, cell, -1, 0) or _touches_water(grid, cell, 1, 0) or _touches_water(grid, cell, 0, -1) or _touches_water(grid, cell, 0, 1)

static func _touches_water(grid: SMDomainGrid, cell: Vector2i, sx: int, sz: int) -> bool:
	if sx == 0 and sz == 0:
		return false
	var stepx: int = -1 if sx < 0 else (1 if sx > 0 else 0)
	var stepz: int = -1 if sz < 0 else (1 if sz > 0 else 0)
	var samples: Array[Vector2i] = [Vector2i(cell.x + stepx, cell.y), Vector2i(cell.x, cell.y + stepz), Vector2i(cell.x + stepx, cell.y + stepz)]
	for sample: Vector2i in samples:
		if stepx == 0 and sample.x != cell.x:
			continue
		if stepz == 0 and sample.y != cell.y:
			continue
		if _wet(grid.domain_at_cell(sample)):
			return true
	return false

static func _track(profile: String, cell: Vector2i) -> bool:
	if profile == "chiang" and cell.x >= 26 and cell.x < 30 and ((cell.y >= 8 and cell.y < 12) or (cell.y >= 28 and cell.y < 32)):
		return true
	return cell.y % 8 == 3

static func _burma_cut(cell: Vector2i) -> bool:
	return cell.x >= 16 and cell.x < 24 and cell.y >= 12 and cell.y < 16

static func _bridge_cell(cell: Vector2i) -> bool:
	var west: bool = cell.x >= 12 and cell.x < 15 and cell.y >= 14 and cell.y < 18
	var east: bool = cell.x >= 26 and cell.x < 29 and cell.y >= 14 and cell.y < 18
	return west or east

static func _busy(profile: String, cell: Vector2i) -> bool:
	if profile == "phillips" and cell.y >= 7 and cell.y <= 9 and cell.x <= 14:
		return true
	if profile == "phillips" and cell.x >= 29 and cell.x <= 34 and cell.y >= 10 and cell.y <= 15:
		return true
	return false

static func _tint(profile: String, cell: Vector2i, domain: int, bank: bool, road: bool) -> Color:
	if domain == SMDomainGrid.Domain.CLIFF:
		return ROCK
	if road:
		return DIRT
	if profile == "atolls":
		return SAND
	var roll: int = _hash(cell.x + 3, cell.y + 9)
	if bank:
		return SAND if roll % 2 == 0 else MUD
	if roll % 7 == 0:
		return MUD
	if roll % 7 == 1:
		return SAND
	return GRASS

static func _hash(x: int, y: int) -> int:
	var n: int = x * 374761393 + y * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	return n & 2147483647

static func _xf(grid: SMDomainGrid, cell: Vector2i, high: float, roll: int) -> Transform3D:
	var at: Vector3 = grid.cell_center(cell)
	at.y = high
	var yaw: float = float(roll % 628) * 0.01
	return Transform3D(Basis(Vector3.UP, yaw), at)

static func _commit(host: Node3D, node_name: String, st: SurfaceTool, keep: bool) -> void:
	if not keep or node_name == "":
		return
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	st.generate_normals()
	mi.mesh = st.commit()
	host.add_child(mi)

static func _multi(host: Node3D, node_name: String, mesh: ArrayMesh, spots: Array[Transform3D]) -> void:
	if spots.is_empty():
		return
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = spots.size()
	for i: int in spots.size():
		mm.set_instance_transform(i, spots[i])
	var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(node)

static func _begin(mat: Material) -> SurfaceTool:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat)
	return st

static func _flat(st: SurfaceTool, grid: SMDomainGrid, cell: Vector2i, y: float, color: Color, cover: float = 0.46) -> void:
	var c: Vector3 = grid.cell_center(cell)
	var h: float = grid.cell_size * cover
	_quad(st, Vector3(c.x - h, y, c.z - h), Vector3(c.x + h, y, c.z - h), Vector3(c.x + h, y, c.z + h), Vector3(c.x - h, y, c.z + h), color)

static func _sloped(st: SurfaceTool, grid: SMDomainGrid, cell: Vector2i, high: float, color: Color) -> void:
	var c: Vector3 = grid.cell_center(cell)
	var h: float = grid.cell_size * 0.5
	var y00: float = _corner(grid, cell, -1, -1, high)
	var y10: float = _corner(grid, cell, 1, -1, high)
	var y11: float = _corner(grid, cell, 1, 1, high)
	var y01: float = _corner(grid, cell, -1, 1, high)
	_quad(st, Vector3(c.x - h, y00, c.z - h), Vector3(c.x + h, y10, c.z - h), Vector3(c.x + h, y11, c.z + h), Vector3(c.x - h, y01, c.z + h), color)

static func _corner(grid: SMDomainGrid, cell: Vector2i, sx: int, sz: int, high: float) -> float:
	if _touches_water(grid, cell, sx, sz):
		return 0.0
	return high

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	st.set_color(color)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(d)

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

static func _land_material() -> StandardMaterial3D:
	if _land_ink == null:
		_land_ink = StandardMaterial3D.new()
		_land_ink.vertex_color_use_as_albedo = true
		_land_ink.roughness = 0.92
		_land_ink.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _land_ink

static func _water_material() -> ShaderMaterial:
	if _water_ink == null:
		_water_ink = ShaderMaterial.new()
		_water_ink.shader = WATER_SHADER
	return _water_ink

static func _site_material() -> StandardMaterial3D:
	if _site_ink == null:
		_site_ink = StandardMaterial3D.new()
		_site_ink.vertex_color_use_as_albedo = true
		_site_ink.roughness = 0.7
		_site_ink.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _site_ink

static func _prop(kind: String) -> ArrayMesh:
	if _prop_cache.has(kind):
		return _prop_cache[kind] as ArrayMesh
	var st: SurfaceTool = _begin(_land_material())
	if kind == "palm":
		_palm(st)
	elif kind == "house":
		_house(st)
	elif kind == "stilt":
		_stilt(st)
	else:
		_tree(st)
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	_prop_cache[kind] = mesh
	return mesh

static func _tree(st: SurfaceTool) -> void:
	_box(st, Vector3(0.0, 0.7, 0.0), Vector3(0.28, 1.4, 0.28), WOOD)
	_box(st, Vector3(0.0, 1.7, 0.0), Vector3(1.5, 0.9, 1.5), LEAF)
	_box(st, Vector3(0.15, 2.2, -0.1), Vector3(1.0, 0.6, 1.0), Color(0.22, 0.48, 0.2))

static func _palm(st: SurfaceTool) -> void:
	_box(st, Vector3(0.0, 0.5, 0.0), Vector3(0.18, 1.0, 0.18), WOOD)
	_box(st, Vector3(0.12, 1.35, 0.0), Vector3(0.16, 0.9, 0.16), WOOD)
	_box(st, Vector3(0.2, 2.05, 0.0), Vector3(1.6, 0.08, 0.22), LEAF)
	_box(st, Vector3(0.2, 2.05, 0.0), Vector3(0.22, 0.08, 1.6), LEAF)

static func _house(st: SurfaceTool) -> void:
	_box(st, Vector3(0.0, 0.55, 0.0), Vector3(1.5, 1.0, 1.2), Color(0.62, 0.5, 0.36))
	_box(st, Vector3(0.0, 1.15, 0.0), Vector3(1.7, 0.28, 1.4), Color(0.55, 0.22, 0.16))
	_box(st, Vector3(0.0, 0.4, -0.62), Vector3(0.35, 0.6, 0.06), WOOD)

static func _stilt(st: SurfaceTool) -> void:
	_box(st, Vector3(-0.45, 0.45, -0.35), Vector3(0.1, 0.9, 0.1), WOOD)
	_box(st, Vector3(0.45, 0.45, -0.35), Vector3(0.1, 0.9, 0.1), WOOD)
	_box(st, Vector3(-0.45, 0.45, 0.35), Vector3(0.1, 0.9, 0.1), WOOD)
	_box(st, Vector3(0.45, 0.45, 0.35), Vector3(0.1, 0.9, 0.1), WOOD)
	_box(st, Vector3(0.0, 1.0, 0.0), Vector3(1.3, 0.12, 1.05), WOOD)
	_box(st, Vector3(0.0, 1.4, 0.0), Vector3(1.15, 0.6, 0.9), Color(0.55, 0.42, 0.28))
	_box(st, Vector3(0.0, 1.8, 0.0), Vector3(1.35, 0.16, 1.1), Color(0.45, 0.2, 0.14))

static func _site(form: String, accent: Color) -> ArrayMesh:
	var key: String = "%s|%s" % [form, accent.to_html(false)]
	if _prop_cache.has(key):
		return _prop_cache[key] as ArrayMesh
	var st: SurfaceTool = _begin(_site_material())
	if form == "cyber":
		_box(st, Vector3(0.0, 0.45, 0.0), Vector3(1.5, 0.9, 1.2), Color(0.22, 0.2, 0.28))
		_box(st, Vector3(0.0, 0.7, -0.62), Vector3(0.7, 0.4, 0.06), accent)
		_box(st, Vector3(0.45, 1.15, 0.0), Vector3(0.08, 0.7, 0.08), Color(0.7, 0.72, 0.75))
	elif form == "bazaar":
		_box(st, Vector3(0.0, 0.35, 0.0), Vector3(1.6, 0.7, 1.1), WOOD)
		_box(st, Vector3(0.0, 0.95, -0.15), Vector3(2.3, 0.1, 1.5), accent)
		_box(st, Vector3(-0.7, 0.5, -0.7), Vector3(0.08, 1.0, 0.08), WOOD)
		_box(st, Vector3(0.7, 0.5, -0.7), Vector3(0.08, 1.0, 0.08), WOOD)
	elif form == "garrison":
		_box(st, Vector3(0.0, 0.35, 0.0), Vector3(1.8, 0.7, 1.5), Color(0.55, 0.5, 0.42))
		_box(st, Vector3(0.0, 0.9, -0.7), Vector3(1.8, 0.45, 0.16), WOOD)
		_box(st, Vector3(-0.7, 1.15, 0.2), Vector3(0.08, 0.9, 0.08), WOOD)
		_box(st, Vector3(-0.7, 1.55, 0.2), Vector3(0.4, 0.22, 0.08), accent)
	elif form == "bridge":
		_box(st, Vector3(0.0, 0.0, 0.0), Vector3(2.4, 0.16, 1.0), WOOD)
		_box(st, Vector3(-1.05, 0.16, 0.0), Vector3(0.1, 0.18, 1.05), Color(0.3, 0.22, 0.14))
		_box(st, Vector3(1.05, 0.16, 0.0), Vector3(0.1, 0.18, 1.05), Color(0.3, 0.22, 0.14))
	elif form == "radar":
		_box(st, Vector3(0.0, 0.7, 0.0), Vector3(0.16, 1.4, 0.16), Color(0.35, 0.38, 0.42))
		_box(st, Vector3(0.0, 1.45, 0.1), Vector3(0.9, 0.08, 0.9), accent)
	elif form == "derrick":
		_box(st, Vector3(0.0, 1.0, 0.0), Vector3(0.22, 2.0, 0.22), Color(0.32, 0.3, 0.28))
		_box(st, Vector3(0.35, 1.7, 0.0), Vector3(0.7, 0.12, 0.12), accent)
	elif form == "salvage":
		_box(st, Vector3(-0.3, 0.25, 0.0), Vector3(0.7, 0.35, 1.2), Color(0.28, 0.26, 0.24))
		_box(st, Vector3(0.35, 0.4, 0.2), Vector3(0.5, 0.5, 0.7), accent)
	elif form == "clinic":
		_box(st, Vector3(0.0, 0.45, 0.0), Vector3(1.4, 0.8, 1.1), Color(0.82, 0.84, 0.86))
		_box(st, Vector3(0.0, 0.7, -0.56), Vector3(0.4, 0.4, 0.06), Color(0.7, 0.15, 0.18))
	else:
		_box(st, Vector3(0.0, 0.2, 0.0), Vector3(1.15, 0.28, 1.15), Color(0.34, 0.3, 0.24))
		_box(st, Vector3(0.0, 0.5, 0.0), Vector3(0.45, 0.45, 0.45), accent)
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	_prop_cache[key] = mesh
	return mesh

static func _rain(sight: SMSight) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Rain"
	mi.visible = false
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat: ShaderMaterial = _rain_ink
	if mat == null:
		mat = ShaderMaterial.new()
		mat.shader = RAIN_SHADER
		_rain_ink = mat
	var st: SurfaceTool = _begin(mat)
	var origin: Vector3 = Vector3(-40.0, 0.0, -30.0)
	var span: Vector3 = Vector3(80.0, 0.0, 60.0)
	if sight.grid != null:
		origin = sight.grid.origin
		span = Vector3(float(sight.grid.cols) * sight.grid.cell_size, 0.0, float(sight.grid.rows) * sight.grid.cell_size)
	for i: int in 56:
		var rx: float = float(_hash(i, 2) % 1000) / 1000.0
		var rz: float = float(_hash(3, i) % 1000) / 1000.0
		var at: Vector3 = origin + Vector3(rx * span.x, 12.0, rz * span.z)
		_box(st, at, Vector3(0.06, 7.0, 0.02), Color.WHITE)
	st.generate_normals()
	mi.mesh = st.commit()
	return mi
