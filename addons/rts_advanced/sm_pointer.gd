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
var selection: RTSSelection = RTSSelection.new()
var units: Array[RTSUnit] = []
var box: RTSSelectionBox
var cam: RTSCamera
var host: Node3D
var ew: SMEwField
const F_COOLDOWN: float = 3.0
const BEAM_TIME: float = 1.5

func bind(p_host: Node3D, p_cam: RTSCamera) -> void:
	host = p_host
	cam = p_cam
	teams.add_team(PLAYER, Color(0.72, 0.12, 0.18))
	teams.add_team(ENEMY, Color(0.12, 0.62, 0.7))
	teams.set_relation(PLAYER, ENEMY, RTSTeams.Relation.ENEMY)
	selection.team = PLAYER

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

func use_domain(grid: SMDomainGrid) -> void:
	nav = RTSGridNav.new(grid.cols, grid.rows, grid.cell_size, grid.origin)
	for y: int in range(grid.rows):
		for x: int in range(grid.cols):
			var domain: int = grid.domain_at_cell(Vector2i(x, y))
			var open: bool = domain == SMDomainGrid.Domain.LAND or domain == SMDomainGrid.Domain.SHALLOW
			if not open:
				nav.set_blocked(Vector2i(x, y), true)

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
	var body: MeshInstance3D = _body_mesh(team, kind)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = _body_color(team, kind)
	body.material_override = mat
	u.add_child(body)
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.name = "Ring"
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.75
	torus.outer_radius = 0.95
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
	tag.font_size = 48
	tag.pixel_size = 0.02
	tag.outline_size = 12
	tag.outline_modulate = Color(0.02, 0.02, 0.03)
	tag.position = Vector3(0, 2.7, 0)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = Color(0.97, 0.94, 0.84)
	u.add_child(tag)
	u.shot_filter = Callable(self, "filter_shot")
	host.add_child(u)
	units.append(u)
	return u

func unit_label(team: int, kind: StringName) -> String:
	if team != PLAYER:
		return "Enemy"
	var data: Dictionary = SMCatalog.faction(faction_id)
	for unit: Dictionary in SMCatalog.units_of(data):
		if str(unit.get("id", "")) == str(kind):
			return str(unit.get("display_name", faction_id.to_upper()))
	return faction_id.to_upper()

func name_of(u: RTSUnit) -> String:
	if not is_instance_valid(u):
		return ""
	var tag: Label3D = u.get_node_or_null("NameTag") as Label3D
	if tag == null:
		return ""
	return tag.text

func _apply_catalog(u: RTSUnit, kind: StringName) -> void:
	var data: Dictionary = SMCatalog.faction(faction_id)
	for unit: Dictionary in SMCatalog.units_of(data):
		if str(unit.get("id", "")) != str(kind):
			continue
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
		return

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
	var units: Array[Dictionary] = SMCatalog.units_of(SMCatalog.faction(faction_id))
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

func _body_mesh(_team: int, kind: StringName) -> MeshInstance3D:
	var body: MeshInstance3D = MeshInstance3D.new()
	body.name = "Body"
	var category: String = category_of(kind)
	if category == "infantry":
		var cap: CapsuleMesh = CapsuleMesh.new()
		cap.radius = 0.26
		cap.height = 1.7
		body.mesh = cap
		body.position = Vector3(0, 0.85, 0)
	elif category == "aircraft":
		var wedge: PrismMesh = PrismMesh.new()
		wedge.size = Vector3(1.9, 0.28, 2.4)
		body.mesh = wedge
		body.position = Vector3(0, 1.35, 0)
	elif category == "boat":
		var hull: BoxMesh = BoxMesh.new()
		hull.size = Vector3(0.62, 0.36, 2.9)
		body.mesh = hull
		body.position = Vector3(0, 0.2, 0)
	else:
		var wide: BoxMesh = BoxMesh.new()
		wide.size = Vector3(2.2, 0.8, 1.2)
		body.mesh = wide
		body.position = Vector3(0, 0.4, 0)
	return body

func units_of(team: int) -> Array[RTSUnit]:
	var out: Array[RTSUnit] = []
	for u: RTSUnit in units:
		if is_instance_valid(u) and u.is_alive() and u.team == team:
			out.append(u)
	return out

func count_team(team: int) -> int:
	return units_of(team).size()

func select_click(screen: Vector2, project_fn: Callable) -> RTSUnit:
	return selection.select_at(screen, units, project_fn, false, false, PICK_PX)

func select_drag(rect: Rect2, project_fn: Callable) -> int:
	return selection.select_box(rect, units, project_fn, false)

## Right click. Returns "attack", "move", or "none".
func command_at(ground: Vector3, screen: Vector2, project_fn: Callable) -> StringName:
	if selection.count() <= 0:
		return &"none"
	var foe: RTSUnit = enemy_near(screen, ground, project_fn)
	if foe != null:
		var hit: int = RTSOrders.attack(selection.units, foe, nav, teams)
		return &"attack" if hit > 0 else &"none"
	if ground == Vector3.INF:
		return &"none"
	var slots: Array[Vector3] = RTSOrders.move(selection.units, ground, nav)
	return &"move" if not slots.is_empty() else &"none"

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
		var strike: RTSUnit = nearest_enemy(aim, 240.0)
		if strike != null:
			strike.take_damage(smart.attack_damage * smart.damage_mult)
		fired = "smart" if fired == "" else fired + "+smart"
	if beam != null:
		beam.set_meta("channeling", true)
		beam.set_meta("channel_t", BEAM_TIME)
		beam.set_meta("f_ready", F_COOLDOWN)
		fired = "beam" if fired == "" else fired + "+beam"
	return fired

func apply_status(u: RTSUnit, status: String, duration: float) -> void:
	if not is_instance_valid(u):
		return
	var body: MeshInstance3D = u.get_node_or_null("Body") as MeshInstance3D
	if body != null:
		body.scale = Vector3.ONE
	u.speed_scale = 1.0
	u.incoming_mult = 1.0
	u.set_meta("frozen", false)
	u.set_meta("status", status)
	u.set_meta("status_t", duration)
	if status == "frozen":
		u.set_meta("frozen", true)
		u.speed_scale = 0.0
		u.stop()
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
			if box.is_box():
				select_drag(box.rect(), project_fn)
			else:
				select_click(mb.position, project_fn)
			box.end()
		return true
	if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		command_at(cam.ground_at(mb.position), mb.position, Callable(self, "project_point"))
		return true
	return false

func handle_motion(motion: InputEventMouseMotion) -> void:
	if box != null and box.active:
		box.update_drag(motion.position)

func tick(delta: float) -> void:
	var alive: Array[RTSUnit] = []
	for u: RTSUnit in units:
		if not is_instance_valid(u):
			continue
		if not u.is_alive():
			u.queue_free()
			continue
		_tick_ability(u, delta)
		u.advance(delta)
		var ring: Node3D = u.get_node_or_null("Ring") as Node3D
		if ring != null:
			ring.visible = u.selected
		alive.append(u)
	units = alive
