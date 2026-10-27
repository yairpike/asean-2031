class_name SMRaider
extends RefCounted
## The skirmish enemy builds a yard, claims a ruby node, and attacks.

var yard: SMBuildYard = SMBuildYard.new()
var goods: SMCommodityNet = SMCommodityNet.new()
var economy: RTSEconomy = RTSEconomy.new()
var field: SMPointer
var built: bool = false
var expanded: bool = false
var attacked: bool = false
var node_id: StringName = &"enemy_ruby"

func attach(p_field: SMPointer, center: Vector3) -> void:
	field = p_field
	economy = RTSEconomy.new()
	economy.set_credits(SMPointer.ENEMY, 3000)
	yard = SMBuildYard.new()
	yard.style = SMBuildYard.Style.SCAFFOLD
	yard.team = SMPointer.ENEMY
	yard.economy = economy
	yard.center = center
	yard.radius = 24.0
	yard.drain_per_sec = 4
	yard.tech_order = [&"enemy_yard"]
	yard.building_time[&"enemy_yard"] = 2.0
	yard.building_tier[&"enemy_yard"] = 1
	goods = SMCommodityNet.new()
	goods.add_node(node_id, SMCommodityNet.KIND_RUBY, center + Vector3(3.0, 0.0, 2.0), 12, false)
	built = false
	expanded = false
	attacked = false

func tick(_delta: float) -> void:
	if field == null:
		return
	_build()
	_expand()
	_attack()

func show_markers(host: Node3D) -> void:
	if built and host.get_node_or_null("EnemyYard") == null:
		_marker(host, "EnemyYard", SMPointer.building_at(yard.center), SMPointer.BUILDING_SIZE, Color(0.45, 0.16, 0.14))
	if expanded and host.get_node_or_null("EnemyClaim") == null:
		var spot: Vector3 = yard.center + Vector3(3.0, 0.5, 2.0)
		_marker(host, "EnemyClaim", spot, Vector3(1.2, 0.8, 1.2), Color(0.7, 0.12, 0.22))

func _build() -> void:
	if yard.finished.has(&"enemy_yard"):
		built = true
		return
	if not yard.scaffold_active:
		yard.begin_scaffold(&"enemy_yard", yard.center, 220.0)
	yard.advance(2.5)
	built = yard.finished.has(&"enemy_yard")

func _expand() -> void:
	if goods.has_collector(node_id):
		expanded = true
		return
	expanded = goods.snap_refinery(node_id, SMPointer.ENEMY)

func _attack() -> void:
	var friends: Array[RTSUnit] = field.units_of(SMPointer.PLAYER)
	var foes: Array[RTSUnit] = field.units_of(SMPointer.ENEMY)
	if friends.is_empty() or foes.is_empty():
		return
	var target: RTSUnit = _nearest(foes[0].global_position, friends)
	var squad: Array[RTSUnit] = []
	for u: RTSUnit in foes:
		squad.append(u)
	var hit: int = 0
	for u: RTSUnit in squad:
		var one: Array[RTSUnit] = [u]
		hit += RTSOrders.attack(one, target, field.nav_for_unit(u), field.teams)
	if hit > 0:
		attacked = true

func _nearest(from: Vector3, group: Array[RTSUnit]) -> RTSUnit:
	var best: RTSUnit = group[0]
	var best_d: float = from.distance_to(best.global_position)
	for u: RTSUnit in group:
		var d: float = from.distance_to(u.global_position)
		if d < best_d:
			best_d = d
			best = u
	return best

func _marker(host: Node3D, node_name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	host.add_child(mi)
