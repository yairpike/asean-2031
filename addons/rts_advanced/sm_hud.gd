class_name SMHud
extends RefCounted

const Power = preload("res://addons/rts_advanced/sm_power.gd")
## In-match readout. Primitive controls and a flat minimap. No map mesh, no art.

signal layer_mounted(who: SMHud, layer: CanvasLayer)

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
var unit_card: PanelContainer
var match_strip: PanelContainer
var purse_mark: int = -1
var purse_ms: int = 0
var purse_rate: int = 0
var purse_window: float = 0.0
var purse_gained: int = 0
var purse_flash: String = ""
var purse_flash_t: float = 0.0
var _map_ms: int = 0
var _shown_credits: int = -999999
var _shown_power: Vector2i = Vector2i(-1, -1)
var _shown_weather: String = ""
var _shown_faction: String = ""
var _shown_map: String = ""
var _shown_selection: String = ""
var layer_node: CanvasLayer
var phone: bool = false
var phone_tab: String = "buildings"
var drawer_open: bool = false
var phone_sheet: float = 280.0
var hint_closed: bool = false
var mission_open: bool = false
var _layout_key: Vector2i = Vector2i(-1, -1)
var phone_drawer: Control
var phone_body: Control
var mission_fold: Button
var mission_panel: Control
var rotate_banner: Control

func mount(layer: CanvasLayer, p_field: SMPointer, p_roster: SMRoster, p_side: SMSide, p_map: String, p_rally: Vector3, ability: Callable, grid: SMDomainGrid, camera: RTSCamera) -> void:
	field = p_field
	roster = p_roster
	side = p_side
	map_name = p_map
	rally = p_rally
	on_ability = ability
	var top: Control = Control.new()
	top.name = "TopBar"
	top.anchor_right = 1.0
	top.offset_bottom = 36.0
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(top)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.05, 0.06, 0.07, 0.92)
	shade.anchor_right = 1.0
	shade.anchor_bottom = 1.0
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(shade)
	var row: HBoxContainer = HBoxContainer.new()
	row.anchor_right = 1.0
	row.anchor_bottom = 1.0
	row.offset_left = 12.0
	row.offset_top = 4.0
	row.offset_right = -12.0
	row.offset_bottom = -4.0
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(row)
	faction_label = _flow_label(row, "HudFaction", 16)
	credits_label = _flow_label(row, "HudCredits", 16)
	income_label = _flow_label(row, "HudIncome", 15)
	income_label.add_theme_color_override("font_color", Color(0.55, 0.9, 0.48))
	income_label.visible = false
	power_label = _flow_label(row, "HudPower", 16)
	map_label = _flow_label(row, "HudMap", 16)
	map_label.size_flags_stretch_ratio = 2.2
	map_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	weather_label = _flow_label(row, "HudWeather", 15)
	minimap = SMMinimap.new()
	minimap.name = "Minimap"
	minimap.setup(grid, field, camera)
	minimap.position = Vector2(8, 42)
	minimap.custom_minimum_size = Vector2(156, 108)
	minimap.size = Vector2(156, 108)
	layer.add_child(minimap)
	_column(layer)
	_guide(layer)
	_tip(layer)
	sfx = SMSfx.new()
	sfx.mount(layer)
	if field != null:
		field.on_cue = Callable(sfx, "play")
		field.on_line = Callable(self, "show_line")
		field.on_bark = Callable(sfx, "bark")
	layer_node = layer
	layer.set_meta("hud", self)
	if field != null:
		field.place_rally(rally)
	layer_mounted.emit(self, layer)
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
	var faction: String = _faction_name(_faction_id())
	if faction != _shown_faction:
		_shown_faction = faction
		faction_label.text = faction
	var purse: int = 0
	if roster != null and roster.economy != null:
		purse = roster.economy.credits(0)
	_measure_purse()
	if purse != _shown_credits:
		_shown_credits = purse
		credits_label.text = ("%d" % purse) if phone else ("Credits %d" % purse)
	var pair: Vector2i = Power.tally(side.yard if side != null else null)
	if pair != _shown_power:
		_shown_power = pair
		power_label.text = ("%d/%d" % [pair.x, pair.y]) if phone else ("Power %d/%d" % [pair.x, pair.y])
	if map_name != _shown_map:
		_shown_map = map_name
		map_label.text = map_name
	if weather_label != null:
		var sky: String = "Clear"
		if minimap != null and minimap.sight != null:
			sky = minimap.sight.weather_name
		if sky != _shown_weather:
			_shown_weather = sky
			weather_label.text = sky
	if selection_label != null:
		var line: String = _selection_line()
		if line != _shown_selection:
			_shown_selection = line
			selection_label.text = line
	_sync_imports()
	_paint_tip()
	_paint_radio()
	_sync_card()
	_paint_mission_fold()
	if minimap != null:
		var now: int = Time.get_ticks_msec()
		if _map_ms <= 0 or now - _map_ms >= 250:
			_map_ms = maxi(now, 1)
			minimap.sample()
			minimap.queue_redraw()

func set_rally(at: Vector3) -> void:
	if at == Vector3.INF:
		return
	rally = at
	if field != null:
		field.place_rally(at)
	_note("Rally set")

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
	income_label.visible = income_label.text != ""

func show_line(text: String) -> void:
	if radio_label == null:
		return
	radio_label.text = text
	radio_label.visible = text != ""
	radio_until = Time.get_ticks_msec() + 2800
	_sync_card()

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
	var backdrop: ColorRect = ColorRect.new()
	backdrop.name = "ColumnShade"
	backdrop.color = Color(0.05, 0.06, 0.07, 0.9)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dock(backdrop, -186.0, 40.0, -8.0, -8.0, 1.0, 0.0, 1.0, 1.0)
	layer.add_child(backdrop)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "CommandColumn"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.clip_contents = true
	_dock(scroll, -186.0, 40.0, -8.0, -8.0, 1.0, 0.0, 1.0, 1.0)
	layer.add_child(scroll)
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "Sidebar"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(0, 0)
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
	_button(box, "CancelQueue", "Cancel", _cancel, "Cancel the building in progress and refund what it has spent.", "ui")
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
	_note(side.yard.super_name if hit > 0 else "superweapon cooling")
	refresh()

func _order(id: StringName) -> void:
	if side == null:
		return
	var note: String = side.order_building(id)
	if note == "built":
		note = "%s built" % side.building_label(id)
	_note(note)
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
	var show_imports: bool = open and (not phone or phone_tab == "buildings")
	var header: Node = sidebar.get_node_or_null("GroupImports")
	if header != null:
		header.visible = show_imports
	if not imports_ready:
		return
	for child: Node in sidebar.get_children():
		if str(child.name).begins_with("Import_"):
			(child as CanvasItem).visible = show_imports

func _import(id: StringName) -> void:
	if roster == null or field == null or tech == null or not tech.holds(SMTechNet.BAZAAR, SMPointer.PLAYER):
		_note("bazaar required")
		refresh()
		return
	var cost: int = 0
	var row: Dictionary = {}
	for unit: Dictionary in SMCatalog.units_of(SMCatalog.faction("black_market")):
		if str(unit.get("id", "")) == str(id):
			row = unit
			cost = int(unit.get("cost", 0))
	if row.is_empty() or not roster.economy.try_spend(SMPointer.PLAYER, cost):
		_note("cannot import")
		refresh()
		return
	var at: Vector3 = rally + Vector3(6.0 + float(field.count_team(SMPointer.PLAYER) % 4) * 2.0, 0.0, 2.0)
	var u: RTSUnit = field.spawn(SMPointer.PLAYER, at, id)
	_note(field.name_of(u))
	refresh()

func _cancel() -> void:
	var note: String = ""
	if roster != null and roster.queue != null and not roster.queue.items.is_empty():
		roster.queue.cancel(roster.economy)
		note = "cancelled"
	if side != null:
		var built: String = side.cancel_order()
		if note == "":
			note = built
	_note(note if note != "" else "nothing to cancel")
	refresh()

func _train(id: StringName) -> void:
	if roster == null or field == null:
		return
	if side != null and not Power.online(side.yard):
		_note("low power")
		refresh()
		return
	var done: StringName = roster.train_and_finish(id)
	if done == &"":
		_note("cannot train")
		refresh()
		return
	var at: Vector3 = rally + Vector3(6.0 + float(field.count_team(SMPointer.PLAYER) % 4) * 2.0, 0.0, 2.0)
	var u: RTSUnit = field.spawn(SMPointer.PLAYER, at, done)
	_note(field.name_of(u))
	refresh()

func _ability() -> void:
	if on_ability.is_valid():
		on_ability.call()
	refresh()

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
	label.clip_text = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.9, 0.78, 0.45))
	box.add_child(label)

func _guide(layer: CanvasLayer) -> void:
	var help: Button = Button.new()
	help.name = "HelpButton"
	help.text = "How to play (H)"
	help.clip_text = true
	help.custom_minimum_size = Vector2(168, 44)
	help.z_index = 9
	help.add_theme_font_size_override("font_size", 15)
	_dock(help, 8.0, -186.0, 176.0, -142.0, 0.0, 1.0, 0.0, 1.0)
	help.pressed.connect(_toggle_guide)
	layer.add_child(help)
	var card: PanelContainer = PanelContainer.new()
	card.name = "UnitCard"
	card.visible = false
	card.z_index = 8
	card.clip_contents = true
	card.add_theme_stylebox_override("panel", _card_style())
	_dock(card, 8.0, -82.0, -194.0, -6.0, 0.0, 1.0, 1.0, 1.0)
	layer.add_child(card)
	unit_card = card
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 0)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(stack)
	selection_label = _card_line(stack, "HudSelection", 16)
	build_label = _card_line(stack, "HudBuild", 14)
	build_label.visible = false
	radio_label = _card_line(stack, "RadioLine", 16)
	radio_label.visible = false
	radio_label.add_theme_color_override("font_color", Color(0.98, 0.9, 0.55))
	var strip: PanelContainer = PanelContainer.new()
	strip.name = "MatchStrip"
	strip.z_index = 8
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_theme_stylebox_override("panel", _card_style())
	_dock(strip, 8.0, -46.0, -194.0, -6.0, 0.0, 1.0, 1.0, 1.0)
	layer.add_child(strip)
	match_strip = strip
	var short_line: Label = _card_line(strip, "MatchHint", 15)
	short_line.text = "H guide    P protocols"
	short_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "HowToOverlay"
	panel.clip_contents = true
	panel.z_index = 30
	panel.visible = true
	_dock(panel, 168.0, 44.0, -194.0, -56.0, 0.0, 0.0, 1.0, 1.0)
	layer.add_child(panel)
	guide_panel = panel
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(box)
	var title: Label = Label.new()
	title.name = "HowToTitle"
	title.text = "How to play"
	title.theme_type_variation = "Header"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.86, 0.45))
	box.add_child(title)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "HowToScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var inner: VBoxContainer = VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 8)
	scroll.add_child(inner)
	tutorial_label = Label.new()
	tutorial_label.name = "TutorialPrompt"
	tutorial_label.visible = false
	tutorial_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tutorial_label.add_theme_font_size_override("font_size", 18)
	tutorial_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.9))
	inner.add_child(tutorial_label)
	var body: Label = Label.new()
	body.name = "HowToBody"
	body.text = SMGuide.howto_text()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("font_size", 16)
	body.add_theme_color_override("font_color", Color(0.93, 0.94, 0.96))
	inner.add_child(body)
	var hint: Label = Label.new()
	hint.name = "ControlsHint"
	hint.text = SMGuide.controls_hint()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.96, 0.94, 0.86))
	inner.add_child(hint)
	var close: Button = Button.new()
	close.name = "HowToClose"
	close.text = "Got it"
	close.custom_minimum_size = Vector2(160, 44)
	close.add_theme_font_size_override("font_size", 16)
	close.pressed.connect(_hide_guide)
	box.add_child(close)

func _tip(layer: CanvasLayer) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "TipPanel"
	panel.visible = false
	panel.z_index = 14
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _card_style())
	panel.custom_minimum_size = Vector2(360, 96)
	_dock(panel, -640.0, -210.0, -196.0, -96.0, 1.0, 1.0, 1.0, 1.0)
	layer.add_child(panel)
	tip_panel = panel
	tip_label = Label.new()
	tip_label.name = "UnitTip"
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tip_label.add_theme_font_size_override("font_size", 14)
	tip_label.add_theme_color_override("font_color", Color(0.97, 0.96, 0.92))
	panel.add_child(tip_label)

func _toggle_guide() -> void:
	if guide_panel != null:
		guide_panel.visible = not guide_panel.visible

func _hide_guide() -> void:
	if guide_panel != null:
		guide_panel.visible = false

func guide_blocks() -> bool:
	return OS.has_feature("web") and guide_panel != null and guide_panel.visible

func _enter_tip(text: String) -> void:
	hover_tip = text
	_paint_tip()

func _exit_tip() -> void:
	hover_tip = ""
	_paint_tip()

func _paint_tip() -> void:
	if tip_label == null or tip_panel == null:
		return
	tip_label.text = hover_tip
	tip_panel.visible = hover_tip != ""

func _button(box: VBoxContainer, node_name: String, text: String, fn: Callable, tip: String, cue: String) -> void:
	var b: Button = Button.new()
	b.name = node_name
	b.text = text
	b.tooltip_text = tip
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 48 if phone else 40)
	b.add_theme_font_size_override("font_size", 16 if phone else 14)
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

func _flow_label(parent: Node, node_name: String, size: int) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.clip_text = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.93, 0.94, 0.96))
	parent.add_child(label)
	return label

func _card_line(parent: Node, node_name: String, size: int) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.clip_text = true
	label.custom_minimum_size = Vector2(0, 18)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.93, 0.94, 0.96))
	parent.add_child(label)
	return label

func _card_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.07, 0.92)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

func _note(text: String) -> void:
	if build_label == null:
		return
	build_label.text = text
	build_label.visible = text != ""
	_sync_card()

func _sync_card() -> void:
	var busy: bool = false
	if selection_label != null:
		var chosen: bool = selection_label.text != "" and selection_label.text != "Nothing selected"
		selection_label.visible = chosen
		if chosen:
			busy = true
	if radio_label != null and radio_label.visible and radio_label.text != "":
		busy = true
	if build_label != null and build_label.visible and build_label.text != "":
		busy = true
	if unit_card != null:
		unit_card.visible = busy
	if match_strip != null:
		match_strip.visible = not busy and not phone

func _dock(node: Control, left: float, top: float, right: float, bottom: float, anchor_l: float, anchor_t: float, anchor_r: float, anchor_b: float) -> void:
	node.anchor_left = anchor_l
	node.anchor_top = anchor_t
	node.anchor_right = anchor_r
	node.anchor_bottom = anchor_b
	node.offset_left = left
	node.offset_top = top
	node.offset_right = right
	node.offset_bottom = bottom

## Portrait only. Landscape and desktop keep the right-hand column.
func layout_for(size: Vector2) -> void:
	if layer_node == null:
		return
	var want: bool = size.y > size.x + 4.0
	var key: Vector2i = Vector2i(int(round(size.x)), int(round(size.y)))
	if want == phone and key == _layout_key:
		_paint_mission_fold()
		return
	var was: bool = phone or phone_drawer != null
	if was:
		_leave_phone()
	phone = want
	_layout_key = key
	if phone:
		_enter_phone(size)
	_shown_credits = -999999
	_shown_power = Vector2i(-1, -1)
	_shown_faction = ""
	_shown_map = ""
	_shown_weather = ""
	refresh()

func _enter_phone(size: Vector2) -> void:
	phone_sheet = clampf(size.y * 0.38, 240.0, 380.0)
	drawer_open = false
	mission_open = false
	_compact_top()
	_build_drawer(size)
	_build_mission(size)
	_build_hint(size)
	_place_phone_chrome(size)
	_apply_phone_tab()

func _leave_phone() -> void:
	var names: PackedStringArray = PackedStringArray([
		"CommandColumn", "ColumnShade", "Protocols", "ProtocolsToggle", "HelpButton",
		"Minimap", "TopBar", "UnitCard", "MatchStrip", "HowToOverlay", "TipPanel",
		"Briefing", "Status", "MissionBoot", "MissionHeading", "ObjectiveButton", "HowToClose",
	])
	for node_name: String in names:
		var node: Control = _phone_node(node_name)
		_restore(node)
	if sidebar != null:
		for child: Node in sidebar.get_children():
			_restore(child as Control)
	var grid: Node = _protocol_grid()
	if grid != null:
		for child: Node in grid.get_children():
			_restore(child as Control)
	if weather_label != null:
		weather_label.visible = true
	if faction_label != null:
		_restore(faction_label)
	if credits_label != null:
		_restore(credits_label)
	if power_label != null:
		_restore(power_label)
	if map_label != null:
		_restore(map_label)
	if weather_label != null:
		_restore(weather_label)
	var row: Control = _top_row()
	_restore(row)
	_free_phone(phone_drawer)
	_free_phone(mission_fold)
	_free_phone(mission_panel)
	_free_phone(rotate_banner)
	var guide: Node = _phone_node("PhoneGuide")
	_free_phone(guide as Control)
	phone_drawer = null
	phone_body = null
	mission_fold = null
	mission_panel = null
	rotate_banner = null
	phone = false

func _compact_top() -> void:
	var top: Control = _phone_node("TopBar")
	_snap(top)
	if top != null:
		top.offset_bottom = 32.0
	var row: Control = _top_row()
	_snap(row)
	if row != null:
		row.offset_top = 2.0
		row.offset_bottom = -2.0
	_phone_font(faction_label, 14)
	_phone_font(credits_label, 14)
	_phone_font(power_label, 14)
	_phone_font(map_label, 14)
	if weather_label != null:
		_snap(weather_label)
		weather_label.visible = false

func _build_drawer(size: Vector2) -> void:
	var drawer: PanelContainer = PanelContainer.new()
	drawer.name = "PhoneDrawer"
	drawer.z_index = 20
	drawer.mouse_filter = Control.MOUSE_FILTER_STOP
	drawer.add_theme_stylebox_override("panel", _tab_style())
	_dock(drawer, 0.0, -68.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0)
	layer_node.add_child(drawer)
	phone_drawer = drawer
	var stack: VBoxContainer = VBoxContainer.new()
	stack.name = "PhoneStack"
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 0)
	drawer.add_child(stack)
	var body: Control = Control.new()
	body.name = "PhoneBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.visible = false
	stack.add_child(body)
	phone_body = body
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.name = "PhoneTabs"
	tabs.custom_minimum_size = Vector2(0, 56)
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_theme_constant_override("separation", 6)
	stack.add_child(tabs)
	_tab_button(tabs, "PhoneTabBuildings", "Buildings", "buildings")
	_tab_button(tabs, "PhoneTabUnits", "Units", "units")
	_tab_button(tabs, "PhoneTabProtocols", "Protocols", "protocols")
	var column: Control = _phone_node("CommandColumn")
	_snap(column)
	if column != null:
		column.reparent(body, false)
		_dock(column, 6.0, 6.0, -6.0, -6.0, 0.0, 0.0, 1.0, 1.0)
	var shade: Control = _phone_node("ColumnShade")
	_snap(shade)
	if shade != null:
		shade.visible = false
	if sidebar != null:
		for child: Node in sidebar.get_children():
			var control: Control = child as Control
			if control == null:
				continue
			_snap(control)
			var wide: Button = child as Button
			if wide == null:
				continue
			wide.custom_minimum_size = Vector2(0, 48)
			wide.add_theme_font_size_override("font_size", 16)
	var protocols: Control = _phone_node("Protocols")
	_snap(protocols)
	if protocols != null:
		protocols.reparent(body, false)
		_dock(protocols, 6.0, 6.0, -6.0, -6.0, 0.0, 0.0, 1.0, 1.0)
		protocols.visible = false
	var grid: Node = _protocol_grid()
	if grid != null:
		for child: Node in grid.get_children():
			var proto: Button = child as Button
			if proto == null:
				continue
			_snap(proto)
			proto.custom_minimum_size = Vector2(148, 48)
			proto.add_theme_font_size_override("font_size", 15)
	var toggle: Control = _phone_node("ProtocolsToggle")
	_snap(toggle)
	if toggle != null:
		toggle.visible = false
	var help: Control = _phone_node("HelpButton")
	_snap(help)
	if help != null:
		help.visible = false

func _build_mission(size: Vector2) -> void:
	var fold: Button = Button.new()
	fold.name = "MissionFold"
	fold.clip_text = true
	fold.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	fold.alignment = HORIZONTAL_ALIGNMENT_LEFT
	fold.custom_minimum_size = Vector2(0, 48)
	fold.add_theme_font_size_override("font_size", 15)
	fold.z_index = 16
	fold.pressed.connect(_toggle_mission)
	_dock(fold, 8.0, 36.0, -78.0, 84.0, 0.0, 0.0, 1.0, 0.0)
	layer_node.add_child(fold)
	mission_fold = fold
	var guide: Button = Button.new()
	guide.name = "PhoneGuide"
	guide.text = "Guide"
	guide.custom_minimum_size = Vector2(64, 48)
	guide.add_theme_font_size_override("font_size", 15)
	guide.z_index = 16
	guide.pressed.connect(_toggle_guide)
	_dock(guide, -72.0, 36.0, -8.0, 84.0, 1.0, 0.0, 1.0, 0.0)
	layer_node.add_child(guide)
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "MissionPanel"
	panel.visible = false
	panel.z_index = 17
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _sheet_style())
	_dock(panel, 8.0, 88.0, -8.0, 360.0, 0.0, 0.0, 1.0, 0.0)
	layer_node.add_child(panel)
	mission_panel = panel
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	_adopt_mission(box, "MissionHeading")
	_adopt_mission(box, "Briefing")
	_adopt_mission(box, "Status")
	_adopt_mission(box, "MissionBoot")
	var boot: Button = _phone_node("MissionBoot") as Button
	if boot != null:
		boot.custom_minimum_size = Vector2(160, 48)
	var overlay: Control = _phone_node("HowToOverlay")
	_snap(overlay)
	if overlay != null:
		_dock(overlay, 12.0, 40.0, -12.0, -64.0, 0.0, 0.0, 1.0, 1.0)
	var close: Button = layer_node.find_child("HowToClose", true, false) as Button
	if close != null:
		_snap(close)
		close.custom_minimum_size = Vector2(160, 48)

func _build_hint(size: Vector2) -> void:
	if hint_closed:
		return
	var banner: PanelContainer = PanelContainer.new()
	banner.name = "RotateHint"
	banner.z_index = 18
	banner.mouse_filter = Control.MOUSE_FILTER_STOP
	banner.add_theme_stylebox_override("panel", _hint_style())
	_dock(banner, 8.0, 86.0, -8.0, 158.0, 0.0, 0.0, 1.0, 0.0)
	layer_node.add_child(banner)
	rotate_banner = banner
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	banner.add_child(row)
	var label: Label = Label.new()
	label.name = "RotateHintText"
	label.text = "Rotate to landscape for the best experience"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = false
	label.custom_minimum_size = Vector2(180, 48)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.98, 0.95, 0.86))
	row.add_child(label)
	var dismiss: Button = Button.new()
	dismiss.name = "RotateHintDismiss"
	dismiss.text = "OK"
	dismiss.custom_minimum_size = Vector2(64, 48)
	dismiss.add_theme_font_size_override("font_size", 16)
	dismiss.pressed.connect(_dismiss_hint)
	row.add_child(dismiss)

func _place_phone_chrome(size: Vector2) -> void:
	var map: Control = _phone_node("Minimap")
	_snap(map)
	if map != null:
		map.position = Vector2(8, 166)
		map.size = Vector2(108, 72)
		map.custom_minimum_size = Vector2(108, 72)
	var card: Control = _phone_node("UnitCard")
	_snap(card)
	var strip: Control = _phone_node("MatchStrip")
	_snap(strip)
	_seat_cards(size)
	var tip: Control = _phone_node("TipPanel")
	_snap(tip)
	if tip != null:
		_dock(tip, 8.0, -168.0, -8.0, -60.0, 0.0, 1.0, 1.0, 1.0)

func _seat_cards(size: Vector2) -> void:
	var sheet: float = phone_sheet if drawer_open else 68.0
	var card: Control = _phone_node("UnitCard")
	if card != null:
		_dock(card, 124.0, -(sheet + 78.0), -8.0, -(sheet + 6.0), 0.0, 1.0, 1.0, 1.0)
	var strip: Control = _phone_node("MatchStrip")
	if strip != null:
		_dock(strip, 124.0, -(sheet + 40.0), -8.0, -(sheet + 6.0), 0.0, 1.0, 1.0, 1.0)

func _tab_button(row: HBoxContainer, node_name: String, caption: String, which: String) -> void:
	var button: Button = Button.new()
	button.name = node_name
	button.text = caption
	button.clip_text = true
	button.custom_minimum_size = Vector2(0, 56)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(_show_phone_tab.bind(which))
	row.add_child(button)

func _show_phone_tab(which: String) -> void:
	if drawer_open and phone_tab == which:
		drawer_open = false
	else:
		phone_tab = which
		drawer_open = true
	_apply_phone_tab()
	if layer_node != null:
		_seat_cards(layer_node.get_viewport().get_visible_rect().size)

func _apply_phone_tab() -> void:
	if phone_drawer != null:
		var sheet: float = phone_sheet if drawer_open else 68.0
		phone_drawer.offset_top = -sheet
	if phone_body != null:
		phone_body.visible = drawer_open
	var column: CanvasItem = _phone_node("CommandColumn")
	var protocols: CanvasItem = _phone_node("Protocols")
	var show_proto: bool = phone_tab == "protocols"
	if protocols != null:
		protocols.visible = drawer_open and show_proto
	if column != null:
		column.visible = drawer_open and not show_proto
	if sidebar == null:
		return
	for child: Node in sidebar.get_children():
		var item: CanvasItem = child as CanvasItem
		if item == null:
			continue
		item.visible = _phone_shows(str(child.name))
	_sync_imports()

func _phone_shows(node_name: String) -> bool:
	if node_name == "HudTitle" or node_name == "GroupAbility":
		return false
	if phone_tab == "units":
		return node_name == "GroupUnits" or node_name.begins_with("Train_") or node_name == "AbilityButton"
	if phone_tab == "buildings":
		if node_name == "GroupBuildings" or node_name == "CancelQueue" or node_name == "MovePacker":
			return true
		if node_name.begins_with("Build_") or node_name.begins_with("Super_"):
			return true
		if node_name == "GroupImports" or node_name.begins_with("Import_"):
			return true
	return false

func _toggle_mission() -> void:
	mission_open = not mission_open
	if mission_panel != null:
		mission_panel.visible = mission_open
	if rotate_banner != null:
		rotate_banner.visible = not mission_open and not hint_closed
	var map: CanvasItem = _phone_node("Minimap")
	if map != null:
		map.visible = not mission_open
	_paint_mission_fold()

func _dismiss_hint() -> void:
	hint_closed = true
	if rotate_banner != null:
		rotate_banner.visible = false

func _paint_mission_fold() -> void:
	if mission_fold == null:
		return
	if mission_open:
		mission_fold.text = "Hide mission"
		return
	var line: String = "Mission"
	var status: Label = _phone_node("Status") as Label
	if status != null and status.text != "":
		line = status.text
	mission_fold.text = line

func _adopt_mission(box: VBoxContainer, node_name: String) -> void:
	var node: Control = _phone_node(node_name)
	if node == null:
		return
	_snap(node)
	node.reparent(box, false)
	node.position = Vector2.ZERO
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.custom_minimum_size = Vector2(0, 44)
	var line: Label = node as Label
	if line != null:
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.clip_text = false
	var tap: Button = node as Button
	if tap != null:
		tap.clip_text = false

func _phone_font(label: Label, size: int) -> void:
	if label == null:
		return
	_snap(label)
	label.add_theme_font_size_override("font_size", size)

func _phone_node(node_name: String) -> Control:
	if layer_node == null:
		return null
	return layer_node.find_child(node_name, true, false) as Control

func _protocol_grid() -> Node:
	var protocols: Node = _phone_node("Protocols")
	if protocols == null or protocols.get_child_count() == 0:
		return null
	return protocols.get_child(0)

func _top_row() -> Control:
	var top: Node = _phone_node("TopBar")
	if top == null:
		return null
	for child: Node in top.get_children():
		if child is HBoxContainer:
			return child as Control
	return null

func _tab_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = _sheet_style()
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

func _hint_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = _sheet_style()
	style.bg_color = Color(0.14, 0.16, 0.2, 0.96)
	style.border_color = Color(0.86, 0.72, 0.36)
	style.set_border_width_all(1)
	return style

func _sheet_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.08, 0.94)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

func _snap(node: Control) -> void:
	if node == null or node.has_meta("desk_snap"):
		return
	var font: int = -1
	if node.has_theme_font_size_override("font_size"):
		font = node.get_theme_font_size("font_size")
	node.set_meta("desk_snap", {
		"parent": node.get_parent(),
		"pos": node.position,
		"size": node.size,
		"min": node.custom_minimum_size,
		"al": node.anchor_left,
		"at": node.anchor_top,
		"ar": node.anchor_right,
		"ab": node.anchor_bottom,
		"ol": node.offset_left,
		"ot": node.offset_top,
		"right": node.offset_right,
		"ob": node.offset_bottom,
		"vis": node.visible,
		"font": font,
	})

func _restore(node: Control) -> void:
	if node == null or not is_instance_valid(node) or not node.has_meta("desk_snap"):
		return
	var snap: Dictionary = node.get_meta("desk_snap")
	var parent: Node = snap.get("parent") as Node
	if parent != null and is_instance_valid(parent) and node.get_parent() != parent:
		node.reparent(parent, false)
	node.anchor_left = float(snap.get("al", 0.0))
	node.anchor_top = float(snap.get("at", 0.0))
	node.anchor_right = float(snap.get("ar", 0.0))
	node.anchor_bottom = float(snap.get("ab", 0.0))
	node.offset_left = float(snap.get("ol", 0.0))
	node.offset_top = float(snap.get("ot", 0.0))
	node.offset_right = float(snap.get("right", 0.0))
	node.offset_bottom = float(snap.get("ob", 0.0))
	node.position = snap.get("pos", Vector2.ZERO) as Vector2
	node.size = snap.get("size", node.size) as Vector2
	node.custom_minimum_size = snap.get("min", Vector2.ZERO) as Vector2
	node.visible = bool(snap.get("vis", true))
	var font: int = int(snap.get("font", -1))
	if font > 0:
		node.add_theme_font_size_override("font_size", font)

func _free_phone(node: Control) -> void:
	if node != null and is_instance_valid(node):
		var parent: Node = node.get_parent()
		if parent != null:
			parent.remove_child(node)
		node.queue_free()
