class_name RTSGridNav
extends RefCounted
## Grid pathfinding on the XZ plane (AStarGrid2D, 8-way, no corner cutting).
## Cell (0,0) starts at `origin`; cells are `cell_size` metres square.

var cols: int
var rows: int
var cell_size: float
var origin: Vector3
var astar: AStarGrid2D = AStarGrid2D.new()

func _init(p_cols: int = 32, p_rows: int = 32, p_cell: float = 2.0, p_origin: Vector3 = Vector3.ZERO) -> void:
	cols = p_cols
	rows = p_rows
	cell_size = p_cell
	origin = p_origin
	astar.region = Rect2i(0, 0, cols, rows)
	astar.cell_size = Vector2(cell_size, cell_size)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()

func in_bounds(c: Vector2i) -> bool:
	return astar.is_in_boundsv(c)

func cell_at(p: Vector3) -> Vector2i:
	return Vector2i(floori((p.x - origin.x) / cell_size), floori((p.z - origin.z) / cell_size))

func cell_center(c: Vector2i) -> Vector3:
	return origin + Vector3((c.x + 0.5) * cell_size, 0.0, (c.y + 0.5) * cell_size)

func set_blocked(c: Vector2i, blocked: bool = true) -> void:
	if in_bounds(c):
		astar.set_point_solid(c, blocked)

func block_rect(r: Rect2i) -> void:
	astar.fill_solid_region(r.intersection(astar.region), true)

func is_blocked(c: Vector2i) -> bool:
	return not in_bounds(c) or astar.is_point_solid(c)

## Nearest walkable cell to `c` (spiral search up to `max_r`); (-1,-1) if none.
func nearest_open(c: Vector2i, max_r: int = 8) -> Vector2i:
	if not is_blocked(c):
		return c
	for r: int in range(1, max_r + 1):
		var best: Vector2i = Vector2i(-1, -1)
		var best_d: int = 1 << 30
		for y: int in range(c.y - r, c.y + r + 1):
			for x: int in range(c.x - r, c.x + r + 1):
				var q: Vector2i = Vector2i(x, y)
				if maxi(absi(x - c.x), absi(y - c.y)) == r and not is_blocked(q):
					var d: int = (q - c).length_squared()
					if d < best_d:
						best_d = d
						best = q
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)

## World-space waypoints from `from` to `to` (end snapped to nearest open cell).
## Empty when unreachable. The first point is the first step, not the start.
func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	var a: Vector2i = nearest_open(cell_at(from))
	var b: Vector2i = nearest_open(cell_at(to))
	if a.x < 0 or b.x < 0:
		return out
	var cells: Array[Vector2i] = astar.get_id_path(a, b)
	if cells.is_empty():
		return out
	for i: int in range(1, cells.size()):
		out.append(cell_center(cells[i]))
	var end: Vector3 = Vector3(to.x, 0.0, to.z) if b == cell_at(to) else cell_center(b)
	if out.is_empty():
		out.append(end)
	else:
		out[out.size() - 1] = end
	return out
