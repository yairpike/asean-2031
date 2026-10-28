extends Control
## Text menu. Campaign opens GTFC, NMRF, and MVD under the item, then the mission list.

const Plate = preload("res://game/menu_plate.gd")
const Backdrop = preload("res://game/menu_backdrop.gd")
const Lan = preload("res://game/lan_link.gd")
const VERSION: String = "v0.9.0"

var selected_map: String = ""
var play_button: Button
var playing_label: Label
var skirmish_panel: Control
var campaign_panel: Control
var faction_panel: Control
var faction_submenu: Control
var backdrop: Control
var multi_note: Label
var lan_panel: Control
var map_cards: Array[Button] = []
var faction_cards: Array[Button] = []
var tab_buttons: Array[Button] = []
var act_lists: Dictionary[String, Control] = {}
var _pad_cool: float = 0.0
var _save_polled: bool = false
var _faction_i: int = 0
var _menu_tab: String = "main"

func _ready() -> void:
	preload("res://game/font_faces.gd").pin()
	backdrop = Backdrop.new() as Control
	backdrop.name = "MenuBackdrop"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var title: Label = Label.new()
	title.name = "GameTitle"
	title.text = "ASEAN 2031"
	title.position = Vector2(48, 16)
	title.theme_type_variation = "Header"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	add_child(title)
	var rule: ColorRect = ColorRect.new()
	rule.name = "TitleRule"
	rule.color = Color(1, 1, 1, 0.9)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rule)
	var version: Label = Label.new()
	version.name = "VersionMark"
	version.text = VERSION
	version.mouse_filter = Control.MOUSE_FILTER_IGNORE
	version.add_theme_font_size_override("font_size", 14)
	version.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	add_child(version)
	var now_playing: Label = Label.new()
	now_playing.name = "NowPlaying"
	now_playing.position = Vector2(320, 22)
	now_playing.size = Vector2(720, 24)
	now_playing.clip_text = true
	now_playing.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	now_playing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	now_playing.add_theme_font_size_override("font_size", 16)
	now_playing.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	add_child(now_playing)
	_tab("CAMPAIGN", "TabCampaign", "campaign", 48)
	faction_submenu = Control.new()
	faction_submenu.name = "FactionSubmenu"
	faction_submenu.visible = false
	faction_submenu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(faction_submenu)
	_tab("SKIRMISH", "TabSkirmish", "skirmish", 248)
	_tab("Side", "TabFaction", "faction", 448)
	var side: Button = find_child("TabFaction", true, false) as Button
	if side != null:
		side.visible = false
	skirmish_panel = _panel("PanelSkirmish")
	campaign_panel = _panel("PanelCampaign")
	faction_panel = _panel("PanelFaction")
	_skirmish()
	_campaign()
	_faction()
	_bar()
	_show_tab("main")
	_show_act("act_1")
	_mark_factions()
	_refresh_playing()
	_warm_shaders()
	var gear: Button = Plate.new() as Button
	gear.name = "SettingsButton"
	gear.text = "SETTINGS"
	gear.theme_type_variation = "HeaderButton"
	gear.pressed.connect(_toggle_settings)
	add_child(gear)
	tab_buttons.append(gear)
	var multi: Button = Plate.new() as Button
	multi.name = "TabMultiplayer"
	multi.text = "MULTIPLAYER"
	multi.theme_type_variation = "HeaderButton"
	multi.pressed.connect(_show_tab.bind("multi"))
	add_child(multi)
	tab_buttons.append(multi)
	var quit: Button = Plate.new() as Button
	quit.name = "QuitButton"
	quit.text = "Quit"
	quit.pressed.connect(_quit)
	add_child(quit)
	multi_note = Label.new()
	multi_note.name = "MultiplayerNote"
	multi_note.visible = false
	multi_note.text = Lan.lan_note(not Lan.show_controls())
	multi_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	multi_note.add_theme_font_size_override("font_size", 18)
	multi_note.add_theme_color_override("font_color", Color(1, 1, 1))
	add_child(multi_note)
	_lan_panel()
	set_process_unhandled_input(true)
	SMSave.pull_web()
	preload("res://game/settings_panel.gd").attach(self)
	preload("res://game/match_settings.gd").apply_scene(self)
	mark_difficulty()
	preload("res://game/match_audio.gd").arm(self, "menu")
	_loading_plate()
	_layout_menu(_view_size())

func _lan_panel() -> void:
	lan_panel = Control.new()
	lan_panel.name = "LanPanel"
	lan_panel.visible = false
	lan_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lan_panel)
	var host: Button = Button.new()
	host.name = "HostLan"
	host.text = "Host LAN"
	host.position = Vector2(0.0, 0.0)
	host.custom_minimum_size = Vector2(160.0, 36.0)
	host.pressed.connect(_host_lan)
	lan_panel.add_child(host)
	var join: Button = Button.new()
	join.name = "JoinLan"
	join.text = "Join LAN"
	join.position = Vector2(176.0, 0.0)
	join.custom_minimum_size = Vector2(160.0, 36.0)
	join.pressed.connect(_join_lan)
	lan_panel.add_child(join)
	var addr: LineEdit = LineEdit.new()
	addr.name = "LanAddress"
	addr.text = "127.0.0.1"
	addr.placeholder_text = "127.0.0.1"
	addr.position = Vector2(0.0, 48.0)
	addr.size = Vector2(336.0, 36.0)
	lan_panel.add_child(addr)
	var status: Label = Label.new()
	status.name = "LanStatus"
	status.text = "Pick host or join."
	status.position = Vector2(0.0, 96.0)
	status.size = Vector2(420.0, 48.0)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lan_panel.add_child(status)
	var found: ItemList = ItemList.new()
	found.name = "LanFound"
	found.position = Vector2(0.0, 148.0)
	found.size = Vector2(420.0, 96.0)
	found.item_selected.connect(_pick_lan)
	lan_panel.add_child(found)
	var lobby: Label = Label.new()
	lobby.name = "LanLobby"
	lobby.position = Vector2(0.0, 250.0)
	lobby.size = Vector2(440.0, 36.0)
	lobby.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lobby.text = "Pick a faction and a map, then ready up."
	lan_panel.add_child(lobby)
	_lan_choice("LanFaction_gtfc", "GTFC", Vector2(0.0, 290.0), _lan_faction.bind("gtfc"))
	_lan_choice("LanFaction_nmrf", "NMRF", Vector2(88.0, 290.0), _lan_faction.bind("nmrf"))
	_lan_choice("LanFaction_mvd", "MVD", Vector2(176.0, 290.0), _lan_faction.bind("mvd"))
	_lan_choice("LanFaction_black_market", "Market", Vector2(264.0, 290.0), _lan_faction.bind("black_market"))
	_lan_choice("LanMap_phillips_channel", "Phillips", Vector2(0.0, 330.0), _lan_map_pick.bind("res://game/phillips_channel.tscn"))
	_lan_choice("LanMap_sop_ruak", "Sop Ruak", Vector2(88.0, 330.0), _lan_map_pick.bind("res://game/sop_ruak.tscn"))
	_lan_choice("LanMap_burma_road", "Burma", Vector2(176.0, 330.0), _lan_map_pick.bind("res://game/burma_road.tscn"))
	_lan_choice("LanMap_ten_degree_atolls", "Atolls", Vector2(264.0, 330.0), _lan_map_pick.bind("res://game/ten_degree_atolls.tscn"))
	_lan_choice("LanMap_mekong_delta", "Mekong", Vector2(0.0, 368.0), _lan_map_pick.bind("res://game/mekong_delta.tscn"))
	_lan_choice("LanMap_chiang_rai", "Chiang Rai", Vector2(88.0, 368.0), _lan_map_pick.bind("res://game/chiang_rai.tscn"))
	var ready: Button = Button.new()
	ready.name = "LanReady"
	ready.text = "Ready"
	ready.position = Vector2(264.0, 368.0)
	ready.custom_minimum_size = Vector2(120.0, 32.0)
	ready.pressed.connect(_lan_ready)
	lan_panel.add_child(ready)
	var count: Label = Label.new()
	count.name = "LanCount"
	count.position = Vector2(0.0, 408.0)
	count.size = Vector2(420.0, 24.0)
	count.text = ""
	lan_panel.add_child(count)
	var chat: Label = Label.new()
	chat.name = "LanChat"
	chat.position = Vector2(0.0, 432.0)
	chat.size = Vector2(420.0, 48.0)
	chat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	chat.text = ""
	lan_panel.add_child(chat)
	var entry: LineEdit = LineEdit.new()
	entry.name = "LanChatLine"
	entry.placeholder_text = "Chat"
	entry.position = Vector2(0.0, 484.0)
	entry.size = Vector2(300.0, 32.0)
	lan_panel.add_child(entry)
	var send: Button = Button.new()
	send.name = "LanChatSend"
	send.text = "Send"
	send.position = Vector2(308.0, 484.0)
	send.custom_minimum_size = Vector2(80.0, 32.0)
	send.pressed.connect(_lan_say)
	lan_panel.add_child(send)

func _host_lan() -> void:
	var err: Error = Lan.open_host()
	var status: Label = find_child("LanStatus", true, false) as Label
	if status == null:
		return
	if err == OK:
		Lan.faction = SMFront.faction_id
		if selected_map != "":
			Lan.map_path = selected_map
		status.text = "Waiting on port %d." % Lan.port
	else:
		status.text = "The port is busy."

func _join_lan() -> void:
	var addr: LineEdit = find_child("LanAddress", true, false) as LineEdit
	var dest: String = "127.0.0.1"
	if addr != null and addr.text.strip_edges() != "":
		dest = addr.text.strip_edges()
	Lan.faction = SMFront.faction_id
	var err: Error = Lan.open_client(dest)
	var status: Label = find_child("LanStatus", true, false) as Label
	if status == null:
		return
	if err == OK:
		status.text = "Connecting to %s." % dest
	else:
		status.text = "Could not join."

func _lan_map() -> String:
	if selected_map != "":
		return selected_map
	return "res://game/phillips_channel.tscn"

func _pick_lan(index: int) -> void:
	var ip: String = Lan.host_address(index)
	if ip == "":
		return
	var addr: LineEdit = find_child("LanAddress", true, false) as LineEdit
	if addr != null:
		addr.text = ip
	var status: Label = find_child("LanStatus", true, false) as Label
	if status != null:
		status.text = "Found %s." % ip

func _fill_lan() -> void:
	var found: ItemList = find_child("LanFound", true, false) as ItemList
	if found == null:
		return
	var rows: PackedStringArray = Lan.hosts()
	var same: bool = found.item_count == rows.size()
	if same:
		for i: int in rows.size():
			if found.get_item_text(i) != rows[i]:
				same = false
				break
	if same:
		return
	found.clear()
	for row: String in rows:
		found.add_item(row)

func _lan_poll(delta: float) -> void:
	if not Lan.show_controls():
		return
	if lan_panel != null and lan_panel.visible and Lan.role != "host":
		Lan.listen()
		Lan.gather()
		_fill_lan()
	if Lan.role == "":
		return
	Lan.pump()
	var raw: String = Lan.take()
	while raw != "":
		_lan_packet(raw)
		raw = Lan.take()
	if Lan.seat().tick_lobby(delta) == "start":
		SMFront.faction_id = Lan.faction
		_open(Lan.map_path)
		return
	_paint_lobby()

func _lan_packet(raw: String) -> void:
	var kind: String = Lan.ingest(raw)
	if kind == "start" and Lan.role == "client":
		_open("res://game/lan_mirror.tscn")

func _lan_choice(node_name: String, caption: String, at: Vector2, fn: Callable) -> void:
	var b: Button = Button.new()
	b.name = node_name
	b.text = caption
	b.position = at
	b.custom_minimum_size = Vector2(84.0, 32.0)
	b.clip_text = true
	b.pressed.connect(fn)
	lan_panel.add_child(b)

func _lan_faction(id: String) -> void:
	if Lan.role == "host":
		SMFront.faction_id = id
	Lan.seat().pick_faction(id)
	_paint_lobby()

func _lan_map_pick(path: String) -> void:
	if Lan.role != "host":
		return
	selected_map = path
	Lan.seat().pick_map(path)
	_paint_lobby()

func _lan_ready() -> void:
	if Lan.role == "":
		Lan.seat().host_ready = not Lan.seat().host_ready
		_paint_lobby()
		return
	var on: bool = not (Lan.seat().host_ready if Lan.role == "host" else Lan.seat().guest_ready)
	Lan.seat().set_ready(on)
	_paint_lobby()

func _lan_say() -> void:
	var entry: LineEdit = find_child("LanChatLine", true, false) as LineEdit
	if entry == null:
		return
	if Lan.role == "":
		return
	Lan.seat().say(entry.text)
	entry.text = ""
	_paint_lobby()

func _paint_lobby() -> void:
	var lobby: Label = find_child("LanLobby", true, false) as Label
	var chat: Label = find_child("LanChat", true, false) as Label
	var count: Label = find_child("LanCount", true, false) as Label
	if lobby != null:
		var guest: String = Lan.seat().guest_faction if Lan.seat().guest_joined else "waiting"
		lobby.text = "Host %s %s    Guest %s %s" % [Lan.seat().faction, "ready" if Lan.seat().host_ready else "open", guest, "ready" if Lan.seat().guest_ready else "open"]
	if chat != null:
		var lines: String = ""
		for line: String in Lan.seat().chat_lines:
			if lines != "":
				lines += "\n"
			lines += line
		chat.text = lines
	if count != null:
		count.text = "Starting in %d." % Lan.seat().count_shown if Lan.seat().counting else ""

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
	playing_label.add_theme_color_override("font_color", Color(1, 1, 1))
	skirmish_panel.add_child(playing_label)
	var hint: Label = Label.new()
	hint.text = "Pick a map, then Play. The enemy builds, expands, and attacks."
	hint.position = Vector2(48, 268)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	skirmish_panel.add_child(hint)
	_difficulty_row(skirmish_panel, "Skirmish", Vector2(48, 308))
	var grey: Button = Plate.new() as Button
	grey.name = "GreyboxButton"
	grey.text = "Greybox"
	grey.custom_minimum_size = Vector2(180, 44)
	grey.tooltip_text = "Systems demo. Camera only."
	grey.pressed.connect(_open.bind("res://game/greybox.tscn"))
	skirmish_panel.add_child(grey)
	var grey_note: Label = Label.new()
	grey_note.text = "Systems demo. Camera only."
	grey_note.position = Vector2(224, 468)
	grey_note.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	skirmish_panel.add_child(grey_note)
	play_button = Plate.new() as Button
	play_button.name = "PlayButton"
	play_button.text = "Play"
	play_button.custom_minimum_size = Vector2(200, 52)
	play_button.disabled = true
	play_button.pressed.connect(_play)
	skirmish_panel.add_child(play_button)

func _campaign() -> void:
	var note: Label = Label.new()
	note.text = "Start with Kokang and Mogok. The match opens with a short lesson."
	note.position = Vector2(48, 8)
	note.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	campaign_panel.add_child(note)
	_difficulty_row(campaign_panel, "Campaign", Vector2(48, 492))
	var acts: PackedStringArray = SMCampaign.act_ids()
	for act: String in acts:
		var b: Button = Plate.new() as Button
		b.name = _act_button_name(act)
		b.text = SMCampaign.act_title(act)
		b.custom_minimum_size = Vector2(180, 44)
		b.pressed.connect(_show_act.bind(act))
		campaign_panel.add_child(b)
		var scroll: ScrollContainer = ScrollContainer.new()
		scroll.name = _act_list_name(act)
		scroll.position = Vector2(268, 48)
		scroll.size = Vector2(960, 430)
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
	note.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	faction_panel.add_child(note)
	_faction_card("gtfc", "FactionGtfc", Vector2(48, 48))
	_faction_card("nmrf", "FactionNmrf", Vector2(440, 48))
	_faction_card("mvd", "FactionMvd", Vector2(832, 48))
	_yard_link("NmrfYardButton", "res://game/nmrf_yard.tscn", Vector2(440, 300))
	_yard_link("MvdYardButton", "res://game/mvd_yard.tscn", Vector2(832, 300))

func _bar() -> void:
	var bar: Label = Label.new()
	bar.name = "ControlBar"
	bar.text = "Left click selects    Right click moves or attacks    F ability    Edge pan    Wheel zoom"
	bar.position = Vector2(48, 670)
	bar.add_theme_font_size_override("font_size", 13)
	bar.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)

func _panel(node_name: String) -> Control:
	var panel: Control = Control.new()
	panel.name = node_name
	panel.position = Vector2(0, 104)
	panel.size = Vector2(1280, 540)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	return panel

func _tab(caption: String, node_name: String, which: String, _x: float) -> void:
	var b: Button = Plate.new() as Button
	b.name = node_name
	b.text = caption
	if node_name == "TabCampaign" or node_name == "TabSkirmish":
		b.theme_type_variation = "HeaderButton"
	if which == "campaign":
		b.pressed.connect(_expand_campaign)
	else:
		b.pressed.connect(_show_tab.bind(which))
	add_child(b)
	tab_buttons.append(b)

func _card(panel: Control, node_name: String, map_name: String, terrain: String, path: String, pos: Vector2) -> void:
	var b: Button = Plate.new() as Button
	b.name = node_name
	b.text = ""
	b.position = pos
	b.custom_minimum_size = Vector2(280, 72)
	b.size = Vector2(280, 72)
	var title: Label = Label.new()
	title.name = "Title"
	title.text = map_name
	title.position = Vector2(16, 16)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	b.add_child(title)
	var line: Label = Label.new()
	line.name = "Terrain"
	line.text = terrain
	line.position = Vector2(16, 50)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_font_size_override("font_size", 15)
	line.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	b.add_child(line)
	b.pressed.connect(_choose_map.bind(path, b))
	panel.add_child(b)
	map_cards.append(b)

func _mission_row(box: VBoxContainer, mission_id: String) -> void:
	var b: Button = Plate.new() as Button
	b.name = "Mission_%s" % mission_id
	b.text = SMCampaign.title_of(mission_id)
	b.custom_minimum_size = Vector2(720, 44)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(_start_mission.bind(mission_id))
	box.add_child(b)
	var brief: Label = Label.new()
	brief.name = "Brief_%s" % mission_id
	brief.text = SMCampaign.briefing_of(mission_id)
	brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	brief.custom_minimum_size = Vector2(880, 66)
	brief.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brief.add_theme_font_size_override("font_size", 15)
	brief.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	box.add_child(brief)
	_ensure_done(b, mission_id)

func _process(delta: float) -> void:
	_lan_poll(delta)
	if not _save_polled and SMSave.poll_web():
		_save_polled = true
		for id: String in SMCampaign.ids():
			var button: Button = find_child("Mission_%s" % id, true, false) as Button
			_ensure_done(button, id)
	_pad_cool = maxf(0.0, _pad_cool - delta)
	if _pad_cool > 0.0:
		return
	var settings: Control = find_child("SettingsPanel", true, false) as Control
	if settings != null and settings.visible:
		return
	var y_axis: float = Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	var x_axis: float = Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	if absf(y_axis) > 0.55:
		_move_focus(1 if y_axis > 0.0 else -1)
		_pad_cool = 0.24
	elif absf(x_axis) > 0.55:
		_move_faction(1 if x_axis > 0.0 else -1)
		_pad_cool = 0.24

func _ensure_done(button: Button, mission_id: String) -> void:
	if button == null or not SMSave.has(mission_id):
		return
	if button.find_child("Done_%s" % mission_id, true, false) != null:
		return
	var done: Label = Label.new()
	done.name = "Done_%s" % mission_id
	done.text = "Done"
	done.position = Vector2(620, 4)
	done.mouse_filter = Control.MOUSE_FILTER_IGNORE
	done.add_theme_color_override("font_color", Color(1, 1, 1))
	button.add_child(done)

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
	var b: Button = Plate.new() as Button
	b.name = node_name
	b.text = ""
	b.position = pos
	b.custom_minimum_size = Vector2(300, 58)
	b.size = Vector2(300, 58)
	b.set_meta("faction", id)
	var title: Label = Label.new()
	title.name = "Title"
	title.text = SMFront.display_name()
	title.position = Vector2(2, 2)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	b.add_child(title)
	var colors: Label = Label.new()
	colors.name = "Colors"
	colors.text = SMFront.color_line()
	colors.visible = false
	colors.position = Vector2(120, 6)
	colors.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colors.add_theme_font_size_override("font_size", 12)
	colors.add_theme_color_override("font_color", Color(1, 1, 1))
	b.add_child(colors)
	var style: Label = Label.new()
	style.name = "Style"
	style.text = SMFront.style_line()
	style.position = Vector2(2, 22)
	style.visible = false
	style.mouse_filter = Control.MOUSE_FILTER_IGNORE
	style.add_theme_font_size_override("font_size", 13)
	style.add_theme_color_override("font_color", Color(1, 1, 1))
	b.add_child(style)
	var primary: ColorRect = ColorRect.new()
	primary.name = "Primary"
	primary.color = SMFront.primary()
	primary.position = Vector2(78, 8)
	primary.size = Vector2(8, 8)
	primary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(primary)
	var accent: ColorRect = ColorRect.new()
	accent.name = "Accent"
	accent.color = SMFront.accent()
	accent.position = Vector2(232, 8)
	accent.size = Vector2(16, 16)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(accent)
	b.pressed.connect(_choose_faction.bind(id))
	b.mouse_entered.connect(_preview_faction.bind(id))
	b.mouse_exited.connect(_preview_faction.bind(""))
	b.add_theme_font_size_override("font_size", 16)
	b.visible = false
	add_child(b)
	faction_cards.append(b)
	SMFront.faction_id = saved

func _yard_link(node_name: String, path: String, pos: Vector2) -> void:
	var b: Button = Plate.new() as Button
	b.name = node_name
	b.text = "Open yard"
	b.position = pos
	b.custom_minimum_size = Vector2(180, 48)
	b.pressed.connect(_open.bind(path))
	faction_panel.add_child(b)

func _set_submenu(open: bool) -> void:
	if faction_submenu != null:
		faction_submenu.visible = open
	for card: Button in faction_cards:
		card.visible = open
	var campaign: Button = find_child("TabCampaign", true, false) as Button
	if campaign != null:
		campaign.set_meta("mark", "chevron" if open else "arrow")
		campaign.queue_redraw()

func _expand_campaign() -> void:
	_set_submenu(true)
	_show_tab("main")

func _show_tab(which: String) -> void:
	_menu_tab = which
	_show_menu_chrome()
	skirmish_panel.visible = which == "skirmish"
	campaign_panel.visible = which == "campaign"
	faction_panel.visible = which == "faction"
	if multi_note != null:
		multi_note.visible = which == "multi"
	if lan_panel != null:
		lan_panel.visible = which == "multi" and Lan.show_controls()
	if which == "skirmish" or which == "multi":
		_set_submenu(false)
	elif which == "campaign" or which == "faction":
		_set_submenu(true)
	var settings: Control = find_child("SettingsPanel", true, false) as Control
	var settings_open: bool = settings != null and settings.visible
	for tab: Button in tab_buttons:
		var on: bool = false
		if which == "skirmish":
			on = tab.name == "TabSkirmish"
		elif which == "multi":
			on = tab.name == "TabMultiplayer"
		elif which == "campaign" or which == "main":
			on = tab.name == "TabCampaign" and faction_submenu.visible
		else:
			on = tab.name == "TabFaction"
		if tab.name == "SettingsButton":
			on = settings_open
		_style_button(tab, Color(0.12, 0.13, 0.16), Color(0.32, 0.34, 0.38), on)
	_refresh_playing()
	_sync_art()
	if settings_open:
		_hide_menu_chrome()
	_layout_menu(_view_size())

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
	_preview_faction(id)
	_show_tab("campaign")

func _preview_faction(id: String) -> void:
	if id != "":
		_paint_faction(id)
		return
	_sync_art()

func _paint_faction(id: String) -> void:
	if backdrop == null or not backdrop.has_method("set_faction"):
		return
	backdrop.call("set_screen", "faction")
	backdrop.call("set_faction", id)

func _sync_art() -> void:
	if backdrop == null or not backdrop.has_method("set_faction"):
		return
	var settings: Control = find_child("SettingsPanel", true, false) as Control
	if settings != null and settings.visible:
		backdrop.call("set_screen", "settings")
		backdrop.call("set_faction", "")
		return
	if skirmish_panel.visible or campaign_panel.visible or faction_panel.visible:
		_paint_faction(SMFront.current())
		return
	backdrop.call("set_screen", "main")
	backdrop.call("set_faction", "")

func _mark_factions() -> void:
	for card: Button in faction_cards:
		var on: bool = str(card.get_meta("faction")) == SMFront.current()
		var fill: Color = Color(0.18, 0.16, 0.12) if on else Color(0.1, 0.11, 0.14)
		var edge: Color = Color(0.86, 0.7, 0.32) if on else Color(0.3, 0.32, 0.36)
		_style_button(card, fill, edge, on)

func _difficulty_row(parent: Control, prefix: String, at: Vector2) -> void:
	var label: Label = Label.new()
	label.name = prefix + "DiffLabel"
	label.text = "Difficulty"
	label.position = at
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	parent.add_child(label)
	var names: PackedStringArray = PackedStringArray(["Easy", "Normal", "Hard"])
	for i: int in names.size():
		var b: Button = Plate.new() as Button
		b.name = prefix + "Diff" + names[i]
		b.text = names[i]
		b.position = at + Vector2(120.0 + float(i) * 112.0, -6.0)
		b.custom_minimum_size = Vector2(104, 40)
		b.add_theme_font_size_override("font_size", 16)
		var id: String = names[i].to_lower()
		b.pressed.connect(_pick_difficulty.bind(id))
		parent.add_child(b)
	mark_difficulty()

func _pick_difficulty(id: String) -> void:
	preload("res://game/match_settings.gd").set_difficulty(id)
	mark_difficulty()

func mark_difficulty() -> void:
	var current: String = str(preload("res://game/match_settings.gd").difficulty)
	var names: PackedStringArray = PackedStringArray(["Easy", "Normal", "Hard"])
	var prefixes: PackedStringArray = PackedStringArray(["Skirmish", "Campaign"])
	for prefix: String in prefixes:
		for caption: String in names:
			var b: Button = find_child(prefix + "Diff" + caption, true, false) as Button
			if b == null:
				continue
			var on: bool = caption.to_lower() == current
			var fill: Color = Color(0.28, 0.2, 0.1) if on else Color(0.12, 0.13, 0.16)
			var edge: Color = Color(0.9, 0.72, 0.28) if on else Color(0.32, 0.34, 0.38)
			_style_button(b, fill, edge, on)

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
	if panel.visible:
		move_child(panel, get_child_count() - 1)
		_hide_menu_chrome()
	else:
		_show_tab(_menu_tab)
	_sync_art()
	_layout_menu(_view_size())

func _show_menu_chrome() -> void:
	var names: PackedStringArray = PackedStringArray([
		"GameTitle", "TitleRule", "VersionMark", "NowPlaying", "ControlBar", "QuitButton",
	])
	for node_name: String in names:
		var node: CanvasItem = find_child(node_name, true, false) as CanvasItem
		if node != null:
			node.visible = true
	for tab: Button in tab_buttons:
		tab.visible = true

func _hide_menu_chrome() -> void:
	var names: PackedStringArray = _chrome_names()
	for node_name: String in names:
		var node: CanvasItem = find_child(node_name, true, false) as CanvasItem
		if node != null:
			node.visible = false
	for tab: Button in tab_buttons:
		tab.visible = false

func _chrome_names() -> PackedStringArray:
	return PackedStringArray([
		"GameTitle", "TitleRule", "VersionMark", "NowPlaying", "ControlBar",
		"MultiplayerNote", "FactionSubmenu", "LanPanel", "PanelSkirmish",
		"PanelCampaign", "PanelFaction", "QuitButton",
	])

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
	var loading: Control = find_child("LoadingPlate", true, false) as Control
	if loading != null:
		loading.visible = true
		move_child(loading, get_child_count() - 1)
		var art: Node = loading.get_child(0)
		if art != null and art.has_method("set_faction"):
			art.call("set_screen", "faction")
			art.call("set_faction", SMFront.current())
		var title: Label = loading.find_child("LoadingTitle", true, false) as Label
		if title != null:
			title.text = _mission_title(path)
		var progress: Label = loading.find_child("LoadingProgress", true, false) as Label
		if progress != null:
			progress.text = "0%"
	await get_tree().process_frame
	var err: Error = ResourceLoader.load_threaded_request(path)
	if err != OK:
		get_tree().change_scene_to_file(path)
		return
	while is_inside_tree():
		var progress_out: Array = []
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(path, progress_out)
		var digits: Label = find_child("LoadingProgress", true, false) as Label
		if digits != null and not progress_out.is_empty():
			digits.text = "%d%%" % int(round(float(progress_out[0]) * 100.0))
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var packed: PackedScene = ResourceLoader.load_threaded_get(path) as PackedScene
			if packed != null:
				get_tree().change_scene_to_packed(packed)
			else:
				get_tree().change_scene_to_file(path)
			return
		if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			get_tree().change_scene_to_file(path)
			return
		await get_tree().process_frame

func _mission_title(path: String) -> String:
	var file: String = path.get_file()
	if file == "mission_kokang.tscn":
		return SMCampaign.title_of("kokang")
	if file == "campaign_mission.tscn":
		return SMCampaign.title_of(SMCampaign.selected)
	if file == "phillips_channel.tscn":
		return "Phillips Channel"
	if file == "sop_ruak.tscn":
		return "Sop Ruak"
	if file == "burma_road.tscn":
		return "Burma Road"
	if file == "ten_degree_atolls.tscn":
		return "Ten Degree Atolls"
	if file == "mekong_delta.tscn":
		return "Mekong Delta"
	if file == "chiang_rai.tscn":
		return "Siege of Chiang Rai"
	if file == "greybox.tscn":
		return "Greybox"
	if file == "nmrf_yard.tscn":
		return "NMRF yard"
	if file == "mvd_yard.tscn":
		return "MVD yard"
	return "Loading"

func _loading_plate() -> void:
	var plate: Control = Control.new()
	plate.name = "LoadingPlate"
	plate.visible = false
	plate.mouse_filter = Control.MOUSE_FILTER_STOP
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	plate.z_index = 40
	var art: Control = Backdrop.new() as Control
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(art)
	var label: Label = Label.new()
	label.name = "LoadingTitle"
	label.text = "LOADING"
	label.theme_type_variation = "Header"
	label.position = Vector2(64, 56)
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	plate.add_child(label)
	var progress: Label = Label.new()
	progress.name = "LoadingProgress"
	progress.text = ""
	progress.position = Vector2(64, 128)
	progress.add_theme_font_size_override("font_size", 28)
	progress.add_theme_color_override("font_color", Color(1, 1, 1))
	plate.add_child(progress)
	add_child(plate)

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
	if b.get_script() == Plate:
		b.set_meta("lit", strong)
		b.queue_redraw()
		return
	var width: int = 2 if strong else 1
	b.add_theme_stylebox_override("normal", _box(fill, edge, width))
	b.add_theme_stylebox_override("hover", _box(fill.lightened(0.08), edge.lightened(0.1), width))
	b.add_theme_stylebox_override("pressed", _box(fill.darkened(0.06), edge, width))
	b.add_theme_stylebox_override("disabled", _box(Color(0.1, 0.1, 0.11), Color(0.22, 0.22, 0.24), 1))
	b.add_theme_color_override("font_color", Color(1, 1, 1))
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.28))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))

func layout_for(size: Vector2) -> void:
	_layout_menu(size)

func _view_size() -> Vector2:
	var view: Vector2 = get_viewport_rect().size
	if view.x < 32.0 or view.y < 32.0:
		return Vector2(1280, 720)
	return view

func _layout_menu(size: Vector2) -> void:
	if size.x < 32.0 or size.y < 32.0:
		size = Vector2(1280, 720)
	var narrow: bool = size.x < 900.0 or size.y > size.x + 4.0
	if faction_submenu != null:
		faction_submenu.position = Vector2.ZERO
		faction_submenu.size = size
	var left: float = 20.0 if narrow else 72.0
	var title_px: int = 34 if narrow else 64
	var title: Control = find_child("GameTitle", true, false) as Control
	if title != null:
		title.position = Vector2(left, 28.0 if narrow else 48.0)
		title.add_theme_font_size_override("font_size", title_px)
	var title_w: float = float(title_px) * 6.4
	var rule: Control = find_child("TitleRule", true, false) as Control
	if rule != null:
		rule.position = Vector2(left + title_w + 14.0, (36.0 if narrow else 58.0))
		rule.size = Vector2(2.0, float(title_px) - 8.0)
	var version: Control = find_child("VersionMark", true, false) as Control
	if version != null:
		version.position = Vector2(left + title_w + 26.0, (40.0 if narrow else 78.0))
	var now: Control = find_child("NowPlaying", true, false) as Control
	if now != null:
		now.position = Vector2(left, size.y - 52.0)
		now.size = Vector2(minf(480.0, size.x - left - 16.0), 20)
	var plate_w: float = size.x - left * 2.0 if narrow else 340.0
	var y: float = (108.0 if narrow else 168.0)
	var row_h: float = 48.0 if narrow else 44.0
	y = _seat(find_child("TabCampaign", true, false) as Control, left, y, plate_w, row_h)
	if faction_submenu != null and faction_submenu.visible:
		y = _seat_factions(left + 16.0, y, plate_w - 16.0, narrow)
	y = _seat(find_child("TabSkirmish", true, false) as Control, left, y, plate_w, row_h)
	y = _seat(find_child("TabMultiplayer", true, false) as Control, left, y, plate_w, row_h)
	y = _seat(find_child("SettingsButton", true, false) as Control, left, y, plate_w, row_h)
	y = _seat(find_child("QuitButton", true, false) as Control, left, y, plate_w, row_h)
	var side: Control = find_child("TabFaction", true, false) as Control
	if side != null:
		side.position = Vector2(-400, -400)
	if multi_note != null:
		multi_note.position = Vector2(left + 8.0 if narrow else 460.0, y if narrow else 180.0)
		multi_note.size = Vector2(plate_w if narrow else 420.0, 72)
	if lan_panel != null:
		lan_panel.position = multi_note.position + Vector2(0.0, 80.0)
		lan_panel.size = Vector2(plate_w if narrow else 440.0, 530.0)
	var content_y: float = y + 8.0 if narrow else 168.0
	var content_x: float = 8.0 if narrow else 460.0
	var content_w: float = size.x - 16.0 if narrow else size.x - content_x - 24.0
	var content_h: float = maxf(160.0, size.y - content_y - 64.0)
	for panel_name: String in ["PanelSkirmish", "PanelCampaign", "PanelFaction"]:
		var panel: Control = find_child(panel_name, true, false) as Control
		if panel == null:
			continue
		panel.position = Vector2(content_x, content_y)
		panel.size = Vector2(content_w, content_h)
	var bar: Control = find_child("ControlBar", true, false) as Control
	if bar != null:
		bar.position = Vector2(12, size.y - 36.0)
		bar.size = Vector2(size.x - 24.0, 28)
		bar.clip_text = true
	_place_skirmish(content_w, content_h)
	_place_campaign(content_w, content_h)
	_place_factions(content_w)

func _seat_factions(x: float, y: float, width: float, narrow: bool) -> float:
	if faction_cards.is_empty():
		return y
	if narrow:
		var cursor: float = y
		for card: Button in faction_cards:
			cursor = _seat(card, x, cursor, width, 48.0)
		return cursor
	var gap: float = 18.0
	var slot: float = maxf(72.0, (width - gap * float(faction_cards.size() - 1)) / float(faction_cards.size()))
	for i: int in faction_cards.size():
		var card: Button = faction_cards[i]
		card.position = Vector2(x + float(i) * (slot + gap), y)
		card.size = Vector2(slot, 40.0)
		card.custom_minimum_size = Vector2(slot, 40.0)
	return y + 48.0

func _quit() -> void:
	get_tree().quit()

func _focusables() -> Array[Button]:
	var rows: Array[Button] = []
	for node_name: String in ["TabCampaign", "TabSkirmish", "TabMultiplayer", "SettingsButton", "QuitButton"]:
		var button: Button = find_child(node_name, true, false) as Button
		if button != null:
			rows.append(button)
	return rows

func _unhandled_input(event: InputEvent) -> void:
	var settings: Control = find_child("SettingsPanel", true, false) as Control
	if settings != null and settings.visible:
		return
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo:
		if key.keycode == KEY_DOWN or key.keycode == KEY_S:
			_move_focus(1)
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_UP or key.keycode == KEY_W:
			_move_focus(-1)
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_LEFT or key.keycode == KEY_A:
			_move_faction(-1)
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_RIGHT or key.keycode == KEY_D:
			_move_faction(1)
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_SPACE:
			_activate_focus()
			get_viewport().set_input_as_handled()
		return
	var joy: InputEventJoypadButton = event as InputEventJoypadButton
	if joy != null and joy.pressed:
		if joy.button_index == JOY_BUTTON_DPAD_DOWN:
			_move_focus(1)
		elif joy.button_index == JOY_BUTTON_DPAD_UP:
			_move_focus(-1)
		elif joy.button_index == JOY_BUTTON_DPAD_LEFT:
			_move_faction(-1)
		elif joy.button_index == JOY_BUTTON_DPAD_RIGHT:
			_move_faction(1)
		elif joy.button_index == JOY_BUTTON_A:
			_activate_focus()
		else:
			return
		get_viewport().set_input_as_handled()

func _move_focus(step: int) -> void:
	var rows: Array[Button] = _focusables()
	if rows.is_empty():
		return
	var current: int = 0
	var owner: Control = get_viewport().gui_get_focus_owner()
	for i: int in rows.size():
		if rows[i] == owner:
			current = i
	var nxt: int = posmod(current + step, rows.size())
	rows[nxt].grab_focus()

func _move_faction(step: int) -> void:
	if faction_submenu == null or not faction_submenu.visible or faction_cards.is_empty():
		return
	_faction_i = posmod(_faction_i + step, faction_cards.size())
	var card: Button = faction_cards[_faction_i]
	card.grab_focus()
	_preview_faction(str(card.get_meta("faction", "")))

func _activate_focus() -> void:
	var owner: Button = get_viewport().gui_get_focus_owner() as Button
	if owner != null and owner.is_visible_in_tree() and not owner.disabled:
		owner.pressed.emit()

func _seat(node: Control, x: float, y: float, w: float, h: float) -> float:
	if node == null:
		return y
	node.position = Vector2(x, y)
	node.size = Vector2(w, h)
	node.custom_minimum_size = Vector2(w, h)
	return y + h + 8.0

func _place_skirmish(panel_w: float, panel_h: float) -> void:
	var names: PackedStringArray = PackedStringArray([
		"CardPhillips", "CardSopRuak", "CardBurma", "CardAtolls", "CardMekong", "CardChiang",
	])
	var gap: float = 8.0
	var columns: int = 2 if panel_w > 560.0 else 1
	var card_w: float = (panel_w - gap * float(columns + 1)) / float(columns)
	var card_h: float = 72.0
	for i: int in names.size():
		var card: Control = find_child(names[i], true, false) as Control
		if card == null:
			continue
		var col: int = i % columns
		var row: int = i / columns
		card.position = Vector2(gap + float(col) * (card_w + gap), gap + float(row) * (card_h + gap))
		card.size = Vector2(card_w, card_h)
		card.custom_minimum_size = Vector2(card_w, card_h)
	var rows: int = int(ceil(float(names.size()) / float(columns)))
	var stack: float = gap + float(rows) * (card_h + gap)
	var playing: Control = find_child("PlayingAs", true, false) as Control
	if playing != null:
		playing.position = Vector2(gap, stack)
	var play: Control = find_child("PlayButton", true, false) as Control
	if play != null:
		play.position = Vector2(gap, panel_h - 60.0)
		play.size = Vector2(panel_w - gap * 2.0, 52)
		play.custom_minimum_size = Vector2(maxf(120.0, panel_w - gap * 2.0), 52)
	var grey: Control = find_child("GreyboxButton", true, false) as Control
	if grey != null:
		grey.position = Vector2(gap, panel_h - 112.0)
		grey.size = Vector2(minf(220.0, panel_w - gap * 2.0), 44)
	var diff_names: PackedStringArray = PackedStringArray(["SkirmishDiffEasy", "SkirmishDiffNormal", "SkirmishDiffHard"])
	var bw: float = (panel_w - gap * 4.0) / 3.0
	for slot: int in diff_names.size():
		var choice: Control = find_child(diff_names[slot], true, false) as Control
		if choice == null:
			continue
		choice.position = Vector2(gap + float(slot) * (bw + gap), panel_h - 168.0)
		choice.size = Vector2(bw, 44)
		choice.custom_minimum_size = Vector2(bw, 44)
	var diff_label: Control = find_child("SkirmishDiffLabel", true, false) as Control
	if diff_label != null:
		diff_label.visible = false

func _place_campaign(panel_w: float, panel_h: float) -> void:
	var acts: PackedStringArray = PackedStringArray(["ActI", "ActII", "ActIII"])
	var lists: PackedStringArray = PackedStringArray(["ActIMissions", "ActIIMissions", "ActIIIMissions"])
	var gap: float = 8.0
	var tab_w: float = (panel_w - gap * 4.0) / 3.0
	for i: int in acts.size():
		var act: Control = find_child(acts[i], true, false) as Control
		if act == null:
			continue
		act.position = Vector2(gap + float(i) * (tab_w + gap), 4.0)
		act.size = Vector2(tab_w, 44)
		act.custom_minimum_size = Vector2(tab_w, 44)
	for list_name: String in lists:
		var scroll: Control = find_child(list_name, true, false) as Control
		if scroll == null:
			continue
		scroll.position = Vector2(gap, 56.0)
		scroll.size = Vector2(panel_w - gap * 2.0, maxf(80.0, panel_h - 128.0))
		if scroll.get_child_count() > 0:
			var inner: Control = scroll.get_child(0) as Control
			if inner != null:
				inner.custom_minimum_size = Vector2(maxf(80.0, panel_w - 32.0), 0)
	for mission_id: String in SMCampaign.ids():
		var row: Control = find_child("Mission_%s" % mission_id, true, false) as Control
		if row == null:
			continue
		row.custom_minimum_size = Vector2(maxf(80.0, panel_w - 32.0), 44)
	var camp_names: PackedStringArray = PackedStringArray(["CampaignDiffEasy", "CampaignDiffNormal", "CampaignDiffHard"])
	var camp_w: float = (panel_w - gap * 4.0) / 3.0
	for slot: int in camp_names.size():
		var choice: Control = find_child(camp_names[slot], true, false) as Control
		if choice == null:
			continue
		choice.position = Vector2(gap + float(slot) * (camp_w + gap), panel_h - 56.0)
		choice.size = Vector2(camp_w, 44)
		choice.custom_minimum_size = Vector2(camp_w, 44)
	var camp_label: Control = find_child("CampaignDiffLabel", true, false) as Control
	if camp_label != null:
		camp_label.visible = false

func _place_factions(panel_w: float) -> void:
	var yard_nmrf: Control = find_child("NmrfYardButton", true, false) as Control
	var yard_mvd: Control = find_child("MvdYardButton", true, false) as Control
	if yard_nmrf != null:
		yard_nmrf.position = Vector2(16, 16)
		yard_nmrf.custom_minimum_size = Vector2(minf(220.0, panel_w - 32.0), 48)
	if yard_mvd != null:
		yard_mvd.position = Vector2(16, 76)
		yard_mvd.custom_minimum_size = Vector2(minf(220.0, panel_w - 32.0), 48)

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
