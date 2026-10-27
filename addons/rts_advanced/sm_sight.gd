class_name SMSight
extends RefCounted

const World = preload("res://game/world_view.gd")
## Fog for a skirmish. Explored ground stays dim. Current sight is clear.

const UNIT_RADIUS: float = 18.0
const CYCLE: float = 24.0
const MONSOON_AT: float = 8.0
const HAZE_AT: float = 16.0
const HAZE_SIGHT: float = 0.35
const MUD: float = 0.55
const HIDDEN: int = 0
const DIM: int = 1
const CLEAR: int = 2

var grid: SMDomainGrid
var seers: Array[Vector3] = []
var radii: Array[float] = []
var posts: Array[Vector3] = []
var explored: PackedByteArray = PackedByteArray()
var weather_t: float = 0.0
var hazy: bool = false
var monsoon: bool = false
var weather_name: String = "Clear"
var river_lit: bool = false

func bind(p_grid: SMDomainGrid) -> void:
	grid = p_grid
	explored = PackedByteArray()
	explored.resize(grid.cols * grid.rows)
	explored.fill(0)

func advance_weather(delta: float) -> void:
	weather_t += delta
	var phase: float = fmod(weather_t, CYCLE)
	if phase < 0.0:
		phase += CYCLE
	monsoon = phase >= MONSOON_AT and phase < HAZE_AT
	hazy = phase >= HAZE_AT
	_name_sky()

func force_weather(p_hazy: bool) -> void:
	hazy = p_hazy
	monsoon = false
	weather_name = "Strait Haze" if hazy else "Clear"

func force_monsoon(on: bool) -> void:
	monsoon = on
	hazy = false
	weather_name = "Monsoon" if on else "Clear"

func ground_drag() -> float:
	if monsoon:
		return MUD
	return 1.0

func unit_radius(radar_held: bool) -> float:
	if (hazy or monsoon) and not radar_held:
		return UNIT_RADIUS * HAZE_SIGHT
	return UNIT_RADIUS

func _name_sky() -> void:
	if monsoon:
		weather_name = "Monsoon"
	elif hazy:
		weather_name = "Strait Haze"
	else:
		weather_name = "Clear"

func begin() -> void:
	seers.clear()
	radii.clear()
	posts.clear()
	river_lit = false

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
	if river_lit and _on_corridor(at):
		return true
	for i: int in seers.size():
		if _flat(at, seers[i]) <= radii[i]:
			return true
	return false

func _on_corridor(at: Vector3) -> bool:
	if grid == null:
		return false
	var cell: Vector2i = grid.cell_at(at)
	if not grid.in_bounds(cell):
		return false
	if _wet(grid.domain_at_cell(cell)):
		return true
	var east: Vector2i = cell + Vector2i(1, 0)
	var west: Vector2i = cell + Vector2i(-1, 0)
	var south: Vector2i = cell + Vector2i(0, 1)
	var north: Vector2i = cell + Vector2i(0, -1)
	if grid.in_bounds(east) and _wet(grid.domain_at_cell(east)):
		return true
	if grid.in_bounds(west) and _wet(grid.domain_at_cell(west)):
		return true
	if grid.in_bounds(south) and _wet(grid.domain_at_cell(south)):
		return true
	if grid.in_bounds(north) and _wet(grid.domain_at_cell(north)):
		return true
	return false

func _wet(domain: int) -> bool:
	return domain == SMDomainGrid.Domain.SHALLOW or domain == SMDomainGrid.Domain.DEEP

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
			if field.teams.are_allies(SMPointer.PLAYER, u.team):
				u.visible = true
			else:
				u.visible = sees(u.global_position)
	_hide_marker(host, "EnemyYard")
	_hide_marker(host, "EnemyClaim")

static func update_match(sight: SMSight, field: SMPointer, host: Node3D, tech: SMTechNet, raider: SMRaider) -> void:
	if sight == null or field == null:
		return
	sight.begin()
	var radar_held: bool = tech != null and tech.reveals_water(SMPointer.PLAYER)
	var reach: float = sight.unit_radius(radar_held)
	for u: RTSUnit in field.units:
		if is_instance_valid(u) and u.is_alive() and field.teams.are_allies(SMPointer.PLAYER, u.team):
			sight.add_seer(u.global_position, reach)
	if radar_held:
		sight.river_lit = true
		for at: Vector3 in tech.vision_points(SMPointer.PLAYER):
			sight.add_seer(at, SMTechNet.VISION_RADIUS)
	if raider != null and raider.yard != null and raider.yard.living_count() > 0:
		sight.note_post(raider.yard.center)
	sight.commit()
	sight.conceal(field, host)
	apply_drag(sight, field)
	World.sync(host, sight, field.cam)

static func apply_drag(sight: SMSight, field: SMPointer) -> void:
	if sight == null or field == null:
		return
	var drag: float = sight.ground_drag()
	for u: RTSUnit in field.units:
		if not is_instance_valid(u):
			continue
		var loco: String = str(u.get_meta("locomotion", "ground"))
		u.set_meta("weather_drag", drag if loco == "ground" else 1.0)

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
