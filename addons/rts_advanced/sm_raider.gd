class_name SMRaider
extends RefCounted
## The skirmish enemy builds a yard, claims a ruby node, and attacks.

const World = preload("res://game/world_view.gd")

var yard: SMBuildYard = SMBuildYard.new()
var goods: SMCommodityNet = SMCommodityNet.new()
var economy: RTSEconomy = RTSEconomy.new()
var field: SMPointer
var built: bool = false
var expanded: bool = false
var attacked: bool = false
var node_id: StringName = &"enemy_ruby"
var personality_name: String = "Bo Mya"
var plan_goods: SMCommodityNet
var plan_tech: SMTechNet
var plan_a: StringName = &""
var plan_b: StringName = &""
var plan_site: StringName = &""
var opened_nodes: int = 0
var took_tech: bool = false
var used_f: bool = false

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

func bind_plan(goods: SMCommodityNet, tech: SMTechNet, first: StringName, second: StringName, site: StringName, who: String) -> void:
	plan_goods = goods
	plan_tech = tech
	plan_a = first
	plan_b = second
	plan_site = site
	personality_name = who

func tick(_delta: float) -> void:
	if field == null:
		return
	_build()
	_expand()
	_open()
	_attack()

func show_markers(host: Node3D) -> void:
	if built and host.get_node_or_null("EnemyYard") == null:
		_marker(host, "EnemyYard", SMPointer.building_at(yard.center), SMPointer.BUILDING_SIZE, Color(0.45, 0.16, 0.14))
	var yard_node: Node3D = host.get_node_or_null("EnemyYard") as Node3D
	World.billboard(yard_node, "Personality", personality_name, 48, 0.02, Vector3(0, 3.4, 0))
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

func _open() -> void:
	if plan_goods != null and plan_a != &"" and plan_b != &"":
		if not plan_goods.has_collector(plan_a):
			plan_goods.snap_refinery(plan_a, SMPointer.ENEMY)
		if not plan_goods.has_collector(plan_b):
			plan_goods.snap_refinery(plan_b, SMPointer.ENEMY)
		opened_nodes = 0
		if plan_goods.has_collector(plan_a):
			opened_nodes += 1
		if plan_goods.has_collector(plan_b):
			opened_nodes += 1
	if plan_tech != null and plan_site != &"":
		if plan_tech.owner_of(plan_site) < 0:
			took_tech = plan_tech.capture(plan_site, SMPointer.ENEMY)
		elif plan_tech.owner_of(plan_site) == SMPointer.ENEMY:
			took_tech = true
	if used_f or field == null:
		return
	var foes: Array[RTSUnit] = field.units_of(SMPointer.ENEMY)
	if foes.is_empty():
		return
	used_f = field.apply_named_f(foes[0])

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
	World.slab(host, node_name, pos, size, color)
