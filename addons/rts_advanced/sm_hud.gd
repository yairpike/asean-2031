class_name SMHud
extends RefCounted
## In-match readout. Primitive controls and a flat minimap. No map mesh, no art.

var field: SMPointer
var roster: SMRoster
var side: SMSide
var map_name: String = ""
var rally: Vector3 = Vector3.ZERO
var on_ability: Callable
var faction_label: Label
var credits_label: Label
var power_label: Label
var map_label: Label
var weather_label: Label
var selection_label: Label
var build_label: Label
var minimap: SMMinimap

func mount(layer: CanvasLayer, p_field: SMPointer, p_roster: SMRoster, p_side: SMSide, p_map: String, p_rally: Vector3, ability: Callable, grid: SMDomainGrid, camera: RTSCamera) -> void:
	field = p_field
	roster = p_roster
	side = p_side
	map_name = p_map
	rally = p_rally
	on_ability = ability
	var top: Control = Control.new()
	top.name = "TopBar"
	top.position = Vector2(0, 0)
	top.size = Vector2(1280, 40)
	layer.add_child(top)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.05, 0.06, 0.07, 0.92)
	shade.position = Vector2(0, 0)
	shade.size = Vector2(1280, 40)
	top.add_child(shade)
	faction_label = _label(top, "HudFaction", Vector2(16, 8), 18)
	credits_label = _label(top, "HudCredits", Vector2(180, 8), 18)
	power_label = _label(top, "HudPower", Vector2(460, 8), 18)
	map_label = _label(top, "HudMap", Vector2(700, 8), 18)
	weather_label = _label(top, "HudWeather", Vector2(980, 8), 16)
	minimap = SMMinimap.new()
	minimap.name = "Minimap"
	minimap.position = Vector2(12, 48)
	minimap.setup(grid, field, camera)
	layer.add_child(minimap)
	build_label = _label(layer, "HudBuild", Vector2(240, 608), 15)
	build_label.custom_minimum_size = Vector2(760, 24)
	selection_label = _label(layer, "HudSelection", Vector2(16, 648), 16)
	selection_label.custom_minimum_size = Vector2(980, 28)
	_column(layer)
	refresh()

func use_sight(p_sight: SMSight) -> void:
	if minimap != null:
		minimap.sight = p_sight

func use_goods(p_goods: SMCommodityNet) -> void:
	if minimap != null:
		minimap.goods = p_goods

func refresh() -> void:
	if faction_label == null:
		return
	faction_label.text = _faction_name(_faction_id())
	var purse: int = 0
	if roster != null and roster.economy != null:
		purse = roster.economy.credits(0)
	credits_label.text = "Credits %d" % purse
	power_label.text = "Power %d" % _power()
	map_label.text = map_name
	if weather_label != null:
		var sky: String = "Clear"
		if minimap != null and minimap.sight != null:
			sky = minimap.sight.weather_name
		weather_label.text = sky
	selection_label.text = _selection_line()
	if minimap != null:
		minimap.sample()
		minimap.queue_redraw()

func _column(layer: CanvasLayer) -> void:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "CommandColumn"
	scroll.position = Vector2(1032, 44)
	scroll.size = Vector2(240, 600)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layer.add_child(scroll)
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "Sidebar"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(220, 0)
	box.add_theme_constant_override("separation", 4)
	scroll.add_child(box)
	_header(box, "GroupBuildings", "Buildings")
	var data: Dictionary = SMCatalog.faction(_faction_id())
	var raw: Variant = data.get("buildings", [])
	if raw is Array:
		for item: Variant in raw:
			if item is Dictionary:
				var id: StringName = StringName(str(item.get("id", "")))
				if str(id) == "":
					continue
				var node_name: String = "MovePacker" if str(id) == "packer" else "Build_%s" % str(id)
				_button(box, node_name, _pretty(str(id)), _order.bind(id))
	_header(box, "GroupUnits", "Units")
	for unit: Dictionary in SMCatalog.units_of(data):
		var uid: StringName = StringName(str(unit.get("id", "")))
		if str(uid) == "":
			continue
		var caption: String = str(unit.get("display_name", str(uid)))
		_button(box, "Train_%s" % str(uid), caption, _train.bind(uid))
	_header(box, "GroupAbility", "Ability")
	_button(box, "AbilityButton", "Ability (F)", _ability)

func _order(id: StringName) -> void:
	if side == null:
		return
	var note: String = side.order_building(id)
	if build_label != null:
		build_label.text = note
	refresh()

func _train(id: StringName) -> void:
	if roster == null or field == null:
		return
	var done: StringName = roster.train_and_finish(id)
	if done == &"":
		if build_label != null:
			build_label.text = "cannot train"
		refresh()
		return
	var at: Vector3 = rally + Vector3(6.0 + float(field.count_team(SMPointer.PLAYER) % 4) * 2.0, 0.0, 2.0)
	var u: RTSUnit = field.spawn(SMPointer.PLAYER, at, done)
	if build_label != null:
		build_label.text = field.name_of(u)
	refresh()

func _ability() -> void:
	if on_ability.is_valid():
		on_ability.call()
	refresh()

func _power() -> int:
	if field == null:
		return 0
	var total: int = 0
	for u: RTSUnit in field.units_of(SMPointer.PLAYER):
		total += int(round(u.attack_damage))
	return total

func _selection_line() -> String:
	if field == null or field.selection.count() <= 0:
		return "Nothing selected"
	var first: RTSUnit = field.selection.units[0]
	var extra: int = field.selection.count() - 1
	var ability: String = "ability"
	if first.has_meta("secondary"):
		ability = _ability_name(str(first.get_meta("secondary")))
	var line: String = "%s    HP %d/%d    F %s" % [field.name_of(first), int(round(first.hp)), int(round(first.max_hp)), ability]
	if extra > 0:
		line += "    +%d" % extra
	return line

func _faction_id() -> String:
	if roster != null and roster.faction_id != "":
		return roster.faction_id
	return SMFront.current()

func _faction_name(id: String) -> String:
	if id == "nmrf":
		return "NMRF"
	if id == "mvd":
		return "MVD"
	return "GTFC"

func _ability_name(kind: String) -> String:
	if kind == "group_toggle":
		return "group toggle"
	if kind == "smart_cast":
		return "smart-cast"
	if kind == "channeled_beam":
		return "beam"
	return "ability"

func _pretty(id: String) -> String:
	var parts: PackedStringArray = id.split("_")
	var words: PackedStringArray = PackedStringArray()
	for part: String in parts:
		if part == "":
			continue
		words.append(part.capitalize())
	return " ".join(words)

func _header(box: VBoxContainer, node_name: String, text: String) -> void:
	var label: Label = Label.new()
	label.name = node_name
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.9, 0.78, 0.45))
	box.add_child(label)

func _button(box: VBoxContainer, node_name: String, text: String, fn: Callable) -> void:
	var b: Button = Button.new()
	b.name = node_name
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(200, 28)
	b.add_theme_font_size_override("font_size", 14)
	b.pressed.connect(fn)
	box.add_child(b)

func _label(parent: Node, node_name: String, pos: Vector2, size: int) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.position = pos
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.93, 0.94, 0.96))
	parent.add_child(label)
	return label
