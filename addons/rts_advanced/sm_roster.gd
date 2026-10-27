class_name SMRoster
extends RefCounted
## Trains catalog units through the production queue, then the scene spawns them.

var faction_id: String = ""
var queue: RTSProductionQueue
var economy: RTSEconomy = RTSEconomy.new()
## Optional (id) -> price multiplier. A captured bazaar discounts infantry and drones.
var price_scale: Callable

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

func unit_tag(id: StringName) -> String:
	for unit: Dictionary in SMCatalog.units_of(SMCatalog.faction(faction_id)):
		if str(unit.get("id", "")) != str(id):
			continue
		var raw: Variant = unit.get("tags", [])
		if raw is Array:
			for item: Variant in raw:
				var tag: String = str(item)
				if tag == "drone" or tag == "infantry":
					return tag
	return ""

func train(id: StringName) -> bool:
	if queue == null:
		return false
	if not queue.enqueue(id, economy):
		return false
	if price_scale.is_valid():
		var mult: float = float(price_scale.call(id))
		if mult > 0.0 and mult < 1.0:
			var cost: int = int(queue.catalog[id]["cost"])
			var refund: int = cost - int(roundf(float(cost) * mult))
			if refund > 0:
				economy.earn(0, refund)
	return true

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
