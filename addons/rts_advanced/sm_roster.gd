class_name SMRoster
extends RefCounted
## Trains catalog units through the production queue, then the scene spawns them.

var faction_id: String = ""
var queue: RTSProductionQueue
var economy: RTSEconomy = RTSEconomy.new()

func setup(faction: String) -> void:
	faction_id = faction
	economy = RTSEconomy.new()
	economy.set_credits(0, 50000)
	var cat: Dictionary[StringName, Dictionary] = {}
	for unit: Dictionary in SMCatalog.units_of(SMCatalog.faction(faction)):
		var id: StringName = StringName(str(unit.get("id", "")))
		var row: Dictionary = {}
		row["cost"] = int(unit.get("cost", 0))
		row["time"] = float(unit.get("time", 1.0))
		cat[id] = row
	queue = RTSProductionQueue.new(0, cat)

func train(id: StringName) -> bool:
	if queue == null:
		return false
	return queue.enqueue(id, economy)

func finish_head() -> StringName:
	if queue == null or queue.items.is_empty():
		return &""
	var id: StringName = queue.items[0]
	var need: float = float(queue.catalog[id]["time"]) + 0.01
	if queue.advance(need) <= 0:
		return &""
	return id

func train_and_finish(id: StringName) -> StringName:
	if not train(id):
		return &""
	return finish_head()
