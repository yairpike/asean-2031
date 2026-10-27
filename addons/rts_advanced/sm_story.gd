class_name SMStory
extends RefCounted
## Live win check for a story mission. The objective button is only a hidden debug shortcut.

const REACH: float = 2.4

var mission_id: String = ""
var ending: String = ""
var done: bool = false
var field: SMPointer
var roster: SMRoster
var side: SMSide
var goods: SMCommodityNet
var tech: SMTechNet
var protocols: SMProtocols
var abilities: SMAbilities
var ew: SMEwField
var sight: SMSight
var sail: SMBuildYard
var host: Node3D
var pad: Vector3 = Vector3(10.0, 0.0, -6.0)
var far_shore: Vector3 = Vector3(12.0, 0.0, 2.0)
var shallow_pad: Vector3 = Vector3(10.0, 0.0, 6.0)
var raid: SMMission

var _ruby: bool = false
var _cyber: bool = false
var _radar: bool = false
var _haze: bool = false
var _cross: bool = false
var _packer: bool = false
var _kill: bool = false
var _beam: bool = false
var _swarm: bool = false
var _napalm: bool = false
var _toxin: bool = false
var _cryo: bool = false
var _trio: bool = false

static func ending_of(id: String) -> String:
	if id == "kokang":
		return "capture: yard, ruby night shift, and one rare-earth stock"
	if id == "tachileik":
		return "capture: ruby night shift fills the purse"
	if id == "shwe_kokko":
		return "capture: the compound is taken and the enemy purse is siphoned"
	if id == "operation_1027":
		return "destroy: the 23-drone swarm launches"
	if id == "andaman":
		return "escort: an amphibious unit reaches the far shore"
	if id == "ghosts_of_patani":
		return "destroy: the enemy inside the jammer dies, GPS cut and fiber full"
	if id == "kilometer_watch":
		return "capture: the hydro radar is held and water shows"
	if id == "black_haze":
		return "survive: the company lives through the haze with a radar held"
	if id == "archipelago_rising":
		return "escort: the packer reaches shallow water and the wharf is upgraded"
	if id == "wrath_of_the_garuda":
		return "destroy: the Su-30 napalm run is called"
	if id == "fog_over_pakbeng":
		return "survive: a hydro radar is held so the haze does not blind the company"
	if id == "keng_tung":
		return "destroy: Toxic Defoliation is cast"
	if id == "plain_of_jars":
		return "destroy: the beam is held until the target freezes"
	if id == "tonle_sap":
		return "destroy: Cryogeddon freezes the target"
	if id == "shattered_monsoon":
		return "cast: Cash Bounty, Advanced Rocket Pods, and Cryoshot"
	return ""

func bind_mission(p_host: Node3D, id: String, p_field: SMPointer, p_side: SMSide, p_roster: SMRoster, layer: CanvasLayer, grid: SMDomainGrid) -> void:
	host = p_host
	mission_id = id
	ending = ending_of(id)
	field = p_field
	side = p_side
	roster = p_roster
	if ending == "":
		return
	if id == "tachileik":
		_ruby = true
		goods = SMCommodityNet.new()
		goods.add_node(&"ruby", SMCommodityNet.KIND_RUBY, pad, 30, false)
		_pad(pad, Color(0.7, 0.12, 0.2), "RubyPad")
	elif id == "shwe_kokko":
		_cyber = true
		tech = SMTechNet.new()
		tech.add_site(&"compound", SMTechNet.CYBER, pad)
		roster.economy.set_credits(1, 400)
		_pad(pad, Color(0.15, 0.75, 0.82), "CyberPad")
	elif id == "kilometer_watch" or id == "black_haze" or id == "fog_over_pakbeng":
		_radar = true
		_haze = id != "kilometer_watch"
		tech = SMTechNet.new()
		tech.add_site(&"radar", SMTechNet.RADAR, pad)
		sight = SMSight.new()
		if _haze:
			sight.force_weather(true)
		_pad(pad, Color(0.25, 0.45, 0.85), "RadarPad")
	elif id == "andaman":
		_cross = true
		grid.fill_rect(Rect2i(7, 0, 3, grid.rows), SMDomainGrid.Domain.DEEP)
		field.use_domain(grid)
		field.spawn(SMPointer.PLAYER, Vector3(-12.0, 0.0, 0.0), &"channel_skiff")
		_slab("ChannelWater", Vector3(-1.0, -0.05, 0.0), Vector3(6.0, 0.12, 24.0), Color(0.12, 0.28, 0.42))
		_pad(far_shore, Color(0.72, 0.62, 0.32), "FarShore")
	elif id == "archipelago_rising":
		_packer = true
		field.spawn(SMPointer.PLAYER, Vector3(-8.0, 0.0, 1.0), &"channel_skiff")
		sail = SMBuildYard.new()
		sail.style = SMBuildYard.Style.MOBILE
		sail.grid = SMDomainGrid.new(6, 6, 4.0, shallow_pad - Vector3(8.0, 0.0, 8.0))
		sail.grid.fill_rect(Rect2i(0, 0, 6, 6), SMDomainGrid.Domain.SHALLOW)
		sail.packer_pos = sail.grid.cell_center(Vector2i(1, 1))
		sail.packer_id = 7
		_pad(shallow_pad, Color(0.2, 0.55, 0.62), "ShallowPad")
	elif id == "ghosts_of_patani":
		_kill = true
		ew = SMEwField.new()
		ew.radius = 10.0
		ew.penalty = 0.25
		var foe: RTSUnit = _first_enemy()
		ew.center = foe.global_position if foe != null else Vector3(6.0, 0.0, 3.0)
		field.ew = ew
		for u: RTSUnit in field.units_of(SMPointer.PLAYER):
			if str(u.unit_type) == "ruby_lancer":
				u.set_meta("guidance", "gps")
			elif str(u.unit_type) == "militia":
				u.set_meta("guidance", "fiber")
				u.set_meta("fiber_on", true)
	elif id == "plain_of_jars":
		_beam = true
		field.spawn(SMPointer.PLAYER, Vector3(-8.0, 0.0, 3.0), &"monsoon_tube")
	elif id == "operation_1027" or id == "wrath_of_the_garuda" or id == "keng_tung" or id == "tonle_sap" or id == "shattered_monsoon":
		_swarm = id == "operation_1027"
		_napalm = id == "wrath_of_the_garuda"
		_toxin = id == "keng_tung"
		_cryo = id == "tonle_sap"
		_trio = id == "shattered_monsoon"
		protocols = SMProtocols.new()
		abilities = SMAbilities.new()
		abilities.add_unit(10, Vector3(6.0, 0.0, 3.0), SMAbilities.TOGGLE, 1.0, 1.0)
		protocols.mount_panel(layer, roster.economy, 0, abilities, Callable(p_host, "_say"))

func bind_raid(p_host: Node3D, p_raid: SMMission, p_field: SMPointer, p_side: SMSide) -> void:
	host = p_host
	raid = p_raid
	mission_id = "kokang"
	ending = ending_of("kokang")
	field = p_field
	side = p_side
	goods = p_raid.goods
	_ruby = true

func tick(delta: float) -> bool:
	if done or field == null or ending == "":
		return false
	if raid != null:
		return _tick_raid(delta)
	_occupy(delta)
	if _cryo or _trio:
		_freeze_enemy()
	if not _ready():
		return false
	done = true
	if _beam or _cryo or _trio:
		_freeze_enemy()
	return true

func _tick_raid(delta: float) -> bool:
	if raid.won:
		done = true
		return false
	_occupy(delta)
	if goods != null:
		goods.advance(delta, raid.economy)
		raid.ruby_paid = goods.paid_of(&"ruby")
	if side != null and side.yard.finished.has(&"scaffold_yard") and not raid.yard.finished.has(&"scaffold_yard"):
		raid.yard.finished.append(&"scaffold_yard")
		raid.yard.drained = maxi(raid.yard.drained, 1)
	if not raid.try_win():
		return false
	done = true
	return true

func _occupy(delta: float) -> void:
	for u: RTSUnit in field.units_of(SMPointer.PLAYER):
		if not is_instance_valid(u) or not u.is_alive():
			continue
		if goods != null:
			goods.claim_at(u.global_position, SMPointer.PLAYER, REACH)
		if tech != null:
			tech.capture_at(u.global_position, SMPointer.PLAYER, REACH)
	if _ruby and goods != null and goods.has_collector(&"ruby") and not goods.night_on(&"ruby"):
		goods.set_night_shift(&"ruby", true)
	if _ruby and goods != null and roster != null and raid == null:
		goods.advance(delta, roster.economy)
	if _packer and sail != null and not sail.unpacked and _near(&"channel_skiff", shallow_pad):
		var dest: Vector3 = sail.grid.cell_center(Vector2i(2, 1))
		if sail.move_packer(dest):
			sail.unpack(&"gun_wharf")
			sail.upgrade_factory(&"gun_wharf")
			_slab("Wharf", dest + Vector3(0.0, 1.2, 0.0), Vector3(2.2, 2.4, 2.2), Color(0.12, 0.62, 0.4))
	if _cyber and tech != null and roster != null:
		tech.advance(delta, roster.economy, SMPointer.ENEMY)

func _ready() -> bool:
	if _ruby and goods != null:
		return goods.night_on(&"ruby") and goods.paid_of(&"ruby") >= 30
	if _cyber and tech != null:
		return tech.owner_of(&"compound") == SMPointer.PLAYER and tech.siphon_of(&"compound") > 0
	if _radar and tech != null:
		if not tech.reveals_water(SMPointer.PLAYER) or not _company_alive():
			return false
		if not _haze:
			return true
		return sight != null and sight.weather_name == "Strait Haze" and sight.unit_radius(false) < SMSight.UNIT_RADIUS and is_equal_approx(sight.unit_radius(true), SMSight.UNIT_RADIUS)
	if _cross:
		return _crossed()
	if _packer and sail != null:
		return sail.factory_level(&"gun_wharf") == 2 and sail.grid.unit_domain(sail.packer_id) == SMDomainGrid.Domain.SHALLOW
	if _kill and ew != null:
		var foe: RTSUnit = _first_enemy()
		var dead: bool = foe == null or not foe.is_alive()
		return dead and ew.accuracy(ew.center, SMEwField.GPS) < 1.0 and ew.accuracy(ew.center, SMEwField.FIBER) == 1.0
	if _beam:
		return _beam_held()
	if _swarm and protocols != null:
		return protocols.swarm_count == 23
	if _napalm and protocols != null:
		return protocols.napalm == 36
	if _toxin and protocols != null:
		return protocols.defoliation
	if _cryo and protocols != null:
		return protocols.cryo_wave and _enemy_frozen()
	if _trio and protocols != null:
		return protocols.credits_bonus == 250 and is_equal_approx(protocols.damage_mult, 1.5) and protocols.cryo_applied
	return false

func _crossed() -> bool:
	for u: RTSUnit in field.units_of(SMPointer.PLAYER):
		if is_instance_valid(u) and u.is_alive() and str(u.get_meta("locomotion", "")) == "amphibious" and u.global_position.x > 8.0:
			return true
	return false

func _beam_held() -> bool:
	var held: bool = false
	for u: RTSUnit in field.units_of(SMPointer.PLAYER):
		if is_instance_valid(u) and int(u.get_meta("beam_done", 0)) >= 1:
			held = true
	return held and _enemy_frozen()

func _enemy_frozen() -> bool:
	var foe: RTSUnit = _first_enemy()
	return foe != null and bool(foe.get_meta("frozen", false))

func _freeze_enemy() -> void:
	var foe: RTSUnit = _first_enemy()
	if foe != null and foe.is_alive() and not bool(foe.get_meta("frozen", false)):
		field.apply_status(foe, "frozen", 8.0)

func _company_alive() -> bool:
	for u: RTSUnit in field.units_of(SMPointer.PLAYER):
		if is_instance_valid(u) and u.is_alive():
			return true
	return false

func _near(kind: String, at: Vector3) -> bool:
	for u: RTSUnit in field.units_of(SMPointer.PLAYER):
		if is_instance_valid(u) and u.is_alive() and str(u.unit_type) == kind and u.global_position.distance_to(at) <= REACH:
			return true
	return false

func _first_enemy() -> RTSUnit:
	var foes: Array[RTSUnit] = field.units_of(SMPointer.ENEMY)
	if foes.is_empty():
		return null
	return foes[0]

func _pad(at: Vector3, color: Color, node_name: String) -> void:
	_slab(node_name, at + Vector3(0.0, 0.15, 0.0), Vector3(1.6, 0.3, 1.6), color)

func _slab(node_name: String, at: Vector3, size: Vector3, color: Color) -> void:
	if host == null or host.get_node_or_null(node_name) != null:
		return
	var body: MeshInstance3D = MeshInstance3D.new()
	body.name = node_name
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	body.mesh = mesh
	body.position = at
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	body.material_override = mat
	host.add_child(body)
