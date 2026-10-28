extends Control
## Match HUD laid out like a command deck: monitor, credits, power, cameo tabs,
## a unit card, and a slot for the protocol panel. Our frames and colors, not a copy of another game's art.

const SWEEP := preload("res://game/cameo_sweep.gd")

static func install(layer: CanvasLayer, hud: SMHud, grid: SMDomainGrid, camera: RTSCamera) -> void:
	var root: Control = (load("res://game/match_hud.tscn") as PackedScene).instantiate() as Control
	layer.add_child(root)
	root._bind(hud, grid, camera)

func _bind(hud: SMHud, grid: SMDomainGrid, camera: RTSCamera) -> void:
	hud.use_tiles = true
	_style_self()
	var top: HBoxContainer = _top_bar()
	hud.faction_label = _label(top, "HudFaction", 16)
	hud.income_label = _label(top, "HudIncome", 15)
	hud.income_label.add_theme_color_override("font_color", Color(0.55, 0.9, 0.48))
	hud.income_label.visible = false
	hud.map_label = _label(top, "HudMap", 16)
	hud.map_label.size_flags_stretch_ratio = 2.2
	hud.map_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hud.weather_label = _label(top, "HudWeather", 15)
	var column: ScrollContainer = _column()
	var wrap: VBoxContainer = column.get_child(0) as VBoxContainer
	var host: Control = wrap.get_node("MonitorFrame/MonitorStack/MonitorHost") as Control
	var minimap: SMMinimap = SMMinimap.new()
	minimap.name = "Minimap"
	minimap.setup(grid, hud.field, camera)
	minimap.position = Vector2.ZERO
	minimap.custom_minimum_size = Vector2(156, 100)
	minimap.size = Vector2(156, 100)
	host.add_child(minimap)
	hud.minimap = minimap
	hud.monitor_cameo = wrap.get_node("MonitorFrame/MonitorStack/MonitorCameo") as TextureRect
	hud.credits_label = wrap.get_node("HudCredits") as Label
	hud.power_fill = wrap.get_node("PowerRow/PowerTrack/PowerFill") as ColorRect
	hud.power_mark = wrap.get_node("PowerRow/PowerTrack/PowerMark") as ColorRect
	hud.power_label = wrap.get_node("PowerRow/HudPower") as Label
	hud.repair_button = wrap.get_node("ModeRow/RepairButton") as Button
	hud.sell_button = wrap.get_node("ModeRow/SellButton") as Button
	hud.repair_button.pressed.connect(hud.toggle_repair_mode)
	hud.sell_button.pressed.connect(hud.toggle_sell_mode)
	hud.icon_grid = wrap.get_node("PhoneIconGrid") as GridContainer
	hud.sidebar = wrap.get_node("Sidebar") as VBoxContainer
	hud.super_dock = get_node("SuperDock") as VBoxContainer
	hud.command_row = find_child("CommandRow", true, false) as VBoxContainer
	hud.unit_card = find_child("UnitCard", true, false) as PanelContainer
	hud.card_cameo = find_child("CardCameo", true, false) as TextureRect
	hud.selection_label = find_child("HudSelection", true, false) as Label
	hud.build_label = find_child("HudBuild", true, false) as Label
	hud.radio_label = find_child("RadioLine", true, false) as Label
	hud.health_fill = find_child("HealthFill", true, false) as ColorRect
	hud.veteran_label = find_child("HudVeteran", true, false) as Label
	hud.breakdown_label = find_child("HudBreakdown", true, false) as Label
	_wire_tab(hud, "TabBuildings", "buildings")
	_wire_tab(hud, "TabDefenses", "defenses")
	_wire_tab(hud, "TabInfantry", "infantry")
	_wire_tab(hud, "TabVehicles", "vehicles")
	_wire_tab(hud, "TabAircraft", "aircraft")
	_wire_tab(hud, "TabNaval", "naval")
	var scroll: ScrollContainer = get_node("CommandColumn") as ScrollContainer
	if scroll != null and not scroll.gui_input.is_connected(hud._drag_column):
		scroll.gui_input.connect(hud._drag_column)
	hud.paint_extra = Callable(self, "paint")
	set_meta("hud", hud)

func paint(hud: SMHud) -> void:
	_paint_power(hud)
	_paint_monitor(hud)
	_paint_modes(hud)
	_paint_sweeps(hud)
	_paint_super(hud)
	_paint_protocols(hud)

func _paint_protocols(hud: SMHud) -> void:
	if hud.layer_node == null:
		return
	var grid: Node = hud.layer_node.find_child("Protocols", true, false)
	if grid == null or grid.get_child_count() == 0:
		return
	var book: SMProtocols = grid.get_meta("book", null) as SMProtocols
	if book == null:
		return
	var inner: Node = grid.get_child(0)
	for child: Node in inner.get_children():
		var button: Button = child as Button
		if button == null or not str(button.name).begins_with("Proto_"):
			continue
		var id: StringName = StringName(str(button.name).trim_prefix("Proto_"))
		var left: float = float(book.cool_left.get(id, 0.0))
		var ratio: float = 0.0
		if left > 0.0 and SMProtocols.COOL_TIME > 0.0:
			ratio = 1.0 - clampf(left / SMProtocols.COOL_TIME, 0.0, 1.0)
		_sweep(button, ratio, 0)

func _process(delta: float) -> void:
	var hud: SMHud = get_meta("hud", null) as SMHud
	if hud == null or hud.side == null:
		return
	hud.side.tick_modes(delta)
	_paint_power(hud)
	_paint_monitor(hud)
	_paint_modes(hud)
	_paint_sweeps(hud)
	_paint_super(hud)
	_paint_protocols(hud)

func _paint_power(hud: SMHud) -> void:
	if hud.power_fill == null or hud.side == null:
		return
	var pair: Vector2i = hud._power_pair()
	var span: float = float(maxi(maxi(pair.x, pair.y), 1))
	var gen: float = float(pair.x) / span
	var draw: float = float(pair.y) / span
	var low: bool = pair.x < pair.y
	hud.power_fill.color = Color(0.78, 0.24, 0.2) if low else Color(0.32, 0.78, 0.36)
	hud.power_fill.anchor_top = 1.0 - gen
	hud.power_fill.offset_top = 0.0
	hud.power_fill.offset_bottom = 0.0
	if hud.power_mark != null:
		hud.power_mark.anchor_top = 1.0 - draw
		hud.power_mark.anchor_bottom = 1.0 - draw
		hud.power_mark.offset_top = -1.0
		hud.power_mark.offset_bottom = 1.0

func _paint_monitor(hud: SMHud) -> void:
	if hud.monitor_cameo == null or hud.minimap == null:
		return
	var portrait: Texture2D = null
	if hud.field != null and hud.field.selection.count() == 1:
		var unit: RTSUnit = hud.field.selection.units[0]
		if unit != null:
			portrait = hud._cameo_texture(hud._faction_id(), str(unit.unit_type))
	hud.monitor_cameo.texture = portrait
	hud.monitor_cameo.visible = portrait != null
	hud.minimap.visible = portrait == null

func _paint_modes(hud: SMHud) -> void:
	if hud.side == null:
		return
	if hud.repair_button != null:
		hud.repair_button.modulate = Color(1.0, 0.86, 0.42) if hud.side.repair_armed else Color(1, 1, 1)
	if hud.sell_button != null:
		hud.sell_button.modulate = Color(1.0, 0.86, 0.42) if hud.side.sell_armed else Color(1, 1, 1)

func _paint_sweeps(hud: SMHud) -> void:
	if hud.icon_grid == null:
		return
	for child: Node in hud.icon_grid.get_children():
		var button: Button = child as Button
		if button == null:
			continue
		var id: String = str(button.get_meta("prod_id", ""))
		var kind: String = str(button.get_meta("prod_kind", ""))
		_sweep(button, _ratio(hud, id, kind), _queued(hud, id, kind))

func _paint_super(hud: SMHud) -> void:
	if hud.super_dock == null or hud.side == null or hud.side.yard == null:
		return
	for child: Node in hud.super_dock.get_children():
		var button: Button = child as Button
		if button == null:
			continue
		var left: float = hud.side.yard.super_left
		var ready: bool = left <= 0.0 and hud.side.yard.super_name != ""
		button.modulate = Color(1.0, 0.9, 0.45) if ready else Color(0.55, 0.58, 0.62)
		var clock: Label = button.get_node_or_null("SuperClock") as Label
		if clock != null:
			clock.text = "" if ready else str(int(ceil(left)))
		_sweep(button, 0.0 if hud.side.yard.super_cooldown <= 0.0 else 1.0 - clampf(left / hud.side.yard.super_cooldown, 0.0, 1.0), 0)

func _ratio(hud: SMHud, id: String, kind: String) -> float:
	if id == "":
		return 0.0
	if kind == "unit" and hud.roster != null and hud.roster.queue != null:
		var queue: RTSProductionQueue = hud.roster.queue
		if not queue.items.is_empty() and str(queue.items[0]) == id:
			return queue.head_ratio()
	if kind == "building" and hud.side != null and hud.side.yard != null:
		var yard: SMBuildYard = hud.side.yard
		if yard.scaffold_active and str(yard.scaffold_id) == id and yard.scaffold_time > 0.0:
			return clampf(yard.scaffold_progress / yard.scaffold_time, 0.0, 1.0)
		if not yard.queue.is_empty() and str(yard.queue[0]) == id:
			var need: float = float(yard.building_time.get(yard.queue[0], 4.0))
			if need > 0.0:
				return clampf(yard.queue_progress / need, 0.0, 1.0)
	return 0.0

func _queued(hud: SMHud, id: String, kind: String) -> int:
	var count: int = 0
	if kind == "unit" and hud.roster != null and hud.roster.queue != null:
		for item: StringName in hud.roster.queue.items:
			if str(item) == id:
				count += 1
	if kind == "building" and hud.side != null and hud.side.yard != null:
		for item: StringName in hud.side.yard.queue:
			if str(item) == id:
				count += 1
		if hud.side.yard.scaffold_active and str(hud.side.yard.scaffold_id) == id:
			count += 1
	return count

func _sweep(button: Button, ratio: float, count: int) -> void:
	var sweep: Control = button.get_node_or_null("CameoSweep") as Control
	if sweep == null:
		sweep = Control.new()
		sweep.name = "CameoSweep"
		sweep.set_script(SWEEP)
		sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(sweep)
	sweep.set("ratio", ratio)
	sweep.queue_redraw()
	var badge: Label = button.get_node_or_null("QueueBadge") as Label
	if badge != null:
		badge.text = str(count)
		badge.visible = count > 0

func _wire_tab(hud: SMHud, node_name: String, tab_name: String) -> void:
	var button: Button = find_child(node_name, true, false) as Button
	if button == null:
		return
	button.pressed.connect(hud.show_build_tab.bind(tab_name))

func _style_self() -> void:
	var frame: StyleBoxFlat = _frame()
	for node_name: String in ["MonitorFrame", "UnitCard"]:
		var panel: PanelContainer = find_child(node_name, true, false) as PanelContainer
		if panel != null:
			panel.add_theme_stylebox_override("panel", frame)

func _top_bar() -> HBoxContainer:
	var top: Control = Control.new()
	top.name = "TopBar"
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(top, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 32.0)
	add_child(top)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.05, 0.06, 0.07, 0.92)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	top.add_child(shade)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	_anchor(row, 0.0, 0.0, 1.0, 1.0, 12.0, 4.0, -12.0, -4.0)
	top.add_child(row)
	return row

func _column() -> ScrollContainer:
	var shade: ColorRect = ColorRect.new()
	shade.name = "ColumnShade"
	shade.color = Color(0.05, 0.055, 0.06, 0.94)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(shade, 1.0, 0.0, 1.0, 1.0, -186.0, 40.0, -8.0, -8.0)
	add_child(shade)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "CommandColumn"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.clip_contents = true
	_anchor(scroll, 1.0, 0.0, 1.0, 1.0, -186.0, 40.0, -8.0, -8.0)
	add_child(scroll)
	var wrap: VBoxContainer = VBoxContainer.new()
	wrap.name = "RosterWrap"
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("separation", 6)
	scroll.add_child(wrap)
	var monitor: PanelContainer = PanelContainer.new()
	monitor.name = "MonitorFrame"
	monitor.custom_minimum_size = Vector2(0, 112)
	wrap.add_child(monitor)
	var stack: Control = Control.new()
	stack.name = "MonitorStack"
	stack.custom_minimum_size = Vector2(156, 100)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	monitor.add_child(stack)
	var host: Control = Control.new()
	host.name = "MonitorHost"
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_child(host)
	var cameo: TextureRect = TextureRect.new()
	cameo.name = "MonitorCameo"
	cameo.visible = false
	cameo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cameo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cameo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cameo.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_child(cameo)
	var credits: Label = _label(wrap, "HudCredits", 16)
	credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var power_row: HBoxContainer = HBoxContainer.new()
	power_row.name = "PowerRow"
	power_row.add_theme_constant_override("separation", 8)
	wrap.add_child(power_row)
	var track: ColorRect = ColorRect.new()
	track.name = "PowerTrack"
	track.color = Color(0.08, 0.09, 0.1)
	track.custom_minimum_size = Vector2(16, 64)
	power_row.add_child(track)
	var fill: ColorRect = ColorRect.new()
	fill.name = "PowerFill"
	fill.color = Color(0.32, 0.78, 0.36)
	fill.layout_mode = 1
	fill.anchor_right = 1.0
	fill.anchor_bottom = 1.0
	fill.anchor_top = 1.0
	track.add_child(fill)
	var mark: ColorRect = ColorRect.new()
	mark.name = "PowerMark"
	mark.color = Color(0.95, 0.82, 0.35)
	mark.layout_mode = 1
	mark.anchor_right = 1.0
	mark.anchor_top = 1.0
	mark.anchor_bottom = 1.0
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(mark)
	var power: Label = _label(power_row, "HudPower", 14)
	power.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var modes: HBoxContainer = HBoxContainer.new()
	modes.name = "ModeRow"
	modes.add_theme_constant_override("separation", 4)
	wrap.add_child(modes)
	_mode_button(modes, "RepairButton", "Repair")
	_mode_button(modes, "SellButton", "Sell")
	var tabs: GridContainer = GridContainer.new()
	tabs.name = "BuildTabs"
	tabs.columns = 3
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_theme_constant_override("h_separation", 4)
	tabs.add_theme_constant_override("v_separation", 4)
	wrap.add_child(tabs)
	_tab_button(tabs, "TabBuildings", "Buildings")
	_tab_button(tabs, "TabDefenses", "Defenses")
	_tab_button(tabs, "TabInfantry", "Infantry")
	_tab_button(tabs, "TabVehicles", "Vehicles")
	_tab_button(tabs, "TabAircraft", "Aircraft")
	_tab_button(tabs, "TabNaval", "Naval")
	var grid: GridContainer = GridContainer.new()
	grid.name = "PhoneIconGrid"
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.custom_minimum_size = Vector2(0, 640)
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	wrap.add_child(grid)
	var sidebar: VBoxContainer = VBoxContainer.new()
	sidebar.name = "Sidebar"
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar.add_theme_constant_override("separation", 4)
	wrap.add_child(sidebar)
	var supers: VBoxContainer = VBoxContainer.new()
	supers.name = "SuperDock"
	supers.add_theme_constant_override("separation", 6)
	_anchor(supers, 0.0, 0.0, 0.0, 1.0, 8.0, 96.0, 76.0, -220.0)
	add_child(supers)
	_unit_card()
	return scroll

func _unit_card() -> void:
	var card: PanelContainer = PanelContainer.new()
	card.name = "UnitCard"
	card.visible = false
	card.z_index = 8
	card.clip_contents = true
	_anchor(card, 1.0, 1.0, 1.0, 1.0, -520.0, -176.0, -194.0, -8.0)
	add_child(card)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	card.add_child(margin)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	margin.add_child(stack)
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "CardRow"
	row.add_theme_constant_override("separation", 8)
	stack.add_child(row)
	var portrait: TextureRect = TextureRect.new()
	portrait.name = "CardCameo"
	portrait.custom_minimum_size = Vector2(56, 56)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.visible = false
	row.add_child(portrait)
	var lines: VBoxContainer = VBoxContainer.new()
	lines.name = "CardStack"
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.add_theme_constant_override("separation", 1)
	row.add_child(lines)
	_card_label(lines, "HudSelection", 15)
	var built: Label = _card_label(lines, "HudBuild", 13)
	built.visible = false
	var radio: Label = _card_label(lines, "RadioLine", 14)
	radio.visible = false
	radio.add_theme_color_override("font_color", Color(0.98, 0.9, 0.55))
	var track: ColorRect = ColorRect.new()
	track.name = "HealthTrack"
	track.color = Color(0.15, 0.16, 0.18)
	track.custom_minimum_size = Vector2(0, 8)
	lines.add_child(track)
	var fill: ColorRect = ColorRect.new()
	fill.name = "HealthFill"
	fill.color = Color(0.36, 0.78, 0.4)
	fill.layout_mode = 1
	fill.anchor_bottom = 1.0
	fill.offset_right = 120.0
	track.add_child(fill)
	var veteran: Label = _card_label(lines, "HudVeteran", 12)
	veteran.add_theme_color_override("font_color", Color(0.95, 0.82, 0.4))
	var breakdown: Label = _card_label(lines, "HudBreakdown", 12)
	breakdown.visible = false
	breakdown.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var commands: VBoxContainer = VBoxContainer.new()
	commands.name = "CommandRow"
	commands.add_theme_constant_override("separation", 4)
	stack.add_child(commands)

func _mode_button(row: HBoxContainer, node_name: String, text: String) -> void:
	var button: Button = Button.new()
	button.name = node_name
	button.text = text
	button.clip_text = true
	button.custom_minimum_size = Vector2(0, 40)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 14)
	row.add_child(button)

func _tab_button(grid: GridContainer, node_name: String, text: String) -> void:
	var button: Button = Button.new()
	button.name = node_name
	button.text = text
	button.clip_text = true
	button.tooltip_text = text
	button.custom_minimum_size = Vector2(0, 28)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 11)
	grid.add_child(button)

func _label(parent: Node, node_name: String, size: int) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.clip_text = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.93, 0.94, 0.96))
	parent.add_child(label)
	return label

func _card_label(parent: Node, node_name: String, size: int) -> Label:
	var label: Label = _label(parent, node_name, size)
	label.custom_minimum_size = Vector2(0, 16)
	return label

func _frame() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.07, 0.94)
	style.border_color = Color(0.78, 0.62, 0.28)
	style.set_border_width_all(1)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

func _anchor(node: Control, left: float, top: float, right: float, bottom: float, ol: float, ot: float, orr: float, ob: float) -> void:
	node.layout_mode = 1
	node.anchor_left = left
	node.anchor_top = top
	node.anchor_right = right
	node.anchor_bottom = bottom
	node.offset_left = ol
	node.offset_top = ot
	node.offset_right = orr
	node.offset_bottom = ob
