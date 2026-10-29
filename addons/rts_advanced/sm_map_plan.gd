class_name SMMapPlan
extends RefCounted
## A skirmish map from res://data/maps/<id>.json. Meshes are not created here.
## Every listed rect, start, node, site and prop is also stamped at its symmetric twin, so both sides get the same map.
## "rot180" turns a cell half a turn about the map centre. "mirror_x" flips it west to east.
## Listed entries are side A (the player's half). Twins are side B. Starts list side A seats first, then side B.

const DIR: String = "res://data/maps/%s.json"

static var _cache: Dictionary = {}
static var _found: Dictionary = {}

var id: String = ""
var cols: int = 0
var rows: int = 0
var cell_size: float = 4.0
var origin: Vector3 = Vector3.ZERO
var symmetry: String = "rot180"
var data: Dictionary = {}
var starts: Array[Vector2i] = []
var plateaus: Array[Rect2i] = []
var roads: Array[Rect2i] = []
var holds: Array[Rect2i] = []
var nodes: Array[Dictionary] = []
var sites: Array[Dictionary] = []
var props: Array[Dictionary] = []
var landmark: Dictionary = {}

static func exists(map_id: String) -> bool:
	if not _found.has(map_id):
		_found[map_id] = map_id != "" and not map_id.contains("/") and FileAccess.file_exists(DIR % map_id)
	return bool(_found[map_id])

static func of(map_id: String) -> SMMapPlan:
	if _cache.has(map_id):
		return _cache[map_id] as SMMapPlan
	if not exists(map_id):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR % map_id))
	if not (parsed is Dictionary):
		return null
	var plan := SMMapPlan.new()
	plan._read(map_id, parsed as Dictionary)
	_cache[map_id] = plan
	return plan

func twin_cell(c: Vector2i) -> Vector2i:
	if symmetry == "mirror_x":
		return Vector2i(cols - 1 - c.x, c.y)
	return Vector2i(cols - 1 - c.x, rows - 1 - c.y)

func twin_rect(r: Rect2i) -> Rect2i:
	if symmetry == "mirror_x":
		return Rect2i(cols - r.position.x - r.size.x, r.position.y, r.size.x, r.size.y)
	return Rect2i(cols - r.position.x - r.size.x, rows - r.position.y - r.size.y, r.size.x, r.size.y)

func grid() -> SMDomainGrid:
	var g := SMDomainGrid.new(cols, rows, cell_size, origin)
	g.cells.fill(_domain(str(data.get("ground", "land"))))
	for raw: Variant in data.get("paint", []):
		var row: Dictionary = raw as Dictionary
		var r: Rect2i = _rect(row.get("rect", []))
		var domain: int = _domain(str(row.get("domain", "land")))
		g.fill_rect(r, domain)
		g.fill_rect(twin_rect(r), domain)
	for r: Rect2i in holds:
		g.hold(r)
	return g

func cell_center(c: Vector2i) -> Vector3:
	return origin + Vector3((float(c.x) + 0.5) * cell_size, 0.0, (float(c.y) + 0.5) * cell_size)

func rect_center(r: Rect2i) -> Vector3:
	return origin + Vector3((float(r.position.x) + float(r.size.x) * 0.5) * cell_size, 0.0, (float(r.position.y) + float(r.size.y) * 0.5) * cell_size)

## Seat 0 is the player. Seats alternate sides only through the starts list order.
func start(seat: int) -> Vector2i:
	if seat < 0 or seat >= starts.size():
		return Vector2i(cols / 2, rows / 2)
	return starts[seat]

## Six spawn cells beside a start, on the side facing the map centre.
func spawn_cells(seat: int, count: int = 6) -> Array[Vector2i]:
	var home: Vector2i = start(seat)
	var toward: Vector2 = Vector2(float(cols) * 0.5 - float(home.x), float(rows) * 0.5 - float(home.y))
	var step: Vector2i = Vector2i(0, -1 if toward.y < 0.0 else 1)
	var side: Vector2i = Vector2i(1, 0)
	if absf(toward.x) > absf(toward.y):
		step = Vector2i(-1 if toward.x < 0.0 else 1, 0)
		side = Vector2i(0, 1)
	var out: Array[Vector2i] = []
	for i: int in count:
		var lane: int = i % 3
		var row: int = i / 3
		out.append(home + step * (4 + row * 2) + side * ((lane - 1) * 2))
	return out

func node_id(stem: String, seat_side: int) -> StringName:
	return StringName("%s_%s" % [stem, "a" if seat_side == 0 else "b"])

func bot(key: String, fallback: String = "") -> String:
	return str((data.get("bot", {}) as Dictionary).get(key, fallback))

func _read(map_id: String, d: Dictionary) -> void:
	id = map_id
	data = d
	cols = int(d.get("cols", 48))
	rows = int(d.get("rows", 48))
	cell_size = float(d.get("cell", 4.0))
	symmetry = str(d.get("symmetry", "rot180"))
	origin = Vector3(-float(cols) * cell_size * 0.5, 0.0, -float(rows) * cell_size * 0.5)
	var side_b: Array[Vector2i] = []
	for raw: Variant in d.get("starts", []):
		var c: Vector2i = _cell(raw)
		starts.append(c)
		side_b.append(twin_cell(c))
	starts.append_array(side_b)
	for raw: Variant in d.get("plateaus", []):
		var r: Rect2i = _rect(raw)
		plateaus.append(r)
		plateaus.append(twin_rect(r))
	for raw: Variant in d.get("roads", []):
		var r: Rect2i = _rect(raw)
		roads.append(r)
		roads.append(twin_rect(r))
	for raw: Variant in d.get("holds", []):
		var r: Rect2i = _rect(raw)
		holds.append(r)
		if twin_rect(r) != r:
			holds.append(twin_rect(r))
	for raw: Variant in d.get("nodes", []):
		var row: Dictionary = raw as Dictionary
		for s: int in 2:
			var c: Vector2i = _cell(row.get("cell", []))
			nodes.append({
				"id": node_id(str(row.get("id", "node")), s),
				"kind": StringName(str(row.get("kind", "slag"))),
				"cell": c if s == 0 else twin_cell(c),
				"rate": int(row.get("rate", 12)),
				"water": bool(row.get("water", false)),
				"side": s,
			})
	for raw: Variant in d.get("sites", []):
		var row: Dictionary = raw as Dictionary
		for s: int in 2:
			var c: Vector2i = _cell(row.get("cell", []))
			sites.append({
				"id": node_id(str(row.get("id", "site")), s),
				"kind": StringName(str(row.get("kind", "radar"))),
				"cell": c if s == 0 else twin_cell(c),
				"side": s,
			})
	for raw: Variant in d.get("props", []):
		var row: Dictionary = raw as Dictionary
		var c: Vector2i = _cell(row.get("cell", []))
		var prop_id: String = str(row.get("id", ""))
		props.append({"id": prop_id, "cell": c, "yaw": float(row.get("yaw", 0.0))})
		props.append({"id": prop_id, "cell": twin_cell(c), "yaw": float(row.get("yaw", 0.0)) + (180.0 if symmetry == "rot180" else 0.0)})
	var mark: Variant = d.get("landmark", {})
	if mark is Dictionary and not (mark as Dictionary).is_empty():
		landmark = {"id": str((mark as Dictionary).get("id", "")), "rect": _rect((mark as Dictionary).get("rect", []))}

func _cell(raw: Variant) -> Vector2i:
	if raw is Array and (raw as Array).size() >= 2:
		return Vector2i(int((raw as Array)[0]), int((raw as Array)[1]))
	return Vector2i.ZERO

func _rect(raw: Variant) -> Rect2i:
	if raw is Array and (raw as Array).size() >= 4:
		var a: Array = raw as Array
		return Rect2i(int(a[0]), int(a[1]), int(a[2]), int(a[3]))
	return Rect2i()

static func goods_kind(name: StringName) -> StringName:
	if name == &"rare":
		return SMCommodityNet.KIND_RARE
	if name == &"ruby":
		return SMCommodityNet.KIND_RUBY
	if name == &"jade":
		return SMCommodityNet.KIND_JADE
	if name == &"bullion":
		return SMCommodityNet.KIND_BULLION
	return SMCommodityNet.KIND_SLAG

static func site_kind(name: StringName) -> StringName:
	if name == &"cyber":
		return SMTechNet.CYBER
	if name == &"bazaar":
		return SMTechNet.BAZAAR
	if name == &"clinic":
		return SMTechNet.CLINIC
	if name == &"salvage":
		return SMTechNet.SALVAGE
	if name == &"derrick":
		return SMTechNet.DERRICK
	if name == &"bridge":
		return SMTechNet.BRIDGE
	if name == &"garrison":
		return SMTechNet.GARRISON
	return SMTechNet.RADAR

## Cells kept free of scattered scenery: plateaus, roads, holds and a ring round every start, node and site.
func clear_of_props(c: Vector2i) -> bool:
	for r: Rect2i in plateaus:
		if r.grow(1).has_point(c):
			return false
	for r: Rect2i in roads:
		if r.grow(1).has_point(c):
			return false
	for r: Rect2i in holds:
		if r.grow(1).has_point(c):
			return false
	var spots: Array[Vector2i] = starts.duplicate()
	for row: Dictionary in nodes:
		spots.append(row["cell"] as Vector2i)
	for row: Dictionary in sites:
		spots.append(row["cell"] as Vector2i)
	for spot: Vector2i in spots:
		if absi(spot.x - c.x) <= 3 and absi(spot.y - c.y) <= 3:
			return false
	return true

## The same roll for a cell and its twin, so scatter is symmetric too.
func canon(c: Vector2i) -> Vector2i:
	var t: Vector2i = twin_cell(c)
	if t.y < c.y or (t.y == c.y and t.x < c.x):
		return t
	return c

static func _domain(name: String) -> int:
	if name == "shallow":
		return SMDomainGrid.Domain.SHALLOW
	if name == "deep":
		return SMDomainGrid.Domain.DEEP
	if name == "cliff":
		return SMDomainGrid.Domain.CLIFF
	if name == "air":
		return SMDomainGrid.Domain.AIR
	return SMDomainGrid.Domain.LAND
