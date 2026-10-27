class_name SMPointer
extends RefCounted
## Click controls for a match: left click and drag select friendlies,
## right click ground to move, right click an enemy to attack.

const PLAYER: int = 0
const ENEMY: int = 1
const PICK_PX: float = 28.0
const ATTACK_M: float = 2.2

var teams: RTSTeams = RTSTeams.new()
var nav: RTSGridNav
var selection: RTSSelection = RTSSelection.new()
var units: Array[RTSUnit] = []
var box: RTSSelectionBox
var cam: RTSCamera
var host: Node3D

func bind(p_host: Node3D, p_cam: RTSCamera) -> void:
	host = p_host
	cam = p_cam
	teams.add_team(PLAYER, Color(0.72, 0.12, 0.18))
	teams.add_team(ENEMY, Color(0.12, 0.62, 0.7))
	teams.set_relation(PLAYER, ENEMY, RTSTeams.Relation.ENEMY)
	selection.team = PLAYER

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
	var body: MeshInstance3D = MeshInstance3D.new()
	if team == PLAYER:
		var cap: CapsuleMesh = CapsuleMesh.new()
		cap.radius = 0.45
		cap.height = 1.6
		body.mesh = cap
		body.position = Vector3(0, 0.8, 0)
	else:
		var box_mesh: BoxMesh = BoxMesh.new()
		box_mesh.size = Vector3(1.15, 1.25, 1.15)
		body.mesh = box_mesh
		body.position = Vector3(0, 0.62, 0)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = teams.color_of(team)
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
	tag.text = "GTFC" if team == PLAYER else "Enemy"
	tag.font_size = 42
	tag.position = Vector3(0, 2.3, 0)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = Color(0.96, 0.93, 0.82)
	u.add_child(tag)
	host.add_child(u)
	units.append(u)
	return u

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
		u.advance(delta)
		var ring: Node3D = u.get_node_or_null("Ring") as Node3D
		if ring != null:
			ring.visible = u.selected
		alive.append(u)
	units = alive
