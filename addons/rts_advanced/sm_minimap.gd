class_name SMMinimap
extends Control
## Flat map of the domain grid. Land, water, both sides, and the camera rectangle.

const LAND_COLOR: Color = Color(0.40, 0.36, 0.24)
const CLIFF_COLOR: Color = Color(0.50, 0.46, 0.40)
const WATER_COLOR: Color = Color(0.10, 0.32, 0.55)
const FRAME_COLOR: Color = Color(0.93, 0.94, 0.96)
const VIEW_COLOR: Color = Color(0.96, 0.92, 0.72)

var grid: SMDomainGrid
var field: SMPointer
var camera: RTSCamera
var sight: SMSight
var goods: SMCommodityNet
var player_dots: int = 0
var enemy_dots: int = 0
var building_dots: int = 0
var claimed_dots: int = 0
var saw_land: bool = false
var saw_water: bool = false
var camera_rect: Rect2 = Rect2()

func setup(p_grid: SMDomainGrid, p_field: SMPointer, p_camera: RTSCamera) -> void:
	grid = p_grid
	field = p_field
	camera = p_camera
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(156, 108)
	size = Vector2(156, 108)

func map_size() -> Vector2:
	if size.x < 8.0 or size.y < 8.0:
		return Vector2(200, 160)
	return size

func terrain_kind(cell: Vector2i) -> String:
	if grid == null:
		return "land"
	var domain: int = grid.domain_at_cell(cell)
	if domain == SMDomainGrid.Domain.SHALLOW or domain == SMDomainGrid.Domain.DEEP:
		return "water"
	return "land"

func sample() -> void:
	saw_land = false
	saw_water = false
	player_dots = 0
	enemy_dots = 0
	building_dots = 0
	claimed_dots = 0
	if grid != null:
		for y: int in grid.rows:
			for x: int in grid.cols:
				if terrain_kind(Vector2i(x, y)) == "water":
					saw_water = true
				else:
					saw_land = true
	if field != null:
		player_dots = field.units_of(SMPointer.PLAYER).size()
		for u: RTSUnit in field.units_of(SMPointer.ENEMY):
			if sight == null or sight.sees(u.global_position):
				enemy_dots += 1
	if sight != null:
		for at: Vector3 in sight.posts:
			if sight.sees(at):
				building_dots += 1
	if goods != null:
		for node: Dictionary in goods.nodes:
			if int(node.get("team", -1)) >= 0:
				claimed_dots += 1
	camera_rect = _view_rect()

func covers_focus() -> bool:
	if camera == null:
		return false
	return camera_rect.grow(0.5).has_point(Vector2(camera.focus.x, camera.focus.z))

func pan_to(local: Vector2) -> Vector3:
	var world: Vector3 = _local_to_world(local)
	if camera != null:
		camera.focus_on(world)
		camera_rect = _view_rect()
	return world

func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		pan_to(mb.position)
		accept_event()

func _draw() -> void:
	var extent: Vector2 = map_size()
	if grid == null or grid.cols <= 0 or grid.rows <= 0:
		draw_rect(Rect2(Vector2.ZERO, extent), LAND_COLOR, true)
		return
	var step: Vector2 = Vector2(extent.x / float(grid.cols), extent.y / float(grid.rows))
	for y: int in grid.rows:
		for x: int in grid.cols:
			var cell: Vector2i = Vector2i(x, y)
			draw_rect(Rect2(Vector2(float(x) * step.x, float(y) * step.y), step + Vector2(0.5, 0.5)), _cell_color(cell), true)
	if field != null:
		var friendly: Color = field.teams.color_of(SMPointer.PLAYER)
		var hostile: Color = field.teams.color_of(SMPointer.ENEMY)
		for u: RTSUnit in field.units_of(SMPointer.PLAYER):
			_dot(u.global_position, friendly)
		for u: RTSUnit in field.units_of(SMPointer.ENEMY):
			if sight == null or sight.sees(u.global_position):
				_dot(u.global_position, hostile)
		if field.beacon_at != Vector3.INF:
			var beacon_p: Vector2 = _world_to_local(field.beacon_at)
			draw_rect(Rect2(beacon_p - Vector2(5, 5), Vector2(10, 10)), Color(0.98, 0.82, 0.28), false, 2.0)
	if sight != null:
		for at: Vector3 in sight.posts:
			if sight.sees(at):
				_dot(at, Color(0.55, 0.16, 0.14))
	if goods != null:
		for node: Dictionary in goods.nodes:
			if int(node.get("team", -1)) >= 0:
				var spot: Vector3 = node.get("pos", Vector3.ZERO) as Vector3
				_dot(spot, Color(0.95, 0.78, 0.22))
	var local_view: Rect2 = _world_rect_local(camera_rect)
	if local_view.size.x > 1.0 and local_view.size.y > 1.0:
		draw_rect(local_view, VIEW_COLOR, false, 2.0)
	draw_rect(Rect2(Vector2.ZERO, extent), FRAME_COLOR, false, 1.0)

func _cell_color(cell: Vector2i) -> Color:
	var domain: int = grid.domain_at_cell(cell)
	var base: Color = LAND_COLOR
	if domain == SMDomainGrid.Domain.SHALLOW or domain == SMDomainGrid.Domain.DEEP:
		base = WATER_COLOR
	elif domain == SMDomainGrid.Domain.CLIFF:
		base = CLIFF_COLOR
	if sight == null:
		return base
	var state: int = sight.cell_state(cell)
	if state == SMSight.HIDDEN:
		return Color(0.04, 0.05, 0.07)
	if state == SMSight.DIM:
		return base.lerp(Color(0.05, 0.05, 0.06), 0.62)
	return base

func _dot(at: Vector3, color: Color) -> void:
	var p: Vector2 = _world_to_local(at)
	draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), color, true)

func _world_to_local(at: Vector3) -> Vector2:
	var extent: Vector2 = map_size()
	var span: Vector2 = _span()
	var u: float = clampf((at.x - grid.origin.x) / span.x, 0.0, 1.0)
	var v: float = clampf((at.z - grid.origin.z) / span.y, 0.0, 1.0)
	return Vector2(u * extent.x, v * extent.y)

func _local_to_world(local: Vector2) -> Vector3:
	var extent: Vector2 = map_size()
	var span: Vector2 = _span()
	var u: float = clampf(local.x / extent.x, 0.0, 1.0)
	var v: float = clampf(local.y / extent.y, 0.0, 1.0)
	return Vector3(grid.origin.x + u * span.x, 0.0, grid.origin.z + v * span.y)

func _span() -> Vector2:
	return Vector2(float(grid.cols) * grid.cell_size, float(grid.rows) * grid.cell_size)

func _world_rect_local(world: Rect2) -> Rect2:
	if grid == null:
		return Rect2()
	var a: Vector2 = _world_to_local(Vector3(world.position.x, 0.0, world.position.y))
	var b: Vector2 = _world_to_local(Vector3(world.end.x, 0.0, world.end.y))
	return Rect2(a, b - a).abs()

func _view_rect() -> Rect2:
	if camera == null:
		return Rect2()
	var vs: Vector2 = Vector2(1280, 720)
	var vp: Viewport = camera.get_viewport()
	if vp != null:
		var visible: Vector2 = vp.get_visible_rect().size
		if visible.x >= 2.0 and visible.y >= 2.0:
			vs = visible
	var min_x: float = INF
	var max_x: float = -INF
	var min_z: float = INF
	var max_z: float = -INF
	var hits: int = 0
	var corners: Array[Vector2] = [Vector2(0, 0), Vector2(vs.x, 0), Vector2(vs.x, vs.y), Vector2(0, vs.y)]
	for corner: Vector2 in corners:
		var ground: Vector3 = camera.ground_at(corner)
		if ground == Vector3.INF:
			continue
		hits += 1
		min_x = minf(min_x, ground.x)
		max_x = maxf(max_x, ground.x)
		min_z = minf(min_z, ground.z)
		max_z = maxf(max_z, ground.z)
	var projected: Rect2 = Rect2()
	if hits == 4:
		projected = Rect2(min_x, min_z, maxf(0.5, max_x - min_x), maxf(0.5, max_z - min_z))
	if hits == 4 and projected.grow(0.5).has_point(Vector2(camera.focus.x, camera.focus.z)):
		return projected
	var half: float = maxf(6.0, camera.distance * 0.35)
	return Rect2(camera.focus.x - half, camera.focus.z - half, half * 2.0, half * 2.0)
