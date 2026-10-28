extends Control
## Match HUD laid out like a command deck: monitor, credits, power, cameo tabs,
## a unit card, and a slot for the protocol panel. Our frames and colors, not a copy of another game's art.

const SWEEP := preload("res://game/cameo_sweep.gd")
const Art = preload("res://game/served_art.gd")
const Clips = preload("res://game/match_audio.gd")

var _goals_open: bool = false

static func install(layer: CanvasLayer, hud: SMHud, grid: SMDomainGrid, camera: RTSCamera) -> void:
	var root: Control = (load("res://game/match_hud.tscn") as PackedScene).instantiate() as Control
	layer.add_child(root)
	root._bind(hud, grid, camera)

func _bind(hud: SMHud, grid: SMDomainGrid, camera: RTSCamera) -> void:
	hud.use_tiles = true
	_style_self()
	_selection_row()
	var top: HBoxContainer = _top_bar()
	var now_playing: Label = Label.new()
	now_playing.name = "NowPlaying"
	now_playing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	now_playing.clip_text = true
	now_playing.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	now_playing.add_theme_font_size_override("font_size", 14)
	now_playing.add_theme_color_override("font_color", Color(0.78, 0.74, 0.62))
	_anchor(now_playing, 0.0, 0.0, 0.0, 0.0, 12.0, 36.0, 480.0, 54.0)
	add_child(now_playing)
	hud.faction_label = _label(top, "HudFaction", 16)
	hud.faction_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	hud.credits_label = _label(top, "HudCredits", 16)
	hud.credits_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	hud.income_label = _label(top, "HudIncome", 15)
	hud.income_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	hud.income_label.add_theme_color_override("font_color", Color(0.55, 0.9, 0.48))
	hud.income_label.visible = false
	hud.map_label = _label(top, "HudMap", 16)
	hud.map_label.size_flags_stretch_ratio = 2.2
	hud.map_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.map_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hud.weather_label = _label(top, "HudWeather", 15)
	hud.weather_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	var menu: Button = Button.new()
	menu.name = "HudMenu"
	menu.text = "☰"
	menu.custom_minimum_size = Vector2(28, 22)
	menu.size_flags_horizontal = Control.SIZE_SHRINK_END
	menu.add_theme_font_size_override("font_size", 16)
	menu.pressed.connect(_open_menu)
	top.add_child(menu)
	var column: ScrollContainer = _column()
	var wrap: VBoxContainer = column.get_child(0) as VBoxContainer
	var host: Control = wrap.get_node("MonitorFrame/MonitorStack/MonitorHost") as Control
	var minimap: SMMinimap = SMMinimap.new()
	minimap.name = "Minimap"
	minimap.setup(grid, hud.field, camera)
	minimap.position = Vector2.ZERO
	minimap.custom_minimum_size = Vector2(216, 216)
	minimap.size = Vector2(216, 216)
	host.add_child(minimap)
	hud.minimap = minimap
	hud.monitor_cameo = wrap.get_node("MonitorFrame/MonitorStack/MonitorCameo") as TextureRect
	hud.power_fill = wrap.get_node("PowerRow/PowerTrack/PowerFill") as ColorRect
	hud.power_mark = wrap.get_node("PowerRow/PowerTrack/PowerMark") as ColorRect
	hud.power_label = wrap.get_node("PowerRow/HudPower") as Label
	hud.repair_button = wrap.get_node("ModeRow/RepairButton") as Button
	hud.sell_button = wrap.get_node("ModeRow/SellButton") as Button
	hud.repair_button.pressed.connect(_mode_sound)
	hud.repair_button.pressed.connect(hud.toggle_repair_mode)
	hud.sell_button.pressed.connect(_mode_sound)
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
	set_process_unhandled_input(true)

func paint(hud: SMHud) -> void:
	_paint_power(hud)
	_paint_monitor(hud)
	_paint_modes(hud)
	_paint_sweeps(hud)
	_paint_super(hud)
	_paint_protocols(hud)
	_paint_selection(hud)

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
	_seat_chrome()
	_seat_tip()
	_pulse_power_tile()
	var hud: SMHud = get_meta("hud", null) as SMHud
	if hud == null or hud.side == null:
		return
	hud.side.tick_modes(delta)
	SMGuns.tick(hud.side, hud.field, delta)
	_paint_power(hud)
	_paint_monitor(hud)
	_paint_modes(hud)
	_paint_sweeps(hud)
	_paint_super(hud)
	_paint_protocols(hud)
	_paint_selection(hud)

func _seat_tip() -> void:
	var layer: Node = get_parent()
	if layer == null:
		return
	var tip: Control = layer.find_child("TipPanel", true, false) as Control
	if tip == null:
		return
	_anchor(tip, 1.0, 0.0, 1.0, 0.0, -260.0, 268.0, -8.0, 356.0)
	tip.custom_minimum_size = Vector2(240, 88)

func _pulse_power_tile() -> void:
	var hud: SMHud = get_meta("hud", null) as SMHud
	if hud == null or hud.icon_grid == null or hud.side == null or hud.side.yard == null:
		return
	var pair: Vector2i = hud._power_pair()
	var pulse: bool = pair.x <= 0
	var wave: float = 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.008)
	for child: Node in hud.icon_grid.get_children():
		var button: Button = child as Button
		if button == null:
			continue
		var prod: String = str(button.get_meta("prod_id", ""))
		var feeds: bool = prod.contains("hydro") or prod.contains("plant") or prod.contains("reactor") or prod.contains("generator")
		if pulse and feeds and button.visible:
			button.modulate = Color(wave, wave, wave)

func _paint_power(hud: SMHud) -> void:
	if hud.power_fill == null or hud.side == null:
		return
	var pair: Vector2i = hud._power_pair()
	var span: float = float(maxi(maxi(pair.x, pair.y), 1))
	var gen: float = float(pair.x) / span
	var draw: float = float(pair.y) / span
	var low: bool = pair.x < pair.y
	var tight: bool = not low and pair.y > 0 and float(pair.x) < float(pair.y) * 1.2
	hud.power_fill.color = Color(0.78, 0.24, 0.2) if low else (Color(0.92, 0.78, 0.22) if tight else Color(0.32, 0.78, 0.36))
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
		button.modulate = Color(1.15, 1.05, 0.7) if ready else Color(0.7, 0.72, 0.76)
		button.custom_minimum_size = Vector2(56, 56)
		var plate: StyleBoxFlat = StyleBoxFlat.new()
		plate.bg_color = Color(0.08, 0.09, 0.11, 0.94)
		plate.corner_radius_top_left = 28
		plate.corner_radius_top_right = 28
		plate.corner_radius_bottom_left = 28
		plate.corner_radius_bottom_right = 28
		plate.set_border_width_all(2)
		plate.border_color = Color(0.95, 0.82, 0.35) if ready else Color(0.35, 0.38, 0.42)
		button.add_theme_stylebox_override("normal", plate)
		var clock: Label = button.get_node_or_null("SuperClock") as Label
		if clock != null:
			clock.text = "RDY" if ready else str(int(ceil(left)))
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
	button.mouse_entered.connect(_hover_sound)
	button.pressed.connect(_tab_sound)
	button.pressed.connect(hud.show_build_tab.bind(tab_name))

func _tab_sound() -> void:
	Clips.play_kind(self, "ui_tab")

func _hover_sound() -> void:
	Clips.play_kind(self, "ui_hover")

func _mode_sound() -> void:
	Clips.play_kind(self, "ui_click")

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
	_anchor(top, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 28.0)
	add_child(top)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.05, 0.06, 0.07, 0.92)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	top.add_child(shade)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation", 14)
	_anchor(row, 0.0, 0.0, 1.0, 1.0, 12.0, 4.0, -12.0, -4.0)
	top.add_child(row)
	return row

func _selection_row() -> void:
	var row := HBoxContainer.new()
	row.name = "SelectionSlots"
	row.visible = false
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	row.clip_contents = true
	_anchor(row, 0.0, 1.0, 0.0, 1.0, 376.0, -116.0, 736.0, -68.0)
	add_child(row)

func _paint_selection(hud: SMHud) -> void:
	var row: HBoxContainer = get_node_or_null("SelectionSlots") as HBoxContainer
	if row == null or hud == null:
		return
	var units: Array[RTSUnit] = []
	if hud.field != null:
		units = hud.field.selection.units
	var shown: int = mini(7, units.size())
	row.visible = shown > 1
	var cameo: CanvasItem = find_child("CardCameo", true, false) as CanvasItem
	if cameo != null and shown > 1:
		cameo.visible = false
	while row.get_child_count() > shown:
		var extra: Node = row.get_child(row.get_child_count() - 1)
		row.remove_child(extra)
		extra.free()
	for i: int in shown:
		var rect: TextureRect = null
		if i < row.get_child_count():
			rect = row.get_child(i) as TextureRect
		if rect == null:
			rect = TextureRect.new()
			rect.custom_minimum_size = Vector2(48, 48)
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(rect)
		var unit: RTSUnit = units[i]
		var tex: Texture2D = null
		if unit != null and is_instance_valid(unit):
			tex = hud._cameo_texture(hud._faction_id(), str(unit.unit_type))
		rect.texture = tex
		rect.visible = tex != null

func _faction(hud: SMHud) -> String:
	if hud != null and hud.field != null:
		var id: String = str(hud.field.get("faction_id"))
		if id == "gtfc" or id == "nmrf" or id == "mvd":
			return id
	var front: String = SMFront.current()
	if front == "nmrf" or front == "mvd":
		return front
	return "gtfc"

func _column() -> ScrollContainer:
	var shade: ColorRect = ColorRect.new()
	shade.name = "ColumnShade"
	shade.color = Color(0.05, 0.055, 0.06, 0.94)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(shade, 1.0, 0.0, 1.0, 1.0, -260.0, 28.0, -8.0, -8.0)
	add_child(shade)
	var plate: TextureRect = TextureRect.new()
	plate.name = "SidebarArt"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var side_tex: Texture2D = Art.texture("ui/frames/%s_sidebar.webp" % _faction(null))
	if side_tex != null:
		plate.texture = side_tex
		shade.visible = false
	_anchor(plate, 1.0, 0.0, 1.0, 1.0, -260.0, 28.0, -8.0, -8.0)
	add_child(plate)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "CommandColumn"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.clip_contents = true
	_anchor(scroll, 1.0, 0.0, 1.0, 1.0, -260.0, 28.0, -8.0, -8.0)
	add_child(scroll)
	var wrap: VBoxContainer = VBoxContainer.new()
	wrap.name = "RosterWrap"
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("separation", 6)
	scroll.add_child(wrap)
	var monitor: PanelContainer = PanelContainer.new()
	monitor.name = "MonitorFrame"
	monitor.custom_minimum_size = Vector2(0, 232)
	wrap.add_child(monitor)
	var stack: Control = Control.new()
	stack.name = "MonitorStack"
	stack.custom_minimum_size = Vector2(216, 216)
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
	var power_row: HBoxContainer = HBoxContainer.new()
	power_row.name = "PowerRow"
	power_row.add_theme_constant_override("separation", 8)
	wrap.add_child(power_row)
	var track: ColorRect = ColorRect.new()
	track.name = "PowerTrack"
	track.color = Color(0.08, 0.09, 0.1)
	track.custom_minimum_size = Vector2(12, 168)
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
	power.tooltip_text = "Power generated / power drawn"
	var modes: HBoxContainer = HBoxContainer.new()
	modes.name = "ModeRow"
	modes.add_theme_constant_override("separation", 4)
	wrap.add_child(modes)
	_mode_button(modes, "RepairButton", "Repair", "ui/icons/repair.webp")
	_mode_button(modes, "SellButton", "Sell", "ui/icons/sell.webp")
	var tabs: GridContainer = GridContainer.new()
	tabs.name = "BuildTabs"
	tabs.columns = 4
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_theme_constant_override("h_separation", 4)
	tabs.add_theme_constant_override("v_separation", 4)
	wrap.add_child(tabs)
	_tab_button(tabs, "TabBuildings", "Buildings", "ui/icons/tab_buildings.webp")
	_tab_button(tabs, "TabDefenses", "Defenses", "ui/icons/tab_defenses.webp")
	_tab_button(tabs, "TabInfantry", "Infantry", "ui/icons/tab_infantry.webp")
	_tab_button(tabs, "TabVehicles", "Vehicles", "ui/icons/tab_vehicles.webp")
	_tab_button(tabs, "TabAircraft", "Aircraft", "ui/icons/tab_aircraft.webp")
	_tab_button(tabs, "TabNaval", "Naval", "ui/icons/tab_naval.webp")
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
	_anchor(supers, 0.0, 0.0, 0.0, 0.0, 8.0, 100.0, 64.0, 280.0)
	add_child(supers)
	_unit_card()
	return scroll

func _unit_card() -> void:
	var card: PanelContainer = PanelContainer.new()
	card.name = "UnitCard"
	card.visible = false
	card.z_index = 8
	card.clip_contents = true
	_anchor(card, 0.0, 1.0, 0.0, 1.0, 380.0, -128.0, 900.0, -8.0)
	add_child(card)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	card.add_child(margin)
	var body: HBoxContainer = HBoxContainer.new()
	body.name = "CardRow"
	body.add_theme_constant_override("separation", 8)
	margin.add_child(body)
	var portrait: TextureRect = TextureRect.new()
	portrait.name = "CardCameo"
	portrait.custom_minimum_size = Vector2(96, 96)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.visible = false
	body.add_child(portrait)
	var lines: VBoxContainer = VBoxContainer.new()
	lines.name = "CardStack"
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.add_theme_constant_override("separation", 2)
	body.add_child(lines)
	var text_block: Control = Control.new()
	text_block.name = "CardText"
	text_block.custom_minimum_size = Vector2(0, 36)
	text_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(text_block)
	var selected: Label = _card_label(text_block, "HudSelection", 16)
	selected.position = Vector2(0, 0)
	selected.size = Vector2(380, 18)
	var track: ColorRect = ColorRect.new()
	track.name = "HealthTrack"
	track.color = Color(0.15, 0.16, 0.18)
	track.position = Vector2(0, 20)
	track.size = Vector2(180, 8)
	text_block.add_child(track)
	var fill: ColorRect = ColorRect.new()
	fill.name = "HealthFill"
	fill.color = Color(0.36, 0.78, 0.4)
	fill.layout_mode = 1
	fill.anchor_bottom = 1.0
	fill.offset_right = 120.0
	track.add_child(fill)
	var veteran: Label = _card_label(text_block, "HudVeteran", 14)
	veteran.position = Vector2(188, 16)
	veteran.size = Vector2(180, 16)
	veteran.add_theme_color_override("font_color", Color(0.95, 0.82, 0.4))
	var built: Label = _card_label(text_block, "HudBuild", 14)
	built.visible = false
	built.position = Vector2(0, 20)
	built.size = Vector2(380, 16)
	var breakdown: Label = _card_label(text_block, "HudBreakdown", 14)
	breakdown.visible = false
	breakdown.position = Vector2(0, 20)
	breakdown.size = Vector2(380, 16)
	var commands: VBoxContainer = VBoxContainer.new()
	commands.name = "CommandRow"
	commands.custom_minimum_size = Vector2(0, 56)
	commands.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	commands.add_theme_constant_override("separation", 0)
	lines.add_child(commands)
	_message_lane()

func _message_lane() -> void:
	var lane: PanelContainer = PanelContainer.new()
	lane.name = "MessageLane"
	lane.visible = false
	lane.z_index = 9
	lane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lane.add_theme_stylebox_override("panel", _frame())
	_anchor(lane, 0.0, 1.0, 0.0, 1.0, 380.0, -188.0, 900.0, -136.0)
	add_child(lane)
	var radio: Label = Label.new()
	radio.name = "RadioLine"
	radio.visible = false
	radio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	radio.clip_text = true
	radio.max_lines_visible = 2
	radio.add_theme_font_size_override("font_size", 16)
	radio.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	lane.add_child(radio)

func _mode_button(row: HBoxContainer, node_name: String, text: String, icon_path: String) -> void:
	var button: Button = Button.new()
	button.name = node_name
	button.text = ""
	button.tooltip_text = text
	button.clip_text = false
	button.custom_minimum_size = Vector2(0, 40)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 14)
	_set_icon(button, icon_path)
	row.add_child(button)

func _tab_button(grid: GridContainer, node_name: String, text: String, icon_path: String) -> void:
	var button: Button = Button.new()
	button.name = node_name
	button.text = ""
	button.clip_text = false
	button.tooltip_text = text
	button.custom_minimum_size = Vector2(56, 40)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 11)
	_set_icon(button, icon_path)
	grid.add_child(button)

func _set_icon(button: Button, icon_path: String) -> void:
	var tex: Texture2D = Art.texture(icon_path)
	if tex == null:
		return
	button.icon = tex
	button.expand_icon = true

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
	style.content_margin_left = 2
	style.content_margin_right = 2
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style

func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_O:
		return
	var layer: Node = get_parent()
	if layer != null:
		var pause: CanvasItem = layer.find_child("PauseMenu", true, false) as CanvasItem
		if pause != null and pause.visible:
			return
	_goals_open = not _goals_open
	var view: Viewport = get_viewport()
	if view != null:
		view.set_input_as_handled()

func _open_menu() -> void:
	var layer: Node = get_parent()
	if layer == null:
		return
	var pause: CanvasItem = layer.find_child("PauseMenu", true, false) as CanvasItem
	if pause != null:
		pause.visible = true

func _seat_chrome() -> void:
	var hud: SMHud = get_meta("hud", null) as SMHud
	if hud != null and hud.phone:
		return
	_seat_context()
	_seat_message()
	_seat_objective()
	_seat_now_playing()
	var layer: Node = get_parent()
	if layer == null:
		return
	var help: CanvasItem = layer.find_child("HelpButton", true, false) as CanvasItem
	if help != null:
		help.visible = false

func _seat_context() -> void:
	var card: Control = get_node_or_null("UnitCard") as Control
	if card == null:
		return
	var width: float = 520.0
	var sidebar: float = size.x - 268.0
	var x: float = (size.x - width) * 0.5
	if x + width > sidebar:
		x = sidebar - width
	if x < 80.0:
		x = 80.0
		width = maxf(280.0, sidebar - 80.0)
	_anchor(card, 0.0, 1.0, 0.0, 1.0, x, -128.0, x + width, -8.0)
	var slots: Control = get_node_or_null("SelectionSlots") as Control
	if slots == null:
		return
	var slot_x: float = maxf(x + 12.0, 360.0)
	_anchor(slots, 0.0, 1.0, 0.0, 1.0, slot_x, -116.0, slot_x + 360.0, -68.0)

func _seat_message() -> void:
	var lane: Control = get_node_or_null("MessageLane") as Control
	var radio: Label = find_child("RadioLine", true, false) as Label
	if lane == null or radio == null:
		return
	var card: Control = get_node_or_null("UnitCard") as Control
	var x: float = card.offset_left if card != null else 380.0
	var width: float = 520.0
	if card != null:
		width = card.offset_right - card.offset_left
	_anchor(lane, 0.0, 1.0, 0.0, 1.0, x, -188.0, x + width, -136.0)
	lane.visible = radio.visible and radio.text != ""
	lane.modulate.a = radio.modulate.a

func _seat_objective() -> void:
	var layer: Node = get_parent()
	if layer == null:
		return
	var status: Label = layer.find_child("Status", true, false) as Label
	if status == null:
		return
	var shade: ColorRect = layer.get_node_or_null("ObjectiveShade") as ColorRect
	if shade == null:
		shade = ColorRect.new()
		shade.name = "ObjectiveShade"
		shade.color = Color(0.05, 0.06, 0.07, 0.88)
		shade.mouse_filter = Control.MOUSE_FILTER_STOP
		shade.z_index = 6
		layer.add_child(shade)
		layer.move_child(shade, 0)
	var mark: Label = layer.get_node_or_null("ObjectiveMark") as Label
	if mark == null:
		mark = Label.new()
		mark.name = "ObjectiveMark"
		mark.text = "☐"
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.z_index = 7
		mark.add_theme_font_size_override("font_size", 16)
		mark.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
		var face: Font = ThemeDB.fallback_font
		if face != null:
			mark.add_theme_font_override("font", face)
		layer.add_child(mark)
	var height: float = 120.0 if _goals_open else 28.0
	_anchor(shade, 0.0, 0.0, 0.0, 0.0, 72.0, 34.0, 432.0, 34.0 + height)
	_anchor(mark, 0.0, 0.0, 0.0, 0.0, 78.0, 36.0, 98.0, 60.0)
	status.z_index = 7
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if _goals_open else TextServer.AUTOWRAP_OFF
	status.clip_text = true
	status.max_lines_visible = 6 if _goals_open else 1
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status.custom_minimum_size = Vector2(0, 22)
	_anchor(status, 0.0, 0.0, 0.0, 0.0, 100.0, 36.0, 424.0, 34.0 + height)

func _seat_now_playing() -> void:
	var line: Control = get_node_or_null("NowPlaying") as Control
	if line == null:
		return
	if size.x < 1200.0:
		line.visible = false
		return
	line.visible = true
	var right: float = size.x - 276.0
	_anchor(line, 0.0, 0.0, 0.0, 0.0, right - 220.0, 36.0, right, 56.0)

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
