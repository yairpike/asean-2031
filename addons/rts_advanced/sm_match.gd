class_name SMMatch
extends RefCounted
## Headless match: faction pipeline, channel crossing, abilities, passive enemy, bots.

var economy: RTSEconomy = RTSEconomy.new()
var grid: SMDomainGrid
var yard: SMBuildYard
var goods: SMCommodityNet = SMCommodityNet.new()
var tech: SMTechNet = SMTechNet.new()
var abilities: SMAbilities = SMAbilities.new()
var ew: SMEwField = SMEwField.new()
var protocols: SMProtocols = SMProtocols.new()
var audio: SMAudioDirector = SMAudioDirector.new()
var player: int = 0
var enemy: int = 1
var enemy_hp: float = 50.0
var finished: bool = false
var winner: int = -1
var domain_log: Array[int] = []
var trained: Array[StringName] = []
var f_smart: int = -1
var f_toggles: int = 0
var pipeline_ok: bool = false
var claimed: bool = false
var faction_id: String = "gtfc"

func setup_phillips(faction: String = "gtfc") -> void:
	faction_id = faction
	economy.set_credits(player, 5000)
	economy.set_credits(enemy, 200)
	grid = SMDomainGrid.phillips_layout()
	grid.domain_changed.connect(_on_domain)
	yard = SMBuildYard.new()
	yard.style = SMBuildYard.Style.SCAFFOLD
	yard.team = player
	yard.economy = economy
	yard.center = grid.cell_center(Vector2i(6, 12))
	yard.radius = 22.0
	yard.drain_per_sec = 5
	yard.tech_order = [&"scaffold_yard", &"barracks"]
	yard.building_time[&"scaffold_yard"] = 4.0
	yard.building_time[&"barracks"] = 3.0
	yard.building_tier[&"scaffold_yard"] = 1
	yard.building_tier[&"barracks"] = 1
	goods = SMCommodityNet.new()
	goods.add_node(&"slag_west", SMCommodityNet.KIND_SLAG, grid.cell_center(Vector2i(8, 8)), 20, false)
	goods.add_node(&"rare_shore", SMCommodityNet.KIND_RARE, grid.cell_center(Vector2i(13, 12)), 0, true)
	goods.add_node(&"ruby_east", SMCommodityNet.KIND_RUBY, grid.cell_center(Vector2i(30, 8)), 15, false)
	goods.add_node(&"jade_west", SMCommodityNet.KIND_JADE, grid.cell_center(Vector2i(5, 18)), 15, false)
	goods.add_node(&"bullion_east", SMCommodityNet.KIND_BULLION, grid.cell_center(Vector2i(32, 16)), 25, false)
	tech = SMTechNet.new()
	tech.add_site(&"cyber", SMTechNet.CYBER, grid.cell_center(Vector2i(28, 18)))
	abilities = SMAbilities.new()
	ew = SMEwField.new()
	ew.center = grid.cell_center(Vector2i(10, 6))
	ew.radius = 10.0
	protocols = SMProtocols.new()
	audio = SMAudioDirector.new()
	domain_log.clear()
	trained.clear()
	f_smart = -1
	f_toggles = 0
	pipeline_ok = false
	claimed = false
	finished = false
	winner = -1
	enemy_hp = 50.0

func _on_domain(_unit_id: int, from_domain: int, to_domain: int) -> void:
	domain_log.append(from_domain)
	domain_log.append(to_domain)

func has_two_lands() -> bool:
	if grid == null:
		return false
	var west: int = grid.domain_at_cell(Vector2i(8, 4))
	var east: int = grid.domain_at_cell(Vector2i(30, 12))
	var deep: int = grid.domain_at_cell(Vector2i(20, 12))
	var shallow: int = grid.domain_at_cell(Vector2i(16, 5))
	return west == SMDomainGrid.Domain.LAND and east == SMDomainGrid.Domain.LAND and deep == SMDomainGrid.Domain.DEEP and shallow == SMDomainGrid.Domain.SHALLOW

func run_player_pipeline() -> bool:
	if yard == null:
		return false
	if not yard.begin_scaffold(&"scaffold_yard", yard.center, 300.0):
		return false
	yard.advance(4.0)
	if yard.vulnerable or not yard.finished.has(&"scaffold_yard"):
		return false
	if yard.drained <= 0:
		return false
	if not yard.can_build(&"barracks"):
		return false
	if not yard.begin_scaffold(&"barracks", yard.center + Vector3(4.0, 0.0, 0.0), 200.0):
		return false
	yard.advance(3.0)
	if not yard.finished.has(&"barracks"):
		return false
	if not goods.snap_refinery(&"slag_west", player):
		return false
	claimed = goods.has_collector(&"slag_west")
	goods.advance(4.0, economy)
	trained.append(&"channel_skiff")
	trained.append(&"militia")
	trained.append(&"ruby_lancer")
	abilities.add_unit(10, yard.center, SMAbilities.TOGGLE, 2.0, 0.6)
	abilities.add_unit(11, yard.center + Vector3(2.0, 0.0, 0.0), SMAbilities.SMART, 3.0, 0.6)
	abilities.add_unit(12, yard.center + Vector3(8.0, 0.0, 1.0), SMAbilities.SMART, 3.0, 0.6)
	pipeline_ok = claimed and goods.paid_of(&"slag_west") > 0
	return pipeline_ok

func cross_channel() -> bool:
	var pts: Array[Vector3] = [
		grid.cell_center(Vector2i(12, 5)),
		grid.cell_center(Vector2i(16, 5)),
		grid.cell_center(Vector2i(22, 5)),
		grid.cell_center(Vector2i(26, 5)),
	]
	for p: Vector3 in pts:
		if not grid.move_unit(12, p, SMDomainGrid.Loco.AMPHIBIOUS):
			return false
	var deep: Vector3 = grid.cell_center(Vector2i(20, 12))
	if grid.move_unit(99, deep, SMDomainGrid.Loco.GROUND):
		return false
	return domain_log.size() >= 2 and grid.unit_domain(12) == SMDomainGrid.Domain.LAND

func use_f() -> bool:
	var ids: Array[int] = [10, 11, 12]
	var aim: Vector3 = yard.center + Vector3(2.0, 0.0, 0.0)
	f_toggles = abilities.group_toggle(ids)
	f_smart = abilities.smart_cast(ids, aim)
	return f_toggles == 1 and f_smart == 11 and abilities.fired_count(12) == 0

func fight_passive() -> bool:
	audio.set_combat(true)
	var guard: int = 0
	while enemy_hp > 0.0 and guard < 20:
		enemy_hp -= 10.0 * protocols.damage_mult
		audio.advance(0.5)
		guard += 1
	if enemy_hp <= 0.0:
		finished = true
		winner = player
		return true
	return false

func script_phillips() -> bool:
	setup_phillips(faction_id if faction_id != "" else "gtfc")
	if not has_two_lands():
		return false
	if not run_player_pipeline():
		return false
	if not cross_channel():
		return false
	if not use_f():
		return false
	return fight_passive()

func run_bot(bot: SMBot) -> Dictionary:
	economy.set_credits(player, 4000)
	economy.set_credits(enemy, 80)
	grid = SMDomainGrid.phillips_layout()
	goods = SMCommodityNet.new()
	goods.add_node(&"a", SMCommodityNet.KIND_SLAG, grid.cell_center(Vector2i(4, 4)), 10, false)
	goods.add_node(&"b", SMCommodityNet.KIND_BULLION, grid.cell_center(Vector2i(8, 6)), 10, false)
	goods.add_node(&"w", SMCommodityNet.KIND_RARE, grid.cell_center(Vector2i(13, 5)), 0, true)
	goods.add_node(&"g", SMCommodityNet.KIND_RUBY, grid.cell_center(Vector2i(6, 16)), 12, false)
	tech = SMTechNet.new()
	tech.add_site(&"site", bot.tech_kind, grid.cell_center(Vector2i(7, 8)))
	abilities = SMAbilities.new()
	protocols = SMProtocols.new()
	audio = SMAudioDirector.new()
	var refineries: int = 0
	if goods.snap_refinery(&"a", player):
		refineries += 1
	if goods.snap_refinery(&"b", player):
		refineries += 1
	var water: bool = goods.snap_refinery(&"w", player)
	var gem: bool = goods.snap_refinery(&"g", player)
	var night: bool = goods.set_night_shift(&"g", true)
	var captured: bool = tech.capture(&"site", player)
	var fired: bool = false
	var frozen: bool = false
	var naval: bool = false
	var flew: bool = false
	if bot.ability == &"smart_cast":
		abilities.add_unit(1, Vector3.ZERO, SMAbilities.SMART, 1.0, 0.5)
		abilities.add_unit(2, Vector3(10.0, 0.0, 0.0), SMAbilities.SMART, 1.0, 0.5)
		fired = abilities.smart_cast([1, 2], Vector3.ZERO) == 1 and abilities.fired_count(2) == 0
	elif bot.ability == &"channeled_beam":
		abilities.add_unit(1, Vector3.ZERO, SMAbilities.BEAM, 1.0, 0.5)
		abilities.add_unit(2, Vector3(3.0, 0.0, 0.0), SMAbilities.TOGGLE, 1.0, 0.5)
		fired = abilities.begin_beam(1, 2)
		abilities.advance(2.0)
		frozen = abilities.status_of(2) == SMAbilities.ST_FROZEN
	if bot.personality == &"iskandar":
		naval = grid.move_unit(7, grid.cell_center(Vector2i(20, 12)), SMDomainGrid.Loco.NAVAL)
	if bot.personality == &"tran":
		flew = grid.move_unit(8, grid.cell_center(Vector2i(19, 10)), SMDomainGrid.Loco.AIR)
		frozen = frozen or abilities.status_of(2) == SMAbilities.ST_FROZEN
	if bot.personality == &"bo_mya":
		var drone_cost: int = int(roundf(100.0 * tech.discount(player, "drone")))
		fired = fired and drone_cost == 70
	audio.set_combat(true)
	audio.advance(1.1)
	var target: int = 2 if abilities.index_of(2) >= 0 else -1
	var proto: bool = protocols.cast(&"logistics", economy, player, abilities, target)
	proto = protocols.cast(&"arsenal", economy, player, abilities, target) and proto
	proto = protocols.cast(&"oracle", economy, player, abilities, target) and proto
	proto = proto and not protocols.can_cast(&"logistics")
	if bot.personality == &"tran":
		frozen = abilities.status_of(2) == SMAbilities.ST_FROZEN or protocols.cryo_applied
	return {
		"refineries": refineries,
		"water": water,
		"gem": gem and night,
		"captured": captured,
		"fired": fired,
		"frozen": frozen,
		"naval": naval,
		"flew": flew,
		"protocols": proto,
		"audio_combat": audio.stem == &"combat" and audio.combat > audio.exploration,
		"silent": audio.silent_placeholder,
		"faction": bot.faction_id,
		"refinery_target": bot.refinery_target,
	}
