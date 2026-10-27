class_name SMHud
extends RefCounted
## In-match readout. Primitive controls and a flat minimap. No map mesh, no art.

var field: SMPointer
var roster: SMRoster
var side: SMSide
var tech: SMTechNet
var sidebar: VBoxContainer
var imports_ready: bool = false
var map_name: String = ""
var rally: Vector3 = Vector3.ZERO
var on_ability: Callable
var faction_label: Label
var credits_label: Label
var income_label: Label
var power_label: Label
var map_label: Label
var weather_label: Label
var selection_label: Label
var build_label: Label
var minimap: SMMinimap
var sfx: SMSfx
var guide_panel: Control
var tutorial_label: Label
var tip_panel: Control
var tip_label: Label
var hover_tip: String = ""
var radio_label: Label
var radio_until: int = 0
var purse_mark: int = -1
var purse_ms: int = 0
var purse_rate: int = 0
var purse_window: float = 0.0
var purse_gained: int = 0
var purse_flash: String = ""
var purse_flash_t: float = 0.0

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
	income_label = _label(top, "HudIncome", Vector2(340, 10), 15)
	income_label.add_theme_color_override("font_color", Color(0.55, 0.9, 0.48))
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
	_guide(layer)
	_tip(layer)
	sfx = SMSfx.new()
	sfx.mount(layer)
	if field != null:
		field.on_cue = Callable(sfx, "play")
		field.on_line = Callable(self, "show_line")
		field.on_bark = Callable(sfx, "bark")
	layer.set_meta("hud", self)
	if field != null:
		field.place_rally(rally)
	refresh()

func use_sight(p_sight: SMSight) -> void:
	if minimap != null:
		minimap.sight = p_sight

func use_tech(p_tech: SMTechNet) -> void:
	tech = p_tech

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
	_measure_purse()
	credits_label.text = "Credits %d" % purse
	power_label.text = "Power %d" % _power()
	map_label.text = map_name
	if weather_label != null:
		var sky: String = "Clear"
		if minimap != null and minimap.sight != null:
			sky = minimap.sight.weather_name
		weather_label.text = sky
	selection_label.text = _selection_line()
	_sync_imports()
	_paint_tip()
	_paint_radio()
	if minimap != null:
		minimap.sample()
		minimap.queue_redraw()

func set_rally(at: Vector3) -> void:
	if at == Vector3.INF:
		return
	rally = at
	if field != null:
		field.place_rally(at)
	if build_label != null:
		build_label.text = "Rally set"

func _measure_purse() -> void:
	var now: int = Time.get_ticks_msec()
	var dt: float = 0.0
	if purse_ms > 0:
		dt = clampf(float(now - purse_ms) / 1000.0, 0.0, 1.0)
	purse_ms = now
	_apply_purse(dt)

func _apply_purse(delta: float) -> void:
	if roster == null or roster.economy == null:
		return
	var now_credits: int = roster.economy.credits(0)
	if purse_mark < 0:
		purse_mark = now_credits
		return
	var gain: int = now_credits - purse_mark
	purse_mark = now_credits
	if gain > 0:
		purse_gained += gain
		purse_flash = "+%d" % gain
		purse_flash_t = 1.4
	elif purse_flash_t > 0.0:
		purse_flash_t = maxf(0.0, purse_flash_t - delta)
	purse_window += maxf(delta, 0.0)
	if purse_window >= 1.0:
		purse_rate = int(round(float(purse_gained) / purse_window))
		purse_gained = 0
		purse_window = 0.0
	_paint_income()

func _paint_income() -> void:
	if income_label == null:
		return
	var rate: String = "+%d/s" % purse_rate if purse_rate > 0 else ""
	if rate != "" and purse_flash_t > 0.0 and purse_flash != "":
		income_label.text = "%s  %s" % [rate, purse_flash]
	elif rate != "":
		income_label.text = rate
	elif purse_flash_t > 0.0:
		income_label.text = purse_flash
	else:
		income_label.text = ""

func show_line(text: String) -> void:
	if radio_label == null:
		return
	radio_label.text = text
	radio_label.visible = text != ""
	radio_until = Time.get_ticks_msec() + 2800

func _paint_radio() -> void:
	if radio_label == null or not radio_label.visible:
		return
	if Time.get_ticks_msec() > radio_until:
		radio_label.visible = false

func set_tutorial(text: String) -> void:
	if tutorial_label == null:
		return
	tutorial_label.text = text
	tutorial_label.visible = text != ""
	if text != "" and guide_panel != null:
		guide_panel.visible = true

static func present_tip(host: Node, text: String) -> void:
	if host == null or not host.has_meta("hud"):
		return
	var hud: SMHud = host.get_meta("hud") as SMHud
	if hud == null:
		return
	hud.hover_tip = text
	hud._paint_tip()

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
	sidebar = box
	_header(box, "HudTitle", "ASEAN 2031")
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
				var caption: String = side.building_label(id) if side != null else _pretty(str(id))
				var row: Dictionary = item
				_button(box, node_name, caption, _order.bind(id), SMGuide.building_tip(row), "ui")
	if side != null and side.yard.super_name != "":
		var super_tip: String = "%s. Area hit, then it cools down." % side.yard.super_name
		_button(box, "Super_%s" % str(side.yard.super_id), side.yard.super_name, _super, super_tip, "ability")
	_header(box, "GroupUnits", "Units")
	for unit: Dictionary in SMCatalog.units_of(data):
		var uid: StringName = StringName(str(unit.get("id", "")))
		if str(uid) == "":
			continue
		var caption: String = str(unit.get("display_name", str(uid)))
		_button(box, "Train_%s" % str(uid), caption, _train.bind(uid), SMGuide.unit_tip(unit), "ui")
	_header(box, "GroupAbility", "Ability")
	_button(box, "AbilityButton", "Ability (F)", _ability, SMGuide.ability_tip(), "ability")

func _super() -> void:
	if side == null or field == null:
		return
	var hit: int = side.fire_super(field)
	if build_label != null:
		build_label.text = side.yard.super_name if hit > 0 else "superweapon cooling"
	refresh()

func _order(id: StringName) -> void:
	if side == null:
		return
	var note: String = side.order_building(id)
	if build_label != null:
		build_label.text = note
	refresh()

func _sync_imports() -> void:
	if sidebar == null:
		return
	var open: bool = tech != null and tech.holds(SMTechNet.BAZAAR, SMPointer.PLAYER)
	if open and not imports_ready:
		_header(sidebar, "GroupImports", "Black Market")
		for unit: Dictionary in SMCatalog.units_of(SMCatalog.faction("black_market")):
			var uid: StringName = StringName(str(unit.get("id", "")))
			if str(uid) == "":
				continue
			var caption: String = str(unit.get("display_name", str(uid)))
			_button(sidebar, "Import_%s" % str(uid), caption, _import.bind(uid), SMGuide.unit_tip(unit), "ui")
		imports_ready = true
	var header: Node = sidebar.get_node_or_null("GroupImports")
	if header != null:
		header.visible = open
	if not imports_ready:
		return
	for child: Node in sidebar.get_children():
		if str(child.name).begins_with("Import_"):
			(child as CanvasItem).visible = open

func _import(id: StringName) -> void:
	if roster == null or field == null or tech == null or not tech.holds(SMTechNet.BAZAAR, SMPointer.PLAYER):
		if build_label != null:
			build_label.text = "bazaar required"
		refresh()
		return
	var cost: int = 0
	var row: Dictionary = {}
	for unit: Dictionary in SMCatalog.units_of(SMCatalog.faction("black_market")):
		if str(unit.get("id", "")) == str(id):
			row = unit
			cost = int(unit.get("cost", 0))
	if row.is_empty() or not roster.economy.try_spend(SMPointer.PLAYER, cost):
		if build_label != null:
			build_label.text = "cannot import"
		refresh()
		return
	var at: Vector3 = rally + Vector3(6.0 + float(field.count_team(SMPointer.PLAYER) % 4) * 2.0, 0.0, 2.0)
	var u: RTSUnit = field.spawn(SMPointer.PLAYER, at, id)
	if build_label != null:
		build_label.text = field.name_of(u)
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
	var base: String = "Nothing selected"
	if field != null and field.selection.count() > 0:
		var first: RTSUnit = field.selection.units[0]
		var extra: int = field.selection.count() - 1
		var ability: String = "ability"
		if first.has_meta("ability") and str(first.get_meta("ability")) != "":
			ability = str(first.get_meta("ability"))
		elif first.has_meta("secondary"):
			ability = _ability_name(str(first.get_meta("secondary")))
		base = "%s    HP %d/%d    F %s" % [field.name_of(first), int(round(first.hp)), int(round(first.max_hp)), ability]
		if extra > 0:
			base += "    +%d" % extra
	if field != null and field.group_note_t > 0.0 and field.group_note != "":
		if base == "Nothing selected":
			return field.group_note
		return "%s    %s" % [base, field.group_note]
	return base

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
	label.theme_type_variation = "Header"
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.9, 0.78, 0.45))
	box.add_child(label)

func _guide(layer: CanvasLayer) -> void:
	var help: Button = Button.new()
	help.name = "HelpButton"
	help.text = "How to play (H)"
	help.position = Vector2(16, 216)
	help.custom_minimum_size = Vector2(200, 32)
	help.add_theme_font_size_override("font_size", 15)
	help.pressed.connect(_toggle_guide)
	layer.add_child(help)
	var hint: Label = Label.new()
	hint.name = "ControlsHint"
	hint.text = SMGuide.controls_hint()
	hint.position = Vector2(224, 672)
	hint.custom_minimum_size = Vector2(780, 44)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.96, 0.94, 0.86))
	layer.add_child(hint)
	radio_label = Label.new()
	radio_label.name = "RadioLine"
	radio_label.visible = false
	radio_label.position = Vector2(224, 46)
	radio_label.custom_minimum_size = Vector2(760, 28)
	radio_label.z_index = 18
	radio_label.add_theme_font_size_override("font_size", 18)
	radio_label.add_theme_color_override("font_color", Color(0.98, 0.9, 0.55))
	layer.add_child(radio_label)
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "HowToOverlay"
	panel.position = Vector2(224, 210)
	panel.custom_minimum_size = Vector2(780, 280)
	panel.z_index = 30
	panel.visible = true
	layer.add_child(panel)
	guide_panel = panel
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title: Label = Label.new()
	title.name = "HowToTitle"
	title.text = "How to play"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.86, 0.45))
	box.add_child(title)
	tutorial_label = Label.new()
	tutorial_label.name = "TutorialPrompt"
	tutorial_label.visible = false
	tutorial_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_label.custom_minimum_size = Vector2(740, 0)
	tutorial_label.add_theme_font_size_override("font_size", 18)
	tutorial_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.9))
	box.add_child(tutorial_label)
	var body: Label = Label.new()
	body.name = "HowToBody"
	body.text = SMGuide.howto_text()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(740, 190)
	body.add_theme_font_size_override("font_size", 16)
	body.add_theme_color_override("font_color", Color(0.93, 0.94, 0.96))
	box.add_child(body)
	var close: Button = Button.new()
	close.name = "HowToClose"
	close.text = "Got it"
	close.custom_minimum_size = Vector2(160, 36)
	close.add_theme_font_size_override("font_size", 16)
	close.pressed.connect(_hide_guide)
	box.add_child(close)

func _tip(layer: CanvasLayer) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "TipPanel"
	panel.position = Vector2(224, 620)
	panel.custom_minimum_size = Vector2(780, 56)
	panel.visible = false
	panel.z_index = 12
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	tip_panel = panel
	tip_label = Label.new()
	tip_label.name = "UnitTip"
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_label.custom_minimum_size = Vector2(760, 48)
	tip_label.add_theme_font_size_override("font_size", 16)
	tip_label.add_theme_color_override("font_color", Color(0.97, 0.96, 0.92))
	panel.add_child(tip_label)

func _toggle_guide() -> void:
	if guide_panel != null:
		guide_panel.visible = not guide_panel.visible

func _hide_guide() -> void:
	if guide_panel != null:
		guide_panel.visible = false

func _enter_tip(text: String) -> void:
	hover_tip = text
	_paint_tip()

func _exit_tip() -> void:
	hover_tip = ""
	_paint_tip()

func _paint_tip() -> void:
	if tip_label == null or tip_panel == null:
		return
	var text: String = hover_tip if hover_tip != "" else _selection_tip()
	tip_label.text = text
	tip_panel.visible = text != ""

func _selection_tip() -> String:
	if field == null or field.selection.count() <= 0:
		return ""
	var first: RTSUnit = field.selection.units[0]
	var ability: String = str(first.get_meta("ability", "ability"))
	var loco: String = str(first.get_meta("locomotion", "ground"))
	var weapon: String = str(first.get_meta("weapon", "weapon"))
	return "%s. HP %d/%d. %s for %d. Moves on %s. F: %s." % [field.name_of(first), int(round(first.hp)), int(round(first.max_hp)), weapon, int(round(first.attack_damage)), loco, ability]

func _button(box: VBoxContainer, node_name: String, text: String, fn: Callable, tip: String, cue: String) -> void:
	var b: Button = Button.new()
	b.name = node_name
	b.text = text
	b.tooltip_text = tip
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(200, 28)
	b.add_theme_font_size_override("font_size", 14)
	b.mouse_entered.connect(_enter_tip.bind(tip))
	b.mouse_exited.connect(_exit_tip)
	b.pressed.connect(_press_cue.bind(fn, cue))
	box.add_child(b)

func _press_cue(fn: Callable, cue: String) -> void:
	if sfx != null:
		sfx.play(cue)
	if fn.is_valid():
		fn.call()

func _label(parent: Node, node_name: String, pos: Vector2, size: int) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.position = pos
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.93, 0.94, 0.96))
	parent.add_child(label)
	return label
