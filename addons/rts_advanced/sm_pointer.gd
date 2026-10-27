class_name SMPointer
extends RefCounted
## Click controls for a match: left click and drag select friendlies,
## right click ground to move, right click an enemy to attack.

const PLAYER: int = 0
const ENEMY: int = 1
const PICK_PX: float = 28.0
const ATTACK_M: float = 2.2
const BUILDING_SIZE: Vector3 = Vector3(2.2, 4.6, 2.2)
const GTFC_KINDS: Array[StringName] = [&"militia", &"slag_hauler", &"ruby_lancer", &"amber_tank", &"monsoon_tube", &"channel_skiff"]
const MVD_KINDS: Array[StringName] = [&"clearance_trooper", &"hub_drone", &"charcoal_apc", &"cyan_ifv", &"relay_van", &"river_drone"]
const NMRF_KINDS: Array[StringName] = [&"river_rifle", &"sampan", &"emerald_gunboat", &"mangrove_tube", &"packer", &"jade_skiff"]

var teams: RTSTeams = RTSTeams.new()
var faction_id: String = "gtfc"
var primary_color: Color = Color(0.72, 0.12, 0.18)
var accent_color: Color = Color(0.88, 0.62, 0.12)
var nav: RTSGridNav
var nav_ground: RTSGridNav
var nav_amphib: RTSGridNav
var nav_naval: RTSGridNav
var nav_air: RTSGridNav
var domain: SMDomainGrid
var selection: RTSSelection = RTSSelection.new()
var units: Array[RTSUnit] = []
var box: RTSSelectionBox
var cam: RTSCamera
var host: Node3D
var ew: SMEwField
var tech: SMTechNet
var on_bridge_ruined: Callable
var on_cue: Callable
var on_line: Callable
var on_bark: Callable
var marks: Array[Node3D] = []
var group_note: String = ""
var group_note_t: float = 0.0
var beacon_at: Vector3 = Vector3.INF
var line_formation: bool = false
var last_pick: int = 0
var last_pick_ms: int = 0
var hover_at: Vector2 = Vector2.INF
const FX = preload("res://addons/rts_advanced/sm_fx.gd")
const Cast = preload("res://addons/rts_advanced/sm_cast.gd")
const Forms = preload("res://addons/rts_advanced/sm_forms.gd")
const F_COOLDOWN: float = 3.0
const BEAM_TIME: float = 1.5

func bind(p_host: Node3D, p_cam: RTSCamera) -> void:
	host = p_host
	cam = p_cam
	teams.add_team(PLAYER, Color(0.72, 0.12, 0.18))
	teams.add_team(ENEMY, Color(0.12, 0.62, 0.7))
	teams.set_relation(PLAYER, ENEMY, RTSTeams.Relation.ENEMY)
	selection.team = PLAYER
	FX.dress(host)

func bind_faction(p_host: Node3D, p_cam: RTSCamera, faction: String) -> void:
	bind(p_host, p_cam)
	faction_id = faction
	var data: Dictionary = SMCatalog.faction(faction)
	var colors: Dictionary = {}
	var raw_colors: Variant = data.get("colors", {})
	if raw_colors is Dictionary:
		colors = raw_colors
	primary_color = SMCatalog.hex_color(str(colors.get("primary_hex", "#B81E2D")))
	accent_color = SMCatalog.hex_color(str(colors.get("accent_hex", "#E0A106")))
	teams.add_team(PLAYER, primary_color)
	if faction == "mvd":
		teams.add_team(ENEMY, Color(0.72, 0.12, 0.18))
	else:
		teams.add_team(ENEMY, Color(0.12, 0.62, 0.7))

func bind_tech(net: SMTechNet, ruined: Callable) -> void:
	tech = net
	on_bridge_ruined = ruined

func use_domain(grid: SMDomainGrid) -> void:
	domain = grid
	nav_ground = _nav_for_loco(grid, SMDomainGrid.Loco.GROUND)
	nav_amphib = _nav_for_loco(grid, SMDomainGrid.Loco.AMPHIBIOUS)
	nav_naval = _nav_for_loco(grid, SMDomainGrid.Loco.NAVAL)
	nav_air = _nav_for_loco(grid, SMDomainGrid.Loco.AIR)
	nav = nav_amphib

func _nav_for_loco(grid: SMDomainGrid, loco: int) -> RTSGridNav:
	var built: RTSGridNav = RTSGridNav.new(grid.cols, grid.rows, grid.cell_size, grid.origin)
	for y: int in range(grid.rows):
		for x: int in range(grid.cols):
			if not grid.can_enter(grid.domain_at_cell(Vector2i(x, y)), loco):
				built.set_blocked(Vector2i(x, y), true)
	return built

func nav_for_unit(u: RTSUnit) -> RTSGridNav:
	var loco: String = "ground"
	if is_instance_valid(u):
		loco = str(u.get_meta("locomotion", "ground"))
	if loco == "naval" and nav_naval != null:
		return nav_naval
	if loco == "amphibious" and nav_amphib != null:
		return nav_amphib
	if loco == "air" and nav_air != null:
		return nav_air
	if nav_ground != null:
		return nav_ground
	return nav

func loco_id(u: RTSUnit) -> int:
	var loco: String = "ground"
	if is_instance_valid(u):
		loco = str(u.get_meta("locomotion", "ground"))
	if loco == "amphibious":
		return SMDomainGrid.Loco.AMPHIBIOUS
	if loco == "naval":
		return SMDomainGrid.Loco.NAVAL
	if loco == "air":
		return SMDomainGrid.Loco.AIR
	return SMDomainGrid.Loco.GROUND

func use_open(cols: int, rows: int, cell: float, origin: Vector3) -> void:
	nav = RTSGridNav.new(cols, rows, cell, origin)

func attach_box(layer: CanvasLayer) -> void:
	box = RTSSelectionBox.new()
	box.name = "SelectionBox"
	box.count_provider = Callable(self, "preview_count")
	layer.add_child(box)

func preview_count(rect: Rect2) -> int:
	return selection.preview_count(rect, units, Callable(self, "project_point"))

func project_point(p: Vector3) -> Vector2:
	if cam == null:
		return Vector2(p.x, p.z)
	return cam.unproject_position(p)

func spawn(team: int, at: Vector3, kind: StringName) -> RTSUnit:
	var u: RTSUnit = RTSUnit.new()
	u.team = team
	u.unit_type = kind
	u.speed = 8.0
	u.max_hp = 80.0
	u.attack_damage = 12.0
	u.attack_range = 8.0
	u.attack_interval = 0.8
	u.position = at
	_apply_catalog(u, kind)
	var row: Dictionary = _unit_row(kind)
	var role: String = "infantry" if row.is_empty() else str(row.get("role", ""))
	var loco: String = "ground" if row.is_empty() else str(row.get("locomotion", "ground"))
	var body: MeshInstance3D = Forms.dress_unit(str(kind), role, loco, _body_color(team, kind))
	u.add_child(body)
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.name = "Ring"
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.82
	torus.outer_radius = 1.05
	ring.mesh = torus
	ring.position = Vector3(0, 0.08, 0)
	var ring_mat: StandardMaterial3D = StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.95, 0.85, 0.35)
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = ring_mat
	ring.visible = false
	u.add_child(ring)
	var tag: Label3D = Label3D.new()
	tag.name = "NameTag"
	tag.text = unit_label(team, kind)
	tag.font_size = 32
	tag.pixel_size = 0.008
	tag.outline_size = 8
	tag.outline_modulate = Color(0.02, 0.02, 0.03)
	tag.position = Vector3(0, 3.35, 0)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = Color(0.97, 0.94, 0.84)
	tag.visible = false
	u.add_child(tag)
	u.shot_filter = Callable(self, "filter_shot")
	u.fired.connect(_on_shot)
	_add_vitals(u, team)
	host.add_child(u)
	u.set_meta("seen_hp", u.hp)
	units.append(u)
	return u

func _add_vitals(u: RTSUnit, team: int) -> void:
	var bar: MeshInstance3D = MeshInstance3D.new()
	bar.name = "HealthBar"
	var slab: BoxMesh = BoxMesh.new()
	slab.size = Vector3(2.0, 0.16, 0.1)
	bar.mesh = slab
	bar.position = Vector3(0.0, 2.9, 0.0)
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ink: StandardMaterial3D = StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.albedo_color = Color(0.35, 0.82, 0.38) if team == PLAYER else Color(0.86, 0.24, 0.2)
	bar.material_override = ink
	u.add_child(bar)
	var muzzle: MeshInstance3D = MeshInstance3D.new()
	muzzle.name = "Muzzle"
	var flash: BoxMesh = BoxMesh.new()
	flash.size = Vector3(0.22, 0.22, 0.5)
	muzzle.mesh = flash
	muzzle.position = Forms.muzzle_pos(str(u.get_node("Body").get_meta("form", "truck")))
	muzzle.visible = false
	muzzle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var glow: StandardMaterial3D = StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.82, 0.35)
	muzzle.material_override = glow
	u.add_child(muzzle)
	var reach: MeshInstance3D = MeshInstance3D.new()
	reach.name = "RangeRing"
	var band: TorusMesh = TorusMesh.new()
	band.inner_radius = 0.92
	band.outer_radius = 1.0
	reach.mesh = band
	reach.position = Vector3(0.0, 0.06, 0.0)
	reach.visible = false
	reach.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var reach_ink: StandardMaterial3D = StandardMaterial3D.new()
	reach_ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	reach_ink.albedo_color = Color(0.95, 0.55, 0.22, 0.85)
	reach_ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	reach.material_override = reach_ink
	u.add_child(reach)

func _on_shot(unit: RTSUnit, _target: RTSUnit) -> void:
	if not is_instance_valid(unit):
		return
	unit.set_meta("flash_t", 0.14)
	var muzzle: MeshInstance3D = unit.get_node_or_null("Muzzle") as MeshInstance3D
	if muzzle != null:
		muzzle.visible = true
	_cue("attack")

func unit_label(team: int, kind: StringName) -> String:
	if team != PLAYER:
		return "Enemy"
	var row: Dictionary = _unit_row(kind)
	if row.is_empty():
		return faction_id.to_upper()
	return str(row.get("display_name", faction_id.to_upper()))

func name_of(u: RTSUnit) -> String:
	if not is_instance_valid(u):
		return ""
	var tag: Label3D = u.get_node_or_null("NameTag") as Label3D
	if tag == null:
		return ""
	return tag.text

func _apply_catalog(u: RTSUnit, kind: StringName) -> void:
	var unit: Dictionary = _unit_row(kind)
	if unit.is_empty():
		return
	u.max_hp = float(unit.get("hp", u.max_hp))
	u.hp = u.max_hp
	u.speed = float(unit.get("speed", u.speed))
	u.attack_damage = float(unit.get("weapon_damage", u.attack_damage))
	u.set_meta("weapon", str(unit.get("weapon", "")))
	u.set_meta("secondary", str(unit.get("secondary", "")))
	u.set_meta("guidance", str(unit.get("guidance", "none")))
	u.set_meta("locomotion", str(unit.get("locomotion", "ground")))
	u.set_meta("role", str(unit.get("role", "")))
	u.set_meta("tags", _tag_list(unit))
	u.set_meta("ability", str(unit.get("ability", "")))
	u.set_meta("f_stat", str(unit.get("f_stat", "damage")))

func _body_color(team: int, kind: StringName) -> Color:
	if team != PLAYER:
		return teams.color_of(team)
	if faction_id != "gtfc":
		return accent_color if _accent_kind(kind) else primary_color
	if kind == &"slag_hauler" or kind == &"amber_tank" or kind == &"channel_skiff":
		return Color(0.88, 0.62, 0.12)
	return Color(0.72, 0.12, 0.18)

func _accent_kind(kind: StringName) -> bool:
	var units: Array[Dictionary] = SMCatalog.units_of(SMCatalog.faction(faction_id))
	for i: int in units.size():
		if str(units[i].get("id", "")) == str(kind):
			return i % 2 == 1
	return false

static func building_at(at: Vector3) -> Vector3:
	return at + Vector3(0.0, BUILDING_SIZE.y * 0.5, 0.0)

func category_of(kind: StringName) -> String:
	var unit: Dictionary = _unit_row(kind)
	if unit.is_empty():
		return "infantry"
	var role: String = str(unit.get("role", ""))
	var loco: String = str(unit.get("locomotion", ""))
	if role == "infantry" or _tagged(unit, "infantry"):
		return "infantry"
	if role == "air" or role == "drone" or loco == "air" or _tagged(unit, "air"):
		return "aircraft"
	if role == "boat" or role == "amphibious" or loco == "naval" or _tagged(unit, "naval"):
		return "boat"
	return "vehicle"

func _unit_row(kind: StringName) -> Dictionary:
	var lists: Array[String] = [faction_id]
	if faction_id != "black_market":
		lists.append("black_market")
	for faction: String in lists:
		var units: Array[Dictionary] = SMCatalog.units_of(SMCatalog.faction(faction))
		for unit: Dictionary in units:
			if str(unit.get("id", "")) == str(kind):
				return unit
	return {}

func _tagged(unit: Dictionary, tag: String) -> bool:
	var raw: Variant = unit.get("tags", [])
	if not (raw is Array):
		return false
	for item: Variant in raw:
		if str(item) == tag:
			return true
	return false

func units_of(team: int) -> Array[RTSUnit]:
	var out: Array[RTSUnit] = []
	for u: RTSUnit in units:
		if is_instance_valid(u) and u.is_alive() and u.team == team:
			out.append(u)
	return out

func count_team(team: int) -> int:
	return units_of(team).size()

func select_click(screen: Vector2, project_fn: Callable, add: bool = false, toggle: bool = false) -> RTSUnit:
	var picked: RTSUnit = selection.select_at(screen, units, project_fn, add, toggle, PICK_PX)
	if picked != null and not add and not toggle and _fresh_double(picked):
		select_kind(picked.unit_type)
	elif picked != null and picked.selected:
		_cue("select")
		announce(picked, "select")
	return picked

func select_drag(rect: Rect2, project_fn: Callable, add: bool = false) -> int:
	return selection.select_box(rect, units, project_fn, add)

func select_kind(kind: StringName) -> int:
	var found: Array[RTSUnit] = []
	for u: RTSUnit in units_of(PLAYER):
		if u.unit_type == kind:
			found.append(u)
	select_only(found)
	if not found.is_empty():
		group_note = "All %s" % name_of(found[0])
		group_note_t = 1.4
	return found.size()

func select_same() -> int:
	if selection.count() <= 0:
		return select_company()
	return select_kind(selection.units[0].unit_type)

func select_company() -> int:
	select_only(units_of(PLAYER))
	group_note = "Company"
	group_note_t = 1.2
	return selection.count()

func toggle_line() -> bool:
	line_formation = not line_formation
	group_note = "Line" if line_formation else "Box"
	group_note_t = 1.4
	return line_formation

func _fresh_double(u: RTSUnit) -> bool:
	var now: int = Time.get_ticks_msec()
	var id: int = u.get_instance_id()
	var hit: bool = last_pick == id and now - last_pick_ms < 320
	last_pick = id
	last_pick_ms = now
	return hit

## Right click. Returns "attack", "move", or "none".
func command_at(ground: Vector3, screen: Vector2, project_fn: Callable, queue: bool = false) -> StringName:
	if selection.count() <= 0:
		return &"none"
	var foe: RTSUnit = enemy_near(screen, ground, project_fn)
	if foe != null:
		var hit: int = 0
		for u: RTSUnit in selection.units:
			if is_instance_valid(u) and u.is_alive():
				var one: Array[RTSUnit] = [u]
				hit += RTSOrders.attack(one, foe, nav_for_unit(u), teams)
		if hit > 0:
			_drop_hunt(selection.units)
			_clear_bridges(selection.units)
			_cue("attack")
			announce(_first_player(), "attack")
			_mark(foe.global_position, "attack")
		return &"attack" if hit > 0 else &"none"
	if tech != null and ground != Vector3.INF:
		var span_id: StringName = tech.nearest_bridge(ground, 6.0)
		if span_id != &"":
			return _order_bridge(span_id)
	if ground == Vector3.INF:
		return &"none"
	var sent: int = _send(ground, false, queue)
	if sent > 0:
		if queue:
			group_note = "Waypoint"
			group_note_t = 1.2
		_cue("move")
		announce(_first_player(), "move")
		_mark(ground, "move")
	return &"move" if sent > 0 else &"none"

## Walks the selection to formation slots. Hunt keeps them shooting on the way.
func _send(ground: Vector3, hunt: bool, queue: bool = false) -> int:
	var live: Array[RTSUnit] = []
	for u: RTSUnit in selection.units:
		if is_instance_valid(u) and u.is_alive():
			live.append(u)
	if live.is_empty():
		return 0
	var center: Vector3 = Vector3.ZERO
	var positions: Array[Vector3] = []
	for u: RTSUnit in live:
		center += u.global_position
		positions.append(u.global_position)
	center /= float(live.size())
	var slots: Array[Vector3] = RTSFormation.line(center, ground, live.size(), 2.0) if line_formation else RTSFormation.box(center, ground, live.size(), 2.0)
	var pick: Array[int] = RTSFormation.assign(positions, slots)
	var sent: int = 0
	for i: int in live.size():
		var mover: RTSUnit = live[i]
		var slot: Vector3 = slots[pick[i]]
		var route: PackedVector3Array = nav_for_unit(mover).find_path(mover.global_position, slot)
		if route.is_empty():
			continue
		if queue and not mover.path.is_empty():
			var tail: Vector3 = mover.path[mover.path.size() - 1]
			var extra: PackedVector3Array = nav_for_unit(mover).find_path(tail, slot)
			if extra.is_empty():
				continue
			mover.path.append_array(extra)
			sent += 1
			continue
		mover.attack_target = null
		mover.set_meta("bridge_id", "")
		mover.set_meta("hunt", hunt)
		if hunt:
			mover.set_meta("hunt_goal", ground)
		mover.set_path(route)
		sent += 1
	return sent

func _drop_hunt(list: Array[RTSUnit]) -> void:
	for u: RTSUnit in list:
		if is_instance_valid(u):
			u.set_meta("hunt", false)

func _clear_bridges(list: Array[RTSUnit]) -> void:
	for u: RTSUnit in list:
		if is_instance_valid(u):
			u.set_meta("bridge_id", "")

func _order_bridge(id: StringName) -> StringName:
	var at: Vector3 = tech.site_pos(id)
	var hit: int = 0
	for u: RTSUnit in selection.units:
		if not is_instance_valid(u) or not u.is_alive():
			continue
		u.attack_target = null
		u.set_meta("hunt", false)
		u.set_meta("bridge_id", str(id))
		u.set_meta("bridge_cool", 0.0)
		var route: PackedVector3Array = nav_for_unit(u).find_path(u.global_position, at)
		if not route.is_empty():
			u.set_path(route)
		hit += 1
	if hit <= 0:
		return &"none"
	_cue("attack")
	announce(_first_player(), "attack")
	_mark(at, "attack")
	return &"attack"

func _press_bridge(u: RTSUnit, delta: float) -> void:
	var raw: String = str(u.get_meta("bridge_id", ""))
	if raw == "" or tech == null:
		return
	var id: StringName = StringName(raw)
	if not tech.bridge_alive(id):
		u.set_meta("bridge_id", "")
		return
	var at: Vector3 = tech.site_pos(id)
	var dist: float = Vector2(u.global_position.x, u.global_position.z).distance_to(Vector2(at.x, at.z))
	if dist > u.attack_range + 0.4:
		return
	u.path = PackedVector3Array()
	u.attack_target = null
	var cool: float = float(u.get_meta("bridge_cool", 0.0)) - delta
	if cool > 0.0:
		u.set_meta("bridge_cool", cool)
		return
	u.set_meta("bridge_cool", u.attack_interval)
	var dealt: float = u.attack_damage * u.damage_mult
	if tech.harm_bridge(id, dealt) and on_bridge_ruined.is_valid():
		on_bridge_ruined.call(id)

## Ctrl stores the current selection in 1-9. A plain number recalls it.
func bind_group(index: int, store: bool) -> int:
	if index < 1 or index > 9:
		return 0
	if store:
		selection.save_group(index)
		group_note = "Group %d stored" % index
		group_note_t = 1.8
		return selection.count()
	var n: int = selection.recall_group(index)
	group_note = ("Group %d" % index) if n > 0 else ("Group %d empty" % index)
	group_note_t = 1.8
	return n

func selection_focus() -> Vector3:
	if selection.count() <= 0:
		return Vector3.INF
	var sum: Vector3 = Vector3.ZERO
	var n: int = 0
	for u: RTSUnit in selection.units:
		if is_instance_valid(u) and u.is_alive():
			sum += u.global_position
			n += 1
	if n <= 0:
		return Vector3.INF
	return sum / float(n)

func halt_selected() -> void:
	var live: Array[RTSUnit] = []
	for u: RTSUnit in selection.units:
		if is_instance_valid(u) and u.is_alive():
			live.append(u)
	RTSOrders.stop(live)
	_drop_hunt(live)
	_clear_bridges(live)
	group_note = "Halt"
	group_note_t = 1.4

## Move toward `at` and shoot anything that enters range along the way.
func attack_move_at(at: Vector3) -> int:
	if at == Vector3.INF:
		return 0
	var sent: int = _send(at, true)
	if sent <= 0:
		return 0
	_mark(at, "attack")
	group_note = "Attack-move"
	group_note_t = 1.6
	_cue("attack")
	announce(_first_player(), "attack")
	return sent

func enemy_anchor() -> Vector3:
	var sum: Vector3 = Vector3.ZERO
	var n: int = 0
	for u: RTSUnit in units:
		if is_instance_valid(u) and u.is_alive() and teams.are_enemies(PLAYER, u.team):
			sum += u.global_position
			n += 1
	if n <= 0:
		return Vector3.INF
	return sum / float(n)

func place_beacon(at: Vector3) -> void:
	beacon_at = at
	if host == null:
		return
	var pole: MeshInstance3D = host.get_node_or_null("GoalBeacon") as MeshInstance3D
	if at == Vector3.INF:
		if pole != null:
			pole.visible = false
		return
	if pole == null:
		pole = MeshInstance3D.new()
		pole.name = "GoalBeacon"
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(0.45, 7.0, 0.45)
		pole.mesh = box
		pole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var ink: StandardMaterial3D = StandardMaterial3D.new()
		ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ink.albedo_color = Color(0.98, 0.82, 0.28)
		pole.material_override = ink
		host.add_child(pole)
	var pulse: float = 1.0 + 0.12 * sin(float(Time.get_ticks_msec()) * 0.005)
	pole.scale = Vector3(pulse, 1.0, pulse)
	pole.position = Vector3(at.x, 3.6, at.z)
	pole.visible = true

func place_rally(at: Vector3) -> void:
	if host == null or at == Vector3.INF:
		return
	var flag: MeshInstance3D = host.get_node_or_null("RallyFlag") as MeshInstance3D
	if flag == null:
		flag = MeshInstance3D.new()
		flag.name = "RallyFlag"
		var pole: BoxMesh = BoxMesh.new()
		pole.size = Vector3(0.08, 1.5, 0.08)
		flag.mesh = pole
		flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var ink: StandardMaterial3D = StandardMaterial3D.new()
		ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ink.albedo_color = Color(0.25, 0.85, 0.45)
		flag.material_override = ink
		var cloth: MeshInstance3D = MeshInstance3D.new()
		cloth.name = "RallyCloth"
		var sheet: BoxMesh = BoxMesh.new()
		sheet.size = Vector3(0.7, 0.38, 0.06)
		cloth.mesh = sheet
		cloth.position = Vector3(0.35, 0.5, 0.0)
		cloth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cloth.material_override = ink
		flag.add_child(cloth)
		host.add_child(flag)
	flag.position = Vector3(at.x, 0.8, at.z)
	flag.visible = true

func _cue(kind: String) -> void:
	if on_cue.is_valid():
		on_cue.call(kind)

func enemy_near(screen: Vector2, ground: Vector3, project_fn: Callable) -> RTSUnit:
	var best: RTSUnit = null
	var best_d: float = PICK_PX
	for u: RTSUnit in units:
		if is_instance_valid(u) and u.is_alive() and teams.are_enemies(PLAYER, u.team):
			var d: float = (project_fn.call(u.global_position) as Vector2).distance_to(screen)
			if d <= best_d:
				best_d = d
				best = u
	if best != null:
		return best
	if ground == Vector3.INF:
		return null
	var flat: Vector2 = Vector2(ground.x, ground.z)
	for u: RTSUnit in units:
		if is_instance_valid(u) and u.is_alive() and teams.are_enemies(PLAYER, u.team):
			if Vector2(u.global_position.x, u.global_position.z).distance_to(flat) <= ATTACK_M:
				return u
	return null

## Kokang secondary: selected friendlies (or the whole squad) strike the nearest enemy.
func secondary_strike() -> int:
	var squad: Array[RTSUnit] = []
	if selection.count() <= 0:
		squad = units_of(PLAYER)
	else:
		for u: RTSUnit in selection.units:
			if is_instance_valid(u) and u.is_alive():
				squad.append(u)
	var n: int = 0
	for u: RTSUnit in squad:
		if not is_instance_valid(u) or not u.is_alive():
			continue
		var foe: RTSUnit = nearest_enemy(u.global_position, 24.0)
		if foe == null:
			continue
		foe.take_damage(u.attack_damage)
		u.attack_target = foe
		n += 1
	if n > 0 and not squad.is_empty():
		announce(squad[0], "ability")
	return n

func select_only(list: Array[RTSUnit]) -> void:
	selection.clear()
	for u: RTSUnit in list:
		if is_instance_valid(u) and u.is_alive() and u.team == PLAYER:
			if not selection.units.has(u):
				selection.units.append(u)
				u.selected = true
	selection.changed.emit(selection.units)

func aim_from_camera(camera: RTSCamera, screen: Vector2) -> Vector3:
	if camera != null:
		var ground: Vector3 = camera.ground_at(screen)
		if ground != Vector3.INF:
			return ground
	if selection.count() > 0:
		return selection.units[0].global_position
	return Vector3.ZERO

## Selected-unit F. Toggles the whole group, smart-casts only the closest ready unit,
## and starts a beam on the closest ready tube. Returns which kinds fired.
func cast_f(aim: Vector3) -> String:
	var toggled: int = 0
	var smart: RTSUnit = null
	var smart_d: float = 1.0e20
	var beam: RTSUnit = null
	var beam_d: float = 1.0e20
	for u: RTSUnit in selection.units:
		if not is_instance_valid(u) or not u.is_alive() or bool(u.get_meta("frozen", false)):
			continue
		var kind: String = str(u.get_meta("secondary", ""))
		var flat: float = Vector2(u.global_position.x, u.global_position.z).distance_to(Vector2(aim.x, aim.z))
		if kind == "group_toggle":
			var on: bool = not bool(u.get_meta("toggled", false))
			u.set_meta("toggled", on)
			var guidance: String = str(u.get_meta("guidance", "none"))
			if guidance == "fiber":
				u.set_meta("fiber_on", on)
			elif guidance == "hop":
				u.set_meta("hop_on", on)
			apply_named_f(u)
			toggled += 1
		elif kind == "smart_cast" and float(u.get_meta("f_ready", 0.0)) <= 0.0 and flat < smart_d:
			smart_d = flat
			smart = u
		elif kind == "channeled_beam" and not bool(u.get_meta("channeling", false)) and float(u.get_meta("f_ready", 0.0)) <= 0.0 and flat < beam_d:
			beam_d = flat
			beam = u
	var fired: String = ""
	if toggled > 0:
		fired = "toggle"
	if smart != null:
		smart.set_meta("fired_f", int(smart.get_meta("fired_f", 0)) + 1)
		smart.set_meta("f_ready", F_COOLDOWN)
		apply_named_f(smart)
		var strike: RTSUnit = nearest_enemy(aim, 240.0)
		if strike != null:
			strike.take_damage(smart.attack_damage * smart.damage_mult)
		fired = "smart" if fired == "" else fired + "+smart"
	if beam != null:
		beam.set_meta("channeling", true)
		beam.set_meta("channel_t", BEAM_TIME)
		beam.set_meta("f_ready", F_COOLDOWN)
		apply_named_f(beam)
		fired = "beam" if fired == "" else fired + "+beam"
	if fired != "":
		announce(_first_player(), "ability")
	return fired

func apply_named_f(u: RTSUnit) -> bool:
	if not is_instance_valid(u):
		return false
	Cast.apply(self, u)
	var stat: String = str(u.get_meta("f_stat", "damage"))
	if stat == "speed":
		u.speed_scale += 0.4
	elif stat == "hp":
		u.max_hp += 8.0
		u.hp += 8.0
	elif stat == "incoming":
		u.incoming_mult = maxf(0.2, u.incoming_mult - 0.2)
	else:
		u.damage_mult += 0.25
	u.set_meta("f_stat_changed", stat)
	if str(u.get_meta("f_effect", "")) == "":
		u.set_meta("f_effect", str(u.get_meta("ability", "")))
	return true

func apply_status(u: RTSUnit, status: String, duration: float) -> void:
	if not is_instance_valid(u):
		return
	var body: MeshInstance3D = u.get_node_or_null("Body") as MeshInstance3D
	if body != null:
		body.scale = Vector3.ONE
	Forms.paint_status(body, null)
	u.speed_scale = 1.0
	u.incoming_mult = 1.0
	u.set_meta("frozen", false)
	u.set_meta("status", status)
	u.set_meta("status_t", duration)
	if status == "frozen":
		u.set_meta("frozen", true)
		u.speed_scale = 0.0
		u.stop()
		Forms.paint_status(body, FX.ice_material())
	elif status == "shrunk":
		u.speed_scale = 2.0
		u.incoming_mult = 0.5
		if body != null:
			body.scale = Vector3(0.5, 0.5, 0.5)
	elif status == "black_hole":
		u.incoming_mult = 0.2

func filter_shot(u: RTSUnit, _target: RTSUnit, amount: float) -> float:
	if ew == null or not is_instance_valid(u):
		return amount
	var guidance: int = SMEwField.guidance_of(str(u.get_meta("guidance", "none")))
	var scale: float = ew.accuracy(u.global_position, guidance, bool(u.get_meta("fiber_on", false)), bool(u.get_meta("hop_on", false)))
	return amount * scale

func _keep_domain(u: RTSUnit, before: Vector3) -> void:
	if domain == null or not is_instance_valid(u):
		return
	var loco: int = loco_id(u)
	var from_ok: bool = domain.can_enter(domain.domain_at(before), loco)
	var to_ok: bool = domain.can_enter(domain.domain_at(u.global_position), loco)
	if from_ok and not to_ok:
		u.global_position = before
		u.path = PackedVector3Array()

func is_infantry(u: RTSUnit) -> bool:
	if not is_instance_valid(u):
		return false
	if str(u.get_meta("role", "")) == "infantry":
		return true
	var raw: Variant = u.get_meta("tags", PackedStringArray())
	if raw is PackedStringArray:
		return (raw as PackedStringArray).has("infantry")
	return false

func _tag_list(unit: Dictionary) -> PackedStringArray:
	var tags: PackedStringArray = PackedStringArray()
	var raw: Variant = unit.get("tags", [])
	if raw is Array:
		for item: Variant in raw:
			tags.append(str(item))
	return tags

func _tick_ability(u: RTSUnit, delta: float) -> void:
	u.set_meta("f_ready", maxf(0.0, float(u.get_meta("f_ready", 0.0)) - delta))
	var status: String = str(u.get_meta("status", "none"))
	if status != "none":
		var left: float = float(u.get_meta("status_t", 0.0)) - delta
		u.set_meta("status_t", left)
		if left <= 0.0:
			apply_status(u, "none", 0.0)
	if not bool(u.get_meta("channeling", false)):
		return
	if bool(u.get_meta("frozen", false)):
		u.set_meta("channeling", false)
		u.set_meta("channel_t", 0.0)
		return
	var channel: float = float(u.get_meta("channel_t", 0.0)) - delta
	u.set_meta("channel_t", channel)
	if channel > 0.0:
		return
	u.set_meta("channeling", false)
	u.set_meta("beam_done", int(u.get_meta("beam_done", 0)) + 1)
	var foe: RTSUnit = nearest_enemy(u.global_position, 240.0)
	if foe != null:
		apply_status(foe, "frozen", 3.0)

func nearest_enemy(from: Vector3, reach: float) -> RTSUnit:
	var best: RTSUnit = null
	var best_d: float = reach
	for u: RTSUnit in units:
		if is_instance_valid(u) and u.is_alive() and teams.are_enemies(PLAYER, u.team):
			var d: float = Vector2(from.x, from.z).distance_to(Vector2(u.global_position.x, u.global_position.z))
			if d <= best_d:
				best_d = d
				best = u
	return best

func handle_button(mb: InputEventMouseButton) -> bool:
	if box == null or cam == null:
		return false
	if mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			box.begin(mb.position)
		else:
			var project_fn: Callable = Callable(self, "project_point")
			var add: bool = mb.shift_pressed
			var toggle: bool = mb.ctrl_pressed and not add
			if box.is_box():
				select_drag(box.rect(), project_fn, add)
			else:
				select_click(mb.position, project_fn, add, toggle)
			box.end()
		return true
	if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		command_at(cam.ground_at(mb.position), mb.position, Callable(self, "project_point"), mb.shift_pressed)
		return true
	return false

func handle_motion(motion: InputEventMouseMotion) -> void:
	hover_at = motion.position
	if box != null and box.active:
		box.update_drag(motion.position)

func tick(delta: float) -> void:
	_fade_marks(delta)
	if group_note_t > 0.0:
		group_note_t = maxf(0.0, group_note_t - delta)
	var alive: Array[RTSUnit] = []
	for u: RTSUnit in units:
		if not is_instance_valid(u):
			continue
		if not u.is_alive():
			_drop_wreck(u.global_position)
			u.queue_free()
			continue
		_tick_ability(u, delta)
		_press_hunt(u)
		_press_bridge(u, delta)
		var before: Vector3 = u.global_position
		u.advance(delta)
		_keep_domain(u, before)
		Forms.animate(u, delta)
		var ring: Node3D = u.get_node_or_null("Ring") as Node3D
		if ring != null:
			ring.visible = u.selected
			var girth: float = _ring_girth(u)
			ring.scale = Vector3(girth, 1.0, girth)
		var reach: MeshInstance3D = u.get_node_or_null("RangeRing") as MeshInstance3D
		if reach != null:
			reach.visible = u.selected and u.team == PLAYER
			var span: float = maxf(u.attack_range, 0.2)
			reach.scale = Vector3(span, 1.0, span)
		_paint_vitals(u, delta)
		alive.append(u)
	units = alive
	_paint_names(alive)
	_paint_path()

func _drop_wreck(at: Vector3) -> void:
	if host == null:
		return
	var wreck: MeshInstance3D = MeshInstance3D.new()
	wreck.name = "Wreck"
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = 0.7
	disc.bottom_radius = 0.7
	disc.height = 0.08
	wreck.mesh = disc
	wreck.position = Vector3(at.x, 0.08, at.z)
	wreck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ink: StandardMaterial3D = StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.albedo_color = Color(0.15, 0.05, 0.04)
	wreck.material_override = ink
	wreck.set_meta("order", "wreck")
	wreck.set_meta("life", 0.9)
	host.add_child(wreck)
	marks.append(wreck)

func _mark(at: Vector3, order: String) -> void:
	if host == null:
		return
	var ping: MeshInstance3D = MeshInstance3D.new()
	ping.name = "OrderPing"
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = 0.55
	ring.outer_radius = 0.82
	ping.mesh = ring
	ping.position = Vector3(at.x, 0.15, at.z)
	ping.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ink: StandardMaterial3D = StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.albedo_color = Color(0.95, 0.28, 0.22) if order == "attack" else Color(0.95, 0.78, 0.28)
	ping.material_override = ink
	ping.set_meta("order", order)
	ping.set_meta("life", 1.15)
	host.add_child(ping)
	marks.append(ping)

func _fade_marks(delta: float) -> void:
	var kept: Array[Node3D] = []
	for ping: Node3D in marks:
		if not is_instance_valid(ping):
			continue
		var life: float = float(ping.get_meta("life", 0.0)) - delta
		if life <= 0.0:
			ping.queue_free()
			continue
		ping.set_meta("life", life)
		kept.append(ping)
	marks = kept

func announce(u: RTSUnit, cue: String) -> void:
	if not is_instance_valid(u) or u.team != PLAYER:
		return
	var text: String = SMBark.line(u.unit_type, cue)
	if on_line.is_valid():
		on_line.call(text)
	if on_bark.is_valid():
		var pitch: float = 1.35 if str(u.get_meta("status", "")) == "shrunk" else 1.0
		on_bark.call(pitch)

func _first_player() -> RTSUnit:
	for u: RTSUnit in selection.units:
		if is_instance_valid(u) and u.is_alive() and u.team == PLAYER:
			return u
	return null

func _ring_girth(u: RTSUnit) -> float:
	var category: String = category_of(u.unit_type)
	if category == "vehicle":
		return 1.85
	if category == "boat" or category == "aircraft":
		return 1.55
	return 0.72

func _paint_names(alive: Array[RTSUnit]) -> void:
	var hover_unit: RTSUnit = null
	var hover_d: float = PICK_PX
	if hover_at != Vector2.INF and cam != null:
		for u: RTSUnit in alive:
			if u.selected:
				continue
			var screen: Vector2 = project_point(u.global_position)
			var d: float = screen.distance_to(hover_at)
			if d <= hover_d:
				hover_d = d
				hover_unit = u
	for u: RTSUnit in alive:
		var tag: Label3D = u.get_node_or_null("NameTag") as Label3D
		if tag == null:
			continue
		tag.visible = u.selected or u == hover_unit

func _paint_vitals(u: RTSUnit, delta: float) -> void:
	var bar: MeshInstance3D = u.get_node_or_null("HealthBar") as MeshInstance3D
	if bar != null:
		var ratio: float = clampf(u.hp / maxf(u.max_hp, 1.0), 0.0, 1.0)
		bar.scale = Vector3(maxf(0.04, ratio), 1.0, 1.0)
		var ink: StandardMaterial3D = bar.material_override as StandardMaterial3D
		if ink != null and u.team == PLAYER and ratio < 0.35:
			ink.albedo_color = Color(0.92, 0.55, 0.18)
	var flash: float = float(u.get_meta("flash_t", 0.0))
	if flash > 0.0:
		flash = maxf(0.0, flash - delta)
		u.set_meta("flash_t", flash)
		var muzzle: MeshInstance3D = u.get_node_or_null("Muzzle") as MeshInstance3D
		if muzzle != null:
			muzzle.visible = flash > 0.0
	var seen: float = float(u.get_meta("seen_hp", u.hp))
	var drop: float = seen - u.hp
	if drop > 0.4:
		_pop_damage(u, drop)
		if u.team == PLAYER:
			var now: int = Time.get_ticks_msec()
			if now >= int(u.get_meta("hurt_until", 0)):
				announce(u, "hurt")
				u.set_meta("hurt_until", now + 1600)
	u.set_meta("seen_hp", u.hp)
	_rise_pop(u, delta)

func _press_hunt(u: RTSUnit) -> void:
	if not bool(u.get_meta("hunt", false)) or bool(u.get_meta("frozen", false)):
		return
	if u.attack_target != null and is_instance_valid(u.attack_target) and u.attack_target.is_alive():
		return
	u.attack_target = null
	var foe: RTSUnit = nearest_enemy(u.global_position, u.attack_range)
	if foe != null:
		u.attack_target = foe
		return
	var goal: Variant = u.get_meta("hunt_goal", Vector3.INF)
	if not (goal is Vector3):
		return
	var at: Vector3 = goal as Vector3
	if at == Vector3.INF:
		return
	var flat: float = Vector2(u.global_position.x, u.global_position.z).distance_to(Vector2(at.x, at.z))
	if flat <= 1.4:
		u.set_meta("hunt", false)
		return
	if u.path.is_empty():
		var route: PackedVector3Array = nav_for_unit(u).find_path(u.global_position, at)
		if not route.is_empty():
			u.set_path(route)

func _paint_path() -> void:
	if host == null:
		return
	var mark: MeshInstance3D = host.get_node_or_null("PathMark") as MeshInstance3D
	var lead: RTSUnit = _first_player()
	var show: bool = lead != null and not lead.path.is_empty()
	if not show:
		if mark != null:
			mark.visible = false
		return
	if mark == null:
		mark = MeshInstance3D.new()
		mark.name = "PathMark"
		var gem: BoxMesh = BoxMesh.new()
		gem.size = Vector3(0.55, 0.14, 0.55)
		mark.mesh = gem
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var ink: StandardMaterial3D = StandardMaterial3D.new()
		ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ink.albedo_color = Color(0.95, 0.82, 0.28)
		mark.material_override = ink
		host.add_child(mark)
	var step: Vector3 = lead.path[0]
	mark.position = Vector3(step.x, 0.22, step.z)
	mark.visible = true

func _pop_damage(u: RTSUnit, amount: float) -> void:
	var pop: Label3D = u.get_node_or_null("DamagePop") as Label3D
	if pop == null:
		pop = Label3D.new()
		pop.name = "DamagePop"
		pop.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		pop.font_size = 64
		pop.pixel_size = 0.005
		pop.outline_size = 10
		pop.no_depth_test = true
		pop.position = Vector3(0.0, 2.4, 0.0)
		u.add_child(pop)
	pop.text = "-%d" % maxi(1, int(round(amount)))
	pop.modulate = Color(1.0, 0.45, 0.32, 1.0) if u.team == PLAYER else Color(1.0, 0.86, 0.35, 1.0)
	pop.position = Vector3(0.0, 2.4, 0.0)
	pop.visible = true
	u.set_meta("pop_t", 0.75)

func _rise_pop(u: RTSUnit, delta: float) -> void:
	var pop: Label3D = u.get_node_or_null("DamagePop") as Label3D
	if pop == null or not pop.visible:
		return
	var left: float = float(u.get_meta("pop_t", 0.0)) - delta
	u.set_meta("pop_t", left)
	if left <= 0.0:
		pop.visible = false
		return
	pop.position.y += delta * 1.6
	pop.modulate.a = clampf(left / 0.75, 0.0, 1.0)
