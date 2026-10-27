class_name SMMission
extends RefCounted
## Solo GTFC night raid. Text briefing stands in for a film.

var briefing: String = "Kokang and Mogok night raid. Raise the scaffold yard, run the ruby pits on night shift, and bring one rare-earth stock home before dawn. If the company dies, the raid fails."
var economy: RTSEconomy = RTSEconomy.new()
var yard: SMBuildYard = SMBuildYard.new()
var goods: SMCommodityNet = SMCommodityNet.new()
var won: bool = false
var ruby_paid: int = 0

func setup() -> void:
	won = false
	ruby_paid = 0
	economy = RTSEconomy.new()
	economy.set_credits(0, 2000)
	yard = SMBuildYard.new()
	yard.style = SMBuildYard.Style.SCAFFOLD
	yard.team = 0
	yard.economy = economy
	yard.center = Vector3.ZERO
	yard.radius = 16.0
	yard.drain_per_sec = 4
	yard.tech_order = [&"scaffold_yard"]
	yard.building_time[&"scaffold_yard"] = 3.0
	yard.building_tier[&"scaffold_yard"] = 1
	goods = SMCommodityNet.new()
	goods.add_node(&"ruby", SMCommodityNet.KIND_RUBY, Vector3(6.0, 0.0, 2.0), 30, false)
	goods.add_node(&"rare", SMCommodityNet.KIND_RARE, Vector3(-6.0, 0.0, 4.0), 0, true)

func raise_scaffold() -> bool:
	if yard.finished.has(&"scaffold_yard"):
		return true
	if not yard.scaffold_active:
		if not yard.begin_scaffold(&"scaffold_yard", Vector3(2.0, 0.0, 0.0), 250.0):
			return false
	yard.advance(3.0)
	return yard.finished.has(&"scaffold_yard") and yard.drained > 0

func run_night_ruby() -> bool:
	var idx: int = goods.find(&"ruby")
	if idx < 0:
		return false
	if int(goods.nodes[idx]["team"]) < 0 and not goods.snap_refinery(&"ruby", 0):
		return false
	if not goods.set_night_shift(&"ruby", true):
		return false
	var before: int = economy.credits(0)
	goods.advance(2.0, economy)
	ruby_paid = economy.credits(0) - before
	return ruby_paid >= 30 and goods.visible_through_fog(&"ruby")

func day_ruby_slower() -> bool:
	var probe: SMCommodityNet = SMCommodityNet.new()
	var econ: RTSEconomy = RTSEconomy.new()
	probe.add_node(&"ruby", SMCommodityNet.KIND_RUBY, Vector3.ZERO, 30, false)
	probe.snap_refinery(&"ruby", 0)
	var paid: int = probe.advance(2.0, econ)
	return paid == 0

func secure_rare() -> bool:
	var idx: int = goods.find(&"rare")
	if idx < 0:
		return false
	if int(goods.nodes[idx]["team"]) < 0 and not goods.snap_refinery(&"rare", 0):
		return false
	goods.advance(4.0, economy)
	return goods.stock_of(0) >= 1

func try_win() -> bool:
	won = yard.finished.has(&"scaffold_yard") and ruby_paid >= 30 and goods.stock_of(0) >= 1
	return won

func playthrough() -> bool:
	setup()
	if briefing == "":
		return false
	if not raise_scaffold():
		return false
	if not run_night_ruby():
		return false
	if not day_ruby_slower():
		return false
	if not secure_rare():
		return false
	return try_win()
