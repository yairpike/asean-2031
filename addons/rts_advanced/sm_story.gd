class_name SMStory
extends RefCounted
## Live win and loss for a story mission. A protocol can help. Casting one does not finish the mission.

const REACH: float = 2.4
signal pad_made(host: Node3D, node_name: String, at: Vector3, size: Vector3, color: Color)
const HOLD_HAZE: float = 16.0
const HOLD_TONLE: float = 20.0

var mission_id: String = ""
var ending: String = ""
var done: bool = false
var lost: bool = false
var loss: String = ""
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
var defend: RTSUnit
var hold_need: float = 0.0
var hold_left: float = 0.0

var _ruby: bool = false
var _cyber: bool = false
var _radar: bool = false
var _haze: bool = false
var _cross: bool = false
var _packer: bool = false
var _kill: bool = false
var _beam: bool = false
var _towers: bool = false
var _fleet: bool = false
var _column: bool = false
var _hold: bool = false
var _supers: bool = false
var _beamed: bool = false
var _phantom_frozen: bool = false
var _phantom: RTSUnit
var _column_need: int = 0
var _column_frozen: int = 0
var _swarm_used: bool = false
var _napalm_used: bool = false
var _defoliation_used: bool = false
var _cryo_used: bool = false
var _trio_used: bool = false
var _alive: Dictionary[String, int] = {}

static func ending_of(id: String) -> String:
	if id == "kokang":
		return "capture: yard, ruby night shift, and one rare-earth stock"
	if id == "tachileik":
		return "destroy: the ambush dies, then the ruby night shift fills the purse"
	if id == "shwe_kokko":
		return "destroy: the garrison dies, then the compound is siphoned"
	if id == "operation_1027":
		return "destroy: the EW towers fall, then the Su-30 and CH-4 hangars"
	if id == "andaman":
		return "destroy: the channel boats die and an amphibious unit reaches the far shore"
	if id == "ghosts_of_patani":
		return "destroy: the enemy inside the jammer dies, GPS cut and fiber full"
	if id == "kilometer_watch":
		return "destroy: the radar garrison dies and the hydro radar is held"
	if id == "black_haze":
		return "survive: hold the radar through the haze while the enemy attacks"
	if id == "archipelago_rising":
		return "destroy: the boats die, then the wharf is unpacked and upgraded"
	if id == "wrath_of_the_garuda":
		return "destroy: the joint enemy fleet is sunk"
	if id == "fog_over_pakbeng":
		return "survive: hold the radar through the haze while the enemy attacks"
	if id == "keng_tung":
		return "destroy: the GTFC tank column is frozen, then destroyed"
	if id == "plain_of_jars":
		return "destroy: the beam freezes the phantom, then the phantom and the battery die"
	if id == "tonle_sap":
		return "survive: the ferry holds until the timer runs out"
	if id == "shattered_monsoon":
		return "destroy: both enemy superweapons are destroyed"
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
		_tag_raider("clear", "Caravan ambush", 100.0, 7.0, 7.0, true)
		_spawn_duty(SMPointer.ENEMY, Vector3(12.0, 0.0, -4.0), &"raider", "clear", "Caravan ambush", 100.0, 7.0, 7.0, true)
		_spawn_duty(SMPointer.ENEMY, Vector3(8.0, 0.0, -8.0), &"raider", "clear", "Caravan ambush", 100.0, 7.0, 7.0, true)
	elif id == "shwe_kokko":
		_cyber = true
		tech = SMTechNet.new()
		tech.add_site(&"compound", SMTechNet.CYBER, pad)
		roster.economy.set_credits(1, 400)
		_pad(pad, Color(0.15, 0.75, 0.82), "CyberPad")
		_tag_raider("clear", "Compound garrison", 110.0, 7.0, 8.0, true)
		_spawn_duty(SMPointer.ENEMY, Vector3(12.0, 0.0, -3.0), &"raider", "clear", "Compound garrison", 110.0, 7.0, 8.0, true)
		_spawn_duty(SMPointer.ENEMY, Vector3(8.0, 0.0, -8.0), &"raider", "clear", "Compound garrison", 110.0, 7.0, 8.0, true)
	elif id == "kilometer_watch":
		_radar = true
		tech = SMTechNet.new()
		tech.add_site(&"radar", SMTechNet.RADAR, pad)
		sight = SMSight.new()
		_pad(pad, Color(0.25, 0.45, 0.85), "RadarPad")
		_tag_raider("clear", "Radar garrison", 100.0, 7.0, 7.0, true)
		_spawn_duty(SMPointer.ENEMY, Vector3(12.0, 0.0, -3.0), &"raider", "clear", "Radar garrison", 100.0, 7.0, 7.0, true)
		_spawn_duty(SMPointer.ENEMY, Vector3(8.0, 0.0, -8.0), &"raider", "clear", "Radar garrison", 100.0, 7.0, 7.0, true)
	elif id == "black_haze" or id == "fog_over_pakbeng":
		_radar = true
		_haze = true
		_hold = true
		hold_need = HOLD_HAZE
		hold_left = HOLD_HAZE
		tech = SMTechNet.new()
		tech.add_site(&"radar", SMTechNet.RADAR, pad)
		sight = SMSight.new()
		sight.force_weather(true)
		_pad(pad, Color(0.25, 0.45, 0.85), "RadarPad")
		_tag_raider("pressure", "Haze raider", 90.0, 7.0, 6.0, false)
		_spawn_duty(SMPointer.ENEMY, Vector3(4.0, 0.0, 4.0), &"raider", "pressure", "Haze raider", 90.0, 7.0, 6.0, false)
		_spawn_duty(SMPointer.ENEMY, Vector3(2.0, 0.0, -6.0), &"raider", "pressure", "Haze raider", 90.0, 7.0, 6.0, false)
	elif id == "andaman":
		_cross = true
		grid.fill_rect(Rect2i(7, 0, 3, grid.rows), SMDomainGrid.Domain.DEEP)
		field.use_domain(grid)
		field.spawn(SMPointer.PLAYER, Vector3(-12.0, 0.0, 0.0), &"channel_skiff")
		_slab("ChannelWater", Vector3(-1.0, -0.05, 0.0), Vector3(6.0, 0.12, 24.0), Color(0.12, 0.28, 0.42))
		_pad(far_shore, Color(0.72, 0.62, 0.32), "FarShore")
		_tag_raider("clear", "Shore gun", 100.0, 6.0, 8.0, true)
		_spawn_duty(SMPointer.ENEMY, Vector3(-1.0, 0.0, 2.0), &"channel_skiff", "clear", "Channel boat", 120.0, 6.0, 8.0, true)
		_spawn_duty(SMPointer.ENEMY, Vector3(1.0, 0.0, -2.0), &"channel_skiff", "clear", "Channel boat", 120.0, 6.0, 8.0, true)
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
		_tag_raider("clear", "Shore boat", 110.0, 6.0, 7.0, true)
		_spawn_duty(SMPointer.ENEMY, Vector3(6.0, 0.0, 4.0), &"channel_skiff", "clear", "Shore boat", 110.0, 6.0, 7.0, true)
		_spawn_duty(SMPointer.ENEMY, Vector3(8.0, 0.0, -2.0), &"channel_skiff", "clear", "Shore boat", 110.0, 6.0, 7.0, true)
	elif id == "ghosts_of_patani":
		_kill = true
		ew = SMEwField.new()
		ew.radius = 1000.0
		ew.penalty = 0.4
		var foe: RTSUnit = _first_enemy()
		ew.center = foe.global_position if foe != null else Vector3(6.0, 0.0, 3.0)
		field.ew = ew
		for u: RTSUnit in field.units_of(SMPointer.PLAYER):
			if str(u.unit_type) == "ruby_lancer":
				u.set_meta("guidance", "gps")
			elif str(u.unit_type) == "militia":
				u.set_meta("guidance", "fiber")
				u.set_meta("fiber_on", true)
		_paint(foe, "ghost", "Jammer ghost", 90.0, 6.0, 8.0)
	elif id == "plain_of_jars":
		_beam = true
		field.spawn(SMPointer.PLAYER, Vector3(-8.0, 0.0, 3.0), &"monsoon_tube")
		_phantom = _first_enemy()
		_tag_raider("phantom", "Plain phantom", 140.0, 5.0, 8.0, true)
		_spawn_duty(SMPointer.ENEMY, Vector3(10.0, 0.0, 5.0), &"raider", "battery", "Jar battery", 120.0, 0.0, 9.0, true)
		_slab("JarBattery", Vector3(10.0, 1.1, 5.0), Vector3(1.8, 2.2, 1.8), Color(0.45, 0.42, 0.32))
	elif id == "operation_1027":
		_towers = true
		_mount_protocols(layer)
		_spawn_duty(SMPointer.ENEMY, Vector3(9.0, 0.0, 5.0), &"raider", "tower", "EW tower", 260.0, 0.0, 7.0, true)
		_spawn_duty(SMPointer.ENEMY, Vector3(9.0, 0.0, -5.0), &"raider", "tower", "EW tower", 260.0, 0.0, 7.0, true)
		_spawn_duty(SMPointer.ENEMY, Vector3(14.0, 0.0, 3.0), &"raider", "hangar", "Su-30 hangar", 300.0, 0.0, 0.0, true)
		_spawn_duty(SMPointer.ENEMY, Vector3(14.0, 0.0, -3.0), &"raider", "hangar", "CH-4 hangar", 300.0, 0.0, 0.0, true)
		_tag_raider("escort", "Junta escort", 90.0, 7.0, 7.0, false)
		_spawn_duty(SMPointer.ENEMY, Vector3(4.0, 0.0, 1.0), &"raider", "escort", "Junta escort", 90.0, 7.0, 7.0, false)
		_slab("EwTowerA", Vector3(9.0, 1.6, 5.0), Vector3(1.2, 3.2, 1.2), Color(0.15, 0.22, 0.38))
		_slab("EwTowerB", Vector3(9.0, 1.6, -5.0), Vector3(1.2, 3.2, 1.2), Color(0.15, 0.22, 0.38))
		_slab("Su30Hangar", Vector3(14.0, 1.2, 3.0), Vector3(3.2, 2.4, 2.4), Color(0.32, 0.34, 0.38))
		_slab("Ch4Hangar", Vector3(14.0, 1.2, -3.0), Vector3(3.2, 2.4, 2.4), Color(0.32, 0.34, 0.38))
	elif id == "wrath_of_the_garuda":
		_fleet = true
		_mount_protocols(layer)
		_tag_raider("fleet", "Joint picket", 150.0, 6.5, 8.0, true)
		_move_raider(Vector3(11.0, 0.0, -4.0))
		_spawn_duty(SMPointer.ENEMY, Vector3(12.0, 0.0, 4.0), &"channel_skiff", "fleet", "NMRF trimaran", 150.0, 6.5, 8.0, true)
		_spawn_duty(SMPointer.ENEMY, Vector3(14.0, 0.0, 1.0), &"channel_skiff", "fleet", "MVD cutter", 150.0, 6.5, 8.0, true)
		_spawn_duty(SMPointer.ENEMY, Vector3(13.0, 0.0, -1.0), &"channel_skiff", "fleet", "GTFC gunboat", 150.0, 6.5, 8.0, true)
	elif id == "keng_tung":
		_column = true
		_mount_protocols(layer)
		field.spawn(SMPointer.PLAYER, Vector3(-8.0, 0.0, 3.0), &"monsoon_tube")
		_tag_raider("column", "GTFC tank", 180.0, 3.5, 10.0, true)
		_spawn_duty(SMPointer.ENEMY, Vector3(10.0, 0.0, 3.0), &"amber_tank", "column", "GTFC tank", 180.0, 3.5, 10.0, true)
		_spawn_duty(SMPointer.ENEMY, Vector3(12.0, 0.0, 0.0), &"amber_tank", "column", "GTFC tank", 180.0, 3.5, 10.0, true)
	elif id == "tonle_sap":
		_hold = true
		hold_need = HOLD_TONLE
		hold_left = HOLD_TONLE
		_mount_protocols(layer)
		defend = _spawn_duty(SMPointer.PLAYER, Vector3(1.0, 0.0, 5.0), &"raider", "ferry", "Tonle ferry", 420.0, 0.0, 0.0, false)
		defend.set_meta("objective", true)
		_tag_raider("trimaran", "NMRF trimaran", 110.0, 6.5, 7.0, false)
		_move_raider(Vector3(11.0, 0.0, 6.0))
		_spawn_duty(SMPointer.ENEMY, Vector3(13.0, 0.0, 2.0), &"channel_skiff", "trimaran", "NMRF trimaran", 110.0, 6.5, 7.0, false)
		_spawn_duty(SMPointer.ENEMY, Vector3(9.0, 0.0, -1.0), &"channel_skiff", "trimaran", "NMRF trimaran", 110.0, 6.5, 7.0, false)
		_slab("TonleFerry", Vector3(1.0, 0.8, 5.0), Vector3(2.4, 1.4, 4.2), Color(0.62, 0.48, 0.22))
	elif id == "shattered_monsoon":
		_supers = true
		_mount_protocols(layer)
		_tag_raider("super", "Ion-Cryo Collider", 360.0, 0.0, 9.0, true)
		_move_raider(Vector3(12.0, 0.0, 3.0))
		_spawn_duty(SMPointer.ENEMY, Vector3(12.0, 0.0, -3.0), &"raider", "super", "Seismic Slag Vacuum", 360.0, 0.0, 9.0, true)
		_slab("IonCollider", Vector3(12.0, 2.2, 3.0), Vector3(1.6, 4.4, 1.6), Color(0.25, 0.55, 0.72))
		_slab("SlagVacuum", Vector3(12.0, 2.2, -3.0), Vector3(1.6, 4.4, 1.6), Color(0.55, 0.28, 0.22))

func bind_raid(p_host: Node3D, p_raid: SMMission, p_field: SMPointer, p_side: SMSide) -> void:
	host = p_host
	raid = p_raid
	mission_id = "kokang"
	ending = ending_of("kokang")
	field = p_field
	side = p_side
	goods = p_raid.goods
	_ruby = true

func progress() -> String:
	if raid != null:
		return _raid_line()
	if _towers:
		return "Drop the EW towers (%d), then the hangars (%d)." % [_left("tower"), _left("hangar")]
	if _fleet:
		return "Sink the joint fleet (%d)." % _left("fleet")
	if _column:
		return "Freeze the column (%d/%d), then destroy it (%d left)." % [_column_frozen, _column_need, _left("column")]
	if _supers:
		return "Destroy both superweapons (%d left)." % _left("super")
	if _beam:
		var beam: String = "beam fired" if _beamed else "fire the beam"
		var frozen: String = "phantom frozen" if _phantom_frozen else "freeze the phantom"
		return "Plain of Jars: %s, %s. Phantom %d, battery %d." % [beam, frozen, _left("phantom"), _left("battery")]
	if _kill:
		var ghost: String = "ghost down" if not _living(_first_enemy()) else "ghost standing"
		return "Patani: %s. GPS shots must miss. Fiber stays true." % ghost
	if _cross:
		if _crossed():
			return "Clear the shore (%d). A boat is on the far shore." % _left("clear")
		return "Clear the shore (%d). Land a boat on the far shore." % _left("clear")
	if _packer:
		var level: int = 0
		if sail != null:
			level = sail.factory_level(&"gun_wharf")
		return "Sink the boats (%d). Raise the wharf to level 2 (now %d)." % [_left("clear"), level]
	if _haze:
		if tech == null or not tech.reveals_water(SMPointer.PLAYER):
			return "Capture the radar, then hold it through the haze."
		return "Hold the radar through the haze. %d seconds left." % _secs()
	if _radar:
		if _left("clear") > 0:
			return "Clear the garrison (%d) and hold the hydro radar." % _left("clear")
		if tech != null and tech.reveals_water(SMPointer.PLAYER):
			return "Garrison clear. Hydro radar is held."
		return "Garrison clear. Hold the hydro radar."
	if _cyber:
		if _left("clear") > 0:
			return "Clear the garrison (%d), then siphon the compound." % _left("clear")
		var siphon: int = 0
		if tech != null:
			siphon = tech.siphon_of(&"compound")
		return "Garrison clear. Siphon the compound (%d)." % siphon
	if _ruby:
		var paid: int = 0
		if goods != null:
			paid = goods.paid_of(&"ruby")
		if _left("clear") > 0:
			return "Clear the ambush (%d). Then run the ruby night shift." % _left("clear")
		return "Ambush clear. Ruby night shift %d/30." % paid
	if _hold:
		return "Keep the ferry alive. %d seconds left." % _secs()
	if ending != "":
		return ending
	return "Fight the briefing."

## Where the tall objective marker should stand. INF hides it.
func beacon() -> Vector3:
	if done or lost or field == null:
		return Vector3.INF
	if raid != null:
		return _raid_beacon()
	if _towers:
		return _duty_at("tower", "hangar")
	if _fleet:
		return _duty_at("fleet", "")
	if _column:
		return _duty_at("column", "")
	if _supers:
		return _duty_at("super", "")
	if _beam:
		if not _beamed:
			var tube: RTSUnit = _player_kind("monsoon_tube")
			if tube != null:
				return tube.global_position
		if not _phantom_frozen and _living(_phantom):
			return _phantom.global_position
		return _duty_at("phantom", "battery")
	if _kill:
		var ghost: RTSUnit = _first_enemy()
		if _living(ghost):
			return ghost.global_position
		if ew != null:
			return ew.center
		return Vector3.INF
	if _cross:
		if _left("clear") > 0:
			return _duty_at("clear", "")
		if not _crossed():
			return far_shore
		return Vector3.INF
	if _packer:
		if _left("clear") > 0:
			return _duty_at("clear", "")
		if sail != null and sail.factory_level(&"gun_wharf") < 2:
			return shallow_pad
		return Vector3.INF
	if _haze or _radar:
		if _left("clear") > 0:
			return _duty_at("clear", "")
		return pad
	if _cyber:
		if _left("clear") > 0:
			return _duty_at("clear", "")
		return pad
	if _ruby:
		if _left("clear") > 0:
			return _duty_at("clear", "")
		return pad
	if _hold and _living(defend):
		return defend.global_position
	return Vector3.INF

func _raid_beacon() -> Vector3:
	var yard_up: bool = raid.yard.finished.has(&"scaffold_yard")
	if not yard_up:
		return raid.yard.center
	var paid: int = raid.ruby_paid
	if goods != null:
		paid = maxi(paid, goods.paid_of(&"ruby"))
	if paid < 30:
		return _goods_at(&"ruby")
	var stock: int = 0
	if raid.goods != null:
		stock = raid.goods.stock_of(0)
	if stock < 1:
		return _goods_at(&"rare")
	return Vector3.INF

func _goods_at(id: StringName) -> Vector3:
	if goods == null:
		return Vector3.INF
	var i: int = goods.find(id)
	if i < 0:
		return Vector3.INF
	return goods.nodes[i]["pos"] as Vector3

func _duty_at(first: String, second: String) -> Vector3:
	var hit: RTSUnit = _first_duty(first)
	if hit == null and second != "":
		hit = _first_duty(second)
	if hit == null:
		return Vector3.INF
	return hit.global_position

func _first_duty(duty: String) -> RTSUnit:
	for u: RTSUnit in field.units:
		if _living(u) and str(u.get_meta("duty", "")) == duty:
			return u
	return null

func _player_kind(kind: String) -> RTSUnit:
	for u: RTSUnit in field.units_of(SMPointer.PLAYER):
		if _living(u) and str(u.unit_type) == kind:
			return u
	return null

func tick(delta: float) -> bool:
	if done or lost or field == null or ending == "":
		return false
	if raid != null:
		return _tick_raid(delta)
	_occupy(delta)
	_recount()
	_press_enemies()
	_help_powers()
	_watch()
	_lock()
	_hold_tick(delta)
	if not _ready():
		if not _company_alive():
			lost = true
			loss = "the company is wiped"
		elif defend != null and not _living(defend):
			lost = true
			loss = "the defended target is lost"
		return false
	done = true
	return true

func _tick_raid(delta: float) -> bool:
	if raid.won:
		done = true
		return false
	_occupy(delta)
	_press_enemies()
	if goods != null:
		goods.advance(delta, raid.economy)
		raid.ruby_paid = goods.paid_of(&"ruby")
	if side != null and side.yard.finished.has(&"scaffold_yard") and not raid.yard.finished.has(&"scaffold_yard"):
		raid.yard.finished.append(&"scaffold_yard")
		raid.yard.drained = maxi(raid.yard.drained, 1)
	if not _company_alive():
		lost = true
		loss = "the company is wiped"
		return false
	if not raid.try_win():
		return false
	done = true
	return true

func _occupy(delta: float) -> void:
	for u: RTSUnit in field.units_of(SMPointer.PLAYER):
		if not _living(u):
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
	if not _company_alive():
		return false
	if _ruby and goods != null and raid == null:
		return goods.night_on(&"ruby") and goods.paid_of(&"ruby") >= 30 and _cleared("clear")
	if _cyber and tech != null:
		return tech.owner_of(&"compound") == SMPointer.PLAYER and tech.siphon_of(&"compound") > 0 and _cleared("clear")
	if _radar and tech != null:
		if not tech.reveals_water(SMPointer.PLAYER) or not _cleared("clear"):
			return false
		if _haze and not _haze_ok():
			return false
		if _hold:
			return hold_left <= 0.0
		return true
	if _cross:
		return _crossed() and _cleared("clear")
	if _packer and sail != null:
		return sail.factory_level(&"gun_wharf") == 2 and sail.grid.unit_domain(sail.packer_id) == SMDomainGrid.Domain.SHALLOW and _cleared("clear")
	if _kill and ew != null:
		var foe: RTSUnit = _first_enemy()
		var dead: bool = foe == null or not foe.is_alive()
		return dead and ew.accuracy(ew.center, SMEwField.GPS) < 1.0 and ew.accuracy(ew.center, SMEwField.FIBER) == 1.0
	if _beam:
		return _beamed and _phantom_frozen and _cleared("phantom") and _cleared("battery")
	if _towers:
		return _cleared("tower") and _cleared("hangar")
	if _fleet:
		return _cleared("fleet")
	if _column:
		return _cleared("column") and _column_need > 0 and _column_frozen >= _column_need
	if _hold:
		return hold_left <= 0.0 and _living(defend)
	if _supers:
		return _cleared("super")
	return false

func _hold_tick(delta: float) -> void:
	if not _hold or delta <= 0.0 or not _company_alive():
		return
	if defend != null and not _living(defend):
		return
	if (_radar or _haze) and (tech == null or not tech.reveals_water(SMPointer.PLAYER)):
		return
	if _haze and not _haze_ok():
		return
	hold_left = maxf(0.0, hold_left - delta)

func _haze_ok() -> bool:
	return sight != null and sight.weather_name == "Strait Haze" and sight.unit_radius(false) < SMSight.UNIT_RADIUS and is_equal_approx(sight.unit_radius(true), SMSight.UNIT_RADIUS)

func _crossed() -> bool:
	for u: RTSUnit in field.units_of(SMPointer.PLAYER):
		if _living(u) and str(u.get_meta("locomotion", "")) == "amphibious" and u.global_position.x > 8.0:
			return true
	return false

func _beam_done() -> bool:
	for u: RTSUnit in field.units_of(SMPointer.PLAYER):
		if _living(u) and int(u.get_meta("beam_done", 0)) >= 1:
			return true
	return false

func _help_powers() -> void:
	if protocols == null:
		return
	if protocols.damage_mult > 1.0:
		for u: RTSUnit in field.units_of(SMPointer.PLAYER):
			if _living(u) and u.damage_mult < protocols.damage_mult:
				u.damage_mult = protocols.damage_mult
	if protocols.swarm_count == 23 and not _swarm_used:
		_swarm_used = true
		_hurt_duty("tower", 70.0)
		_hurt_duty("hangar", 70.0)
	if protocols.napalm == 36 and not _napalm_used:
		_napalm_used = true
		_hurt_duty("fleet", 80.0)
	if protocols.defoliation and not _defoliation_used:
		_defoliation_used = true
		_freeze_duty("column", 8.0)
	if protocols.cryo_wave and not _cryo_used:
		_cryo_used = true
		_freeze_duty("trimaran", 8.0)
	if protocols.credits_bonus == 250 and is_equal_approx(protocols.damage_mult, 1.5) and protocols.cryo_applied and not _trio_used:
		_trio_used = true
		_freeze_duty("super", 4.0)
		_hurt_duty("super", 60.0)

func _watch() -> void:
	if _beam_done():
		_beamed = true
	if _living(_phantom) and bool(_phantom.get_meta("frozen", false)):
		_phantom_frozen = true
	for u: RTSUnit in field.units_of(SMPointer.ENEMY):
		if not _living(u) or str(u.get_meta("duty", "")) != "column":
			continue
		if bool(u.get_meta("frozen", false)):
			u.set_meta("was_frozen", true)
		if bool(u.get_meta("was_frozen", false)) and not bool(u.get_meta("freeze_noted", false)):
			u.set_meta("freeze_noted", true)
			_column_frozen += 1

func _lock() -> void:
	var towers_up: bool = _alive.has("tower") and int(_alive["tower"]) > 0
	for u: RTSUnit in field.units_of(SMPointer.ENEMY):
		if not _living(u):
			continue
		var duty: String = str(u.get_meta("duty", ""))
		if duty == "hangar":
			u.incoming_mult = 0.0 if towers_up else 1.0
		elif duty == "column":
			if bool(u.get_meta("was_frozen", false)):
				if u.incoming_mult <= 0.0:
					u.incoming_mult = 1.0
			else:
				u.incoming_mult = 0.0

func _press_enemies() -> void:
	var prey: RTSUnit = _hunt_target()
	if prey == null:
		return
	for u: RTSUnit in field.units_of(SMPointer.ENEMY):
		if not _living(u) or bool(u.get_meta("frozen", false)):
			continue
		if u.attack_damage <= 0.0:
			continue
		u.attack_target = prey

func _hunt_target() -> RTSUnit:
	if _living(defend):
		return defend
	var best: RTSUnit = null
	var best_d: float = 100000.0
	for u: RTSUnit in field.units_of(SMPointer.PLAYER):
		if not _living(u) or bool(u.get_meta("objective", false)):
			continue
		var d: float = u.global_position.distance_to(Vector3(8.0, 0.0, 0.0))
		if d < best_d:
			best_d = d
			best = u
	return best

func _hurt_duty(duty: String, amount: float) -> void:
	for u: RTSUnit in field.units_of(SMPointer.ENEMY):
		if _living(u) and str(u.get_meta("duty", "")) == duty:
			u.take_damage(amount)

func _freeze_duty(duty: String, duration: float) -> void:
	for u: RTSUnit in field.units_of(SMPointer.ENEMY):
		if _living(u) and str(u.get_meta("duty", "")) == duty and not bool(u.get_meta("frozen", false)):
			field.apply_status(u, "frozen", duration)

func _raid_line() -> String:
	var yard_up: bool = raid.yard.finished.has(&"scaffold_yard")
	var paid: int = raid.ruby_paid
	if goods != null:
		paid = maxi(paid, goods.paid_of(&"ruby"))
	var stock: int = 0
	if raid.goods != null:
		stock = raid.goods.stock_of(0)
	var yard_bit: String = "yard up" if yard_up else "raise the yard"
	var ruby_bit: String = "ruby paid"
	if paid < 30:
		ruby_bit = "ruby night shift %d/30" % paid
	var rare_bit: String = "rare earth home" if stock >= 1 else "bring one rare-earth stock"
	return "Kokang: %s. %s. %s." % [yard_bit, ruby_bit, rare_bit]

func _left(duty: String) -> int:
	if not _alive.has(duty):
		return 0
	return int(_alive[duty])

func _secs() -> int:
	return int(ceil(hold_left))

func _company_alive() -> bool:
	for u: RTSUnit in field.units_of(SMPointer.PLAYER):
		if _living(u) and not bool(u.get_meta("objective", false)):
			return true
	return false

func _near(kind: String, at: Vector3) -> bool:
	for u: RTSUnit in field.units_of(SMPointer.PLAYER):
		if _living(u) and str(u.unit_type) == kind and u.global_position.distance_to(at) <= REACH:
			return true
	return false

func _first_enemy() -> RTSUnit:
	var foes: Array[RTSUnit] = field.units_of(SMPointer.ENEMY)
	if foes.is_empty():
		return null
	return foes[0]

func _living(u: RTSUnit) -> bool:
	return u != null and is_instance_valid(u) and u.is_alive()

func _cleared(duty: String) -> bool:
	if not _alive.has(duty):
		return true
	return int(_alive[duty]) == 0

func _recount() -> void:
	for duty: String in _alive:
		var n: int = 0
		for u: RTSUnit in field.units:
			if _living(u) and str(u.get_meta("duty", "")) == duty:
				n += 1
		_alive[duty] = n

func _mount_protocols(layer: CanvasLayer) -> void:
	protocols = SMProtocols.new()
	abilities = SMAbilities.new()
	abilities.add_unit(10, Vector3(6.0, 0.0, 3.0), SMAbilities.TOGGLE, 1.0, 1.0)
	protocols.mount_panel(layer, roster.economy, 0, abilities, Callable(host, "_say"))

func _tag_raider(duty: String, label: String, hp: float, speed: float, damage: float, count: bool) -> void:
	var foe: RTSUnit = _first_enemy()
	if foe == null:
		return
	_paint(foe, duty, label, hp, speed, damage)
	if count:
		_note(duty)

func _move_raider(at: Vector3) -> void:
	var foe: RTSUnit = _first_enemy()
	if foe != null:
		foe.global_position = at

func _spawn_duty(team: int, at: Vector3, kind: StringName, duty: String, label: String, hp: float, speed: float, damage: float, count: bool) -> RTSUnit:
	var u: RTSUnit = field.spawn(team, at, kind)
	_paint(u, duty, label, hp, speed, damage)
	if count:
		_note(duty)
	return u

func _paint(u: RTSUnit, duty: String, label: String, hp: float, speed: float, damage: float) -> void:
	if u == null:
		return
	u.max_hp = hp
	u.hp = hp
	u.speed = speed
	u.attack_damage = damage
	u.attack_interval = 1.0
	u.attack_range = 12.0 if speed <= 0.0 else 8.0
	u.set_meta("duty", duty)
	if duty == "hangar" or duty == "column":
		u.incoming_mult = 0.0
	var tag: Label3D = u.get_node_or_null("NameTag") as Label3D
	if tag != null:
		tag.text = label

func _note(duty: String) -> void:
	var have: int = 0
	if _alive.has(duty):
		have = int(_alive[duty])
	_alive[duty] = have + 1
	if duty == "column":
		_column_need += 1

func _pad(at: Vector3, color: Color, node_name: String) -> void:
	_slab(node_name, at + Vector3(0.0, 0.15, 0.0), Vector3(1.6, 0.3, 1.6), color)

func _slab(node_name: String, at: Vector3, size: Vector3, color: Color) -> void:
	pad_made.emit(host, node_name, at, size, color)
