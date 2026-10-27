extends Control
## Three tabs. Every map, mission, and faction stays reachable.

var selected_map: String = ""
var play_button: Button
var playing_label: Label
var skirmish_panel: Control
var campaign_panel: Control
var faction_panel: Control
var map_cards: Array[Button] = []
var faction_cards: Array[Button] = []
var tab_buttons: Array[Button] = []
var act_lists: Dictionary[String, Control] = {}

func _ready() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var title: Label = Label.new()
	title.name = "GameTitle"
	title.text = "ASEAN 2031"
	title.position = Vector2(48, 16)
	title.theme_type_variation = "Header"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.95, 0.94, 0.9))
	add_child(title)
	_tab("Skirmish", "TabSkirmish", "skirmish", 48)
	_tab("Campaign", "TabCampaign", "campaign", 248)
	_tab("Faction", "TabFaction", "faction", 448)
	skirmish_panel = _panel("PanelSkirmish")
	campaign_panel = _panel("PanelCampaign")
	faction_panel = _panel("PanelFaction")
	_skirmish()
	_campaign()
	_faction()
	_bar()
	_show_tab("skirmish")
	_show_act("act_1")
	_mark_factions()
	_refresh_playing()
	_warm_shaders()
	var gear: Button = Button.new()
	gear.name = "SettingsButton"
	gear.text = "Settings"
	gear.position = Vector2(1060, 16)
	gear.custom_minimum_size = Vector2(160, 40)
	gear.add_theme_font_size_override("font_size", 18)
	_style_button(gear, Color(0.14, 0.15, 0.18), Color(0.55, 0.42, 0.18), false)
	gear.pressed.connect(_toggle_settings)
	add_child(gear)
	preload("res://game/settings_panel.gd").attach(self)
	preload("res://game/match_settings.gd").apply_scene(self)

func _skirmish() -> void:
	_card(skirmish_panel, "CardPhillips", "Phillips Channel", "Water", "res://game/phillips_channel.tscn", Vector2(48, 16))
	_card(skirmish_panel, "CardSopRuak", "Sop Ruak", "River", "res://game/sop_ruak.tscn", Vector2(348, 16))
	_card(skirmish_panel, "CardBurma", "Burma Road", "Land", "res://game/burma_road.tscn", Vector2(648, 16))
	_card(skirmish_panel, "CardAtolls", "Ten Degree Atolls", "Water", "res://game/ten_degree_atolls.tscn", Vector2(48, 124))
	_card(skirmish_panel, "CardMekong", "Mekong Delta", "River", "res://game/mekong_delta.tscn", Vector2(348, 124))
	_card(skirmish_panel, "CardChiang", "Siege of Chiang Rai", "River", "res://game/chiang_rai.tscn", Vector2(648, 124))
	playing_label = Label.new()
	playing_label.name = "PlayingAs"
	playing_label.position = Vector2(48, 236)
	playing_label.add_theme_font_size_override("font_size", 16)
	playing_label.add_theme_color_override("font_color", Color(0.78, 0.8, 0.84))
	skirmish_panel.add_child(playing_label)
	var hint: Label = Label.new()
	hint.text = "Pick a map, then Play. The enemy builds, expands, and attacks."
	hint.position = Vector2(48, 268)
	hint.add_theme_color_override("font_color", Color(0.62, 0.66, 0.7))
	skirmish_panel.add_child(hint)
	var grey: Button = Button.new()
	grey.name = "GreyboxButton"
	grey.text = "Greybox"
	grey.position = Vector2(48, 460)
	grey.custom_minimum_size = Vector2(160, 40)
	grey.tooltip_text = "Systems demo. Camera only."
	_style_button(grey, Color(0.12, 0.13, 0.15), Color(0.28, 0.3, 0.34), false)
	grey.pressed.connect(_open.bind("res://game/greybox.tscn"))
	skirmish_panel.add_child(grey)
	var grey_note: Label = Label.new()
	grey_note.text = "Systems demo. Camera only."
	grey_note.position = Vector2(224, 468)
	grey_note.add_theme_color_override("font_color", Color(0.55, 0.58, 0.62))
	skirmish_panel.add_child(grey_note)
	play_button = Button.new()
	play_button.name = "PlayButton"
	play_button.text = "Play"
	play_button.theme_type_variation = "HeaderButton"
	play_button.position = Vector2(980, 448)
	play_button.custom_minimum_size = Vector2(200, 56)
	play_button.disabled = true
	play_button.add_theme_font_size_override("font_size", 22)
	_style_button(play_button, Color(0.45, 0.16, 0.14), Color(0.86, 0.62, 0.28), true)
	play_button.pressed.connect(_play)
	skirmish_panel.add_child(play_button)

func _campaign() -> void:
	var note: Label = Label.new()
	note.text = "Start with Kokang and Mogok. The match opens with a short lesson."
	note.position = Vector2(48, 8)
	note.add_theme_color_override("font_color", Color(0.7, 0.74, 0.78))
	campaign_panel.add_child(note)
	var acts: PackedStringArray = SMCampaign.act_ids()
	for i: int in acts.size():
		var act: String = acts[i]
		var b: Button = Button.new()
		b.name = _act_button_name(act)
		b.text = SMCampaign.act_title(act)
		b.theme_type_variation = "HeaderButton"
		b.position = Vector2(48, 48 + i * 56)
		b.custom_minimum_size = Vector2(180, 44)
		_style_button(b, Color(0.12, 0.14, 0.18), Color(0.35, 0.38, 0.42), false)
		b.pressed.connect(_show_act.bind(act))
		campaign_panel.add_child(b)
		var scroll: ScrollContainer = ScrollContainer.new()
		scroll.name = _act_list_name(act)
		scroll.position = Vector2(268, 48)
		scroll.size = Vector2(960, 470)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var box: VBoxContainer = VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.custom_minimum_size = Vector2(900, 0)
		box.add_theme_constant_override("separation", 4)
		scroll.add_child(box)
		for mission_id: String in SMCampaign.act_missions(act):
			_mission_row(box, mission_id)
		campaign_panel.add_child(scroll)
		act_lists[act] = scroll

func _faction() -> void:
	var note: Label = Label.new()
	note.text = "The selected side is who you play on the next skirmish."
	note.position = Vector2(48, 8)
	note.add_theme_color_override("font_color", Color(0.7, 0.74, 0.78))
	faction_panel.add_child(note)
	_faction_card("gtfc", "FactionGtfc", Vector2(48, 48))
	_faction_card("nmrf", "FactionNmrf", Vector2(440, 48))
	_faction_card("mvd", "FactionMvd", Vector2(832, 48))
	_yard_link("NmrfYardButton", "res://game/nmrf_yard.tscn", Vector2(440, 300))
	_yard_link("MvdYardButton", "res://game/mvd_yard.tscn", Vector2(832, 300))

func _bar() -> void:
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.04, 0.045, 0.05)
	shade.position = Vector2(0, 648)
	shade.size = Vector2(1280, 72)
	add_child(shade)
	var bar: Label = Label.new()
	bar.name = "ControlBar"
	bar.text = "Left click selects    Right click moves or attacks    F ability    Edge pan    Wheel zoom"
	bar.position = Vector2(48, 670)
	bar.add_theme_font_size_override("font_size", 16)
	bar.add_theme_color_override("font_color", Color(0.8, 0.82, 0.86))
	add_child(bar)

func _panel(node_name: String) -> Control:
	var panel: Control = Control.new()
	panel.name = node_name
	panel.position = Vector2(0, 104)
	panel.size = Vector2(1280, 540)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	return panel

func _tab(caption: String, node_name: String, which: String, x: float) -> void:
	var b: Button = Button.new()
	b.name = node_name
	b.text = caption
	b.theme_type_variation = "HeaderButton"
	b.position = Vector2(x, 56)
	b.custom_minimum_size = Vector2(180, 38)
	b.add_theme_font_size_override("font_size", 18)
	_style_button(b, Color(0.14, 0.15, 0.18), Color(0.4, 0.42, 0.46), false)
	b.pressed.connect(_show_tab.bind(which))
	add_child(b)
	tab_buttons.append(b)

func _card(panel: Control, node_name: String, map_name: String, terrain: String, path: String, pos: Vector2) -> void:
	var b: Button = Button.new()
	b.name = node_name
	b.text = ""
	b.position = pos
	b.custom_minimum_size = Vector2(280, 92)
	b.size = Vector2(280, 92)
	_style_button(b, Color(0.11, 0.12, 0.15), Color(0.3, 0.32, 0.36), false)
	var title: Label = Label.new()
	title.name = "Title"
	title.text = map_name
	title.theme_type_variation = "Header"
	title.position = Vector2(16, 16)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.95, 0.94, 0.9))
	b.add_child(title)
	var line: Label = Label.new()
	line.name = "Terrain"
	line.text = terrain
	line.position = Vector2(16, 50)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_font_size_override("font_size", 15)
	line.add_theme_color_override("font_color", Color(0.66, 0.72, 0.78))
	b.add_child(line)
	b.pressed.connect(_choose_map.bind(path, b))
	panel.add_child(b)
	map_cards.append(b)

func _mission_row(box: VBoxContainer, mission_id: String) -> void:
	var b: Button = Button.new()
	b.name = "Mission_%s" % mission_id
	b.text = SMCampaign.title_of(mission_id)
	b.theme_type_variation = "HeaderButton"
	b.custom_minimum_size = Vector2(720, 34)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_style_button(b, Color(0.12, 0.13, 0.16), Color(0.32, 0.34, 0.38), false)
	b.pressed.connect(_start_mission.bind(mission_id))
	box.add_child(b)
	var brief: Label = Label.new()
	brief.name = "Brief_%s" % mission_id
	brief.text = SMCampaign.briefing_of(mission_id)
	brief.autowrap_mode = TextServer.AUTOWRAP_OFF
	brief.custom_minimum_size = Vector2(880, 22)
	brief.add_theme_font_size_override("font_size", 15)
	brief.add_theme_color_override("font_color", Color(0.68, 0.72, 0.76))
	box.add_child(brief)
	if SMSave.has(mission_id):
		var done: Label = Label.new()
		done.name = "Done_%s" % mission_id
		done.text = "Done"
		done.position = Vector2(620, 4)
		done.mouse_filter = Control.MOUSE_FILTER_IGNORE
		done.add_theme_color_override("font_color", Color(0.55, 0.78, 0.45))
		b.add_child(done)

func _warm_shaders() -> void:
	var holder: Node3D = Node3D.new()
	holder.name = "ShaderWarmup"
	holder.visible = false
	add_child(holder)
	var paths: PackedStringArray = PackedStringArray([
		"res://game/shaders/cryo_freeze_overlay.gdshader",
		"res://game/shaders/aegis_dome_shield.gdshader",
		"res://game/shaders/slag_corrosion_pool.gdshader",
	])
	for i: int in paths.size():
		var mesh: MeshInstance3D = MeshInstance3D.new()
		mesh.name = "Warm%d" % i
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(0.2, 0.2, 0.2)
		mesh.mesh = box
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = load(paths[i]) as Shader
		mesh.material_override = mat
		holder.add_child(mesh)

func _faction_card(id: String, node_name: String, pos: Vector2) -> void:
	var saved: String = SMFront.faction_id
	SMFront.faction_id = id
	var b: Button = Button.new()
	b.name = node_name
	b.text = ""
	b.position = pos
	b.custom_minimum_size = Vector2(360, 230)
	b.size = Vector2(360, 230)
	b.set_meta("faction", id)
	_style_button(b, Color(0.1, 0.11, 0.14), Color(0.3, 0.32, 0.36), false)
	var title: Label = Label.new()
	title.name = "Title"
	title.text = SMFront.display_name()
	title.theme_type_variation = "Header"
	title.position = Vector2(18, 16)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.95, 0.94, 0.9))
	b.add_child(title)
	var colors: Label = Label.new()
	colors.name = "Colors"
	colors.text = SMFront.color_line()
	colors.position = Vector2(18, 58)
	colors.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colors.add_theme_font_size_override("font_size", 16)
	colors.add_theme_color_override("font_color", Color(0.82, 0.84, 0.86))
	b.add_child(colors)
	var style: Label = Label.new()
	style.name = "Style"
	style.text = SMFront.style_line()
	style.position = Vector2(18, 88)
	style.mouse_filter = Control.MOUSE_FILTER_IGNORE
	style.add_theme_font_size_override("font_size", 16)
	style.add_theme_color_override("font_color", Color(0.7, 0.74, 0.78))
	b.add_child(style)
	var primary: ColorRect = ColorRect.new()
	primary.name = "Primary"
	primary.color = SMFront.primary()
	primary.position = Vector2(18, 132)
	primary.size = Vector2(56, 56)
	primary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(primary)
	var accent: ColorRect = ColorRect.new()
	accent.name = "Accent"
	accent.color = SMFront.accent()
	accent.position = Vector2(86, 132)
	accent.size = Vector2(56, 56)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(accent)
	b.pressed.connect(_choose_faction.bind(id))
	faction_panel.add_child(b)
	faction_cards.append(b)
	SMFront.faction_id = saved

func _yard_link(node_name: String, path: String, pos: Vector2) -> void:
	var b: Button = Button.new()
	b.name = node_name
	b.text = "Open yard"
	b.position = pos
	b.custom_minimum_size = Vector2(180, 40)
	_style_button(b, Color(0.14, 0.16, 0.14), Color(0.35, 0.42, 0.32), false)
	b.pressed.connect(_open.bind(path))
	faction_panel.add_child(b)

func _show_tab(which: String) -> void:
	skirmish_panel.visible = which == "skirmish"
	campaign_panel.visible = which == "campaign"
	faction_panel.visible = which == "faction"
	for tab: Button in tab_buttons:
		var on: bool = false
		if which == "skirmish":
			on = tab.name == "TabSkirmish"
		elif which == "campaign":
			on = tab.name == "TabCampaign"
		else:
			on = tab.name == "TabFaction"
		var fill: Color = Color(0.22, 0.18, 0.12) if on else Color(0.12, 0.13, 0.16)
		var edge: Color = Color(0.86, 0.7, 0.32) if on else Color(0.32, 0.34, 0.38)
		_style_button(tab, fill, edge, on)
	_refresh_playing()

func _show_act(act: String) -> void:
	var keys: Array = act_lists.keys()
	for key: Variant in keys:
		var panel: Control = act_lists[str(key)]
		panel.visible = str(key) == act

func _choose_map(path: String, card: Button) -> void:
	selected_map = path
	play_button.disabled = false
	for other: Button in map_cards:
		var on: bool = other == card
		var fill: Color = Color(0.18, 0.16, 0.12) if on else Color(0.11, 0.12, 0.15)
		var edge: Color = Color(0.86, 0.7, 0.32) if on else Color(0.3, 0.32, 0.36)
		_style_button(other, fill, edge, on)

func _choose_faction(id: String) -> void:
	SMFront.faction_id = id
	_mark_factions()
	_refresh_playing()

func _mark_factions() -> void:
	for card: Button in faction_cards:
		var on: bool = str(card.get_meta("faction")) == SMFront.current()
		var fill: Color = Color(0.18, 0.16, 0.12) if on else Color(0.1, 0.11, 0.14)
		var edge: Color = Color(0.86, 0.7, 0.32) if on else Color(0.3, 0.32, 0.36)
		_style_button(card, fill, edge, on)

func _refresh_playing() -> void:
	if playing_label != null:
		playing_label.text = "Next skirmish: %s" % SMFront.banner()

func _toggle_settings() -> void:
	var panel: Control = find_child("SettingsPanel", true, false) as Control
	if panel == null:
		return
	panel.visible = not panel.visible
	if panel.visible and panel.has_method("pull"):
		panel.call("pull")

func _play() -> void:
	if selected_map == "":
		return
	_open(selected_map)

func _start_mission(mission_id: String) -> void:
	if mission_id == "kokang":
		_open("res://game/mission_kokang.tscn")
		return
	SMCampaign.selected = mission_id
	_open("res://game/campaign_mission.tscn")

func _open(path: String) -> void:
	get_tree().change_scene_to_file(path)

func _act_button_name(act: String) -> String:
	if act == "act_1":
		return "ActI"
	if act == "act_2":
		return "ActII"
	return "ActIII"

func _act_list_name(act: String) -> String:
	if act == "act_1":
		return "ActIMissions"
	if act == "act_2":
		return "ActIIMissions"
	return "ActIIIMissions"

func _style_button(b: Button, fill: Color, edge: Color, strong: bool) -> void:
	var width: int = 2 if strong else 1
	b.add_theme_stylebox_override("normal", _box(fill, edge, width))
	b.add_theme_stylebox_override("hover", _box(fill.lightened(0.08), edge.lightened(0.1), width))
	b.add_theme_stylebox_override("pressed", _box(fill.darkened(0.06), edge, width))
	b.add_theme_stylebox_override("disabled", _box(Color(0.1, 0.1, 0.11), Color(0.22, 0.22, 0.24), 1))
	b.add_theme_color_override("font_color", Color(0.94, 0.95, 0.96))
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.47, 0.5))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))

func _box(fill: Color, edge: Color, width: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(width)
	box.set_corner_radius_all(6)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box
