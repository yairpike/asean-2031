class_name SMDomainGrid
extends RefCounted
## Cell flags for land, shallow water, deep water, cliff, and air.
## Amphibious moves emit domain_changed when the occupied flag changes.

signal domain_changed(unit_id: int, from_domain: int, to_domain: int)

enum Domain { LAND, SHALLOW, DEEP, CLIFF, AIR }
enum Loco { GROUND, AMPHIBIOUS, NAVAL, AIR }

var cols: int = 0
var rows: int = 0
var cell_size: float = 2.0
var origin: Vector3 = Vector3.ZERO
var cells: PackedInt32Array = PackedInt32Array()
var _where: Dictionary[int, int] = {}

func _init(p_cols: int = 8, p_rows: int = 8, p_cell: float = 2.0, p_origin: Vector3 = Vector3.ZERO) -> void:
	cols = p_cols
	rows = p_rows
	cell_size = p_cell
	origin = p_origin
	cells.resize(cols * rows)
	cells.fill(Domain.LAND)

func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows

func cell_at(p: Vector3) -> Vector2i:
	return Vector2i(floori((p.x - origin.x) / cell_size), floori((p.z - origin.z) / cell_size))

func cell_center(c: Vector2i) -> Vector3:
	return origin + Vector3((float(c.x) + 0.5) * cell_size, 0.0, (float(c.y) + 0.5) * cell_size)

func _index(c: Vector2i) -> int:
	return c.y * cols + c.x

func set_domain(c: Vector2i, domain: int) -> void:
	if in_bounds(c):
		cells[_index(c)] = domain

func fill_rect(r: Rect2i, domain: int) -> void:
	for y: int in range(r.position.y, r.position.y + r.size.y):
		for x: int in range(r.position.x, r.position.x + r.size.x):
			set_domain(Vector2i(x, y), domain)

func domain_at_cell(c: Vector2i) -> int:
	if not in_bounds(c):
		return Domain.CLIFF
	return cells[_index(c)]

func domain_at(p: Vector3) -> int:
	return domain_at_cell(cell_at(p))

func can_enter(domain: int, loco: int) -> bool:
	if domain == Domain.CLIFF:
		return false
	if loco == Loco.AIR:
		return domain != Domain.CLIFF
	if loco == Loco.GROUND:
		return domain == Domain.LAND
	if loco == Loco.NAVAL:
		return domain == Domain.SHALLOW or domain == Domain.DEEP
	if loco == Loco.AMPHIBIOUS:
		return domain == Domain.LAND or domain == Domain.SHALLOW or domain == Domain.DEEP
	return false

## First placement records the flag without a signal. Later changes emit.
func move_unit(unit_id: int, to: Vector3, loco: int) -> bool:
	var next: int = domain_at(to)
	if not can_enter(next, loco):
		return false
	var prev: int = _where.get(unit_id, -1)
	_where[unit_id] = next
	if prev >= 0 and prev != next:
		domain_changed.emit(unit_id, prev, next)
	return true

func unit_domain(unit_id: int) -> int:
	return _where.get(unit_id, -1)

## Phillips Channel: west land, east land, a deep channel, two shallow crossings.
static func phillips_layout() -> SMDomainGrid:
	var g: SMDomainGrid = SMDomainGrid.new(40, 24, 4.0, Vector3(-80.0, 0.0, -48.0))
	g.fill_rect(Rect2i(15, 0, 10, 24), Domain.DEEP)
	g.fill_rect(Rect2i(15, 4, 10, 3), Domain.SHALLOW)
	g.fill_rect(Rect2i(15, 17, 10, 3), Domain.SHALLOW)
	g.fill_rect(Rect2i(4, 10, 4, 3), Domain.CLIFF)
	g.fill_rect(Rect2i(18, 10, 4, 2), Domain.AIR)
	return g

## Sop Ruak: three land sectors split by a Y of deep water, with a ford on each arm.
static func sop_ruak_layout() -> SMDomainGrid:
	var g: SMDomainGrid = SMDomainGrid.new(36, 36, 4.0, Vector3(-72.0, 0.0, -72.0))
	g.fill_rect(Rect2i(16, 16, 4, 17), Domain.DEEP)
	for i: int in range(1, 15):
		var lx: int = 16 - i
		var ly: int = 16 - i
		g.set_domain(Vector2i(lx, ly), Domain.DEEP)
		g.set_domain(Vector2i(lx + 1, ly), Domain.DEEP)
		g.set_domain(Vector2i(lx, ly + 1), Domain.DEEP)
		g.set_domain(Vector2i(lx + 1, ly + 1), Domain.DEEP)
		var rx: int = 19 + i
		var ry: int = 16 - i
		g.set_domain(Vector2i(rx, ry), Domain.DEEP)
		g.set_domain(Vector2i(rx - 1, ry), Domain.DEEP)
		g.set_domain(Vector2i(rx, ry + 1), Domain.DEEP)
		g.set_domain(Vector2i(rx - 1, ry + 1), Domain.DEEP)
	g.fill_rect(Rect2i(16, 24, 4, 2), Domain.LAND)
	g.fill_rect(Rect2i(9, 9, 4, 4), Domain.LAND)
	g.fill_rect(Rect2i(23, 9, 4, 4), Domain.LAND)
	return g

## Burma Road: highland cliffs with one land road cut through the wall.
static func burma_road_layout() -> SMDomainGrid:
	var g: SMDomainGrid = SMDomainGrid.new(40, 28, 4.0, Vector3(-80.0, 0.0, -56.0))
	g.fill_rect(Rect2i(0, 0, 12, 8), Domain.CLIFF)
	g.fill_rect(Rect2i(28, 20, 12, 8), Domain.CLIFF)
	g.fill_rect(Rect2i(16, 0, 8, 28), Domain.CLIFF)
	g.fill_rect(Rect2i(16, 12, 8, 4), Domain.LAND)
	return g

## Ten Degree Atolls: land islands in deep water, joined by shallow shoals.
static func ten_degree_atolls_layout() -> SMDomainGrid:
	var g: SMDomainGrid = SMDomainGrid.new(36, 36, 4.0, Vector3(-72.0, 0.0, -72.0))
	g.fill_rect(Rect2i(0, 0, 36, 36), Domain.DEEP)
	g.fill_rect(Rect2i(10, 16, 16, 4), Domain.SHALLOW)
	g.fill_rect(Rect2i(16, 8, 4, 8), Domain.SHALLOW)
	g.fill_rect(Rect2i(2, 14, 8, 8), Domain.LAND)
	g.fill_rect(Rect2i(26, 14, 8, 8), Domain.LAND)
	g.fill_rect(Rect2i(14, 2, 8, 6), Domain.LAND)
	return g

## Mekong Delta: two deep canals with a land bridge on each.
static func mekong_delta_layout() -> SMDomainGrid:
	var g: SMDomainGrid = SMDomainGrid.new(40, 32, 4.0, Vector3(-80.0, 0.0, -64.0))
	g.fill_rect(Rect2i(12, 0, 3, 32), Domain.DEEP)
	g.fill_rect(Rect2i(26, 0, 3, 32), Domain.DEEP)
	g.fill_rect(Rect2i(12, 14, 3, 4), Domain.LAND)
	g.fill_rect(Rect2i(26, 14, 3, 4), Domain.LAND)
	return g

## Siege of Chiang Rai: a wider field, a river, two fords, and a siege wall.
static func chiang_rai_layout() -> SMDomainGrid:
	var g: SMDomainGrid = SMDomainGrid.new(56, 40, 4.0, Vector3(-112.0, 0.0, -80.0))
	g.fill_rect(Rect2i(26, 0, 4, 40), Domain.DEEP)
	g.fill_rect(Rect2i(26, 8, 4, 4), Domain.LAND)
	g.fill_rect(Rect2i(26, 28, 4, 4), Domain.LAND)
	g.fill_rect(Rect2i(6, 6, 8, 3), Domain.CLIFF)
	g.fill_rect(Rect2i(42, 30, 8, 3), Domain.CLIFF)
	return g
