extends Control

func _ready() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 56.0
	scroll.offset_top = 28.0
	scroll.offset_right = -56.0
	scroll.offset_bottom = -24.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)

	_heading(box, "Shattered Monsoon", 32)
	_body(box, "You play GTFC (crimson / amber) on the skirmish maps and the Kokang raid. NMRF is olive / emerald. MVD is charcoal / cyan. Greybox is a systems demo and has no player faction.")

	_link(box, "Greybox (systems demo)", "res://game/greybox.tscn", "GreyboxButton")
	_hint(box, "Look at the build styles, commodity nodes, and jammer. Camera only. No select, move, attack, or F.")
	_link(box, "Phillips Channel (1v1 skirmish)", "res://game/phillips_channel.tscn", "PhillipsButton")
	_hint(box, "GTFC versus enemies on the far shore. Names float on each unit. Select, then right click.")
	_link(box, "Sop Ruak (river skirmish)", "res://game/sop_ruak.tscn", "SopRuakButton")
	_hint(box, "GTFC versus one enemy. Three shores split by a Y-shaped river. Same orders as Phillips Channel.")
	_link(box, "Burma Road (highland cliffs)", "res://game/burma_road.tscn", "BurmaRoadButton")
	_hint(box, "GTFC versus one enemy. Highland cliffs, with a land road through the wall. Same orders as Sop Ruak.")
	_link(box, "Ten Degree Atolls (islands and deep water)", "res://game/ten_degree_atolls.tscn", "AtollsButton")
	_hint(box, "GTFC versus one enemy. Islands in deep water, joined by shoals. Same orders as Sop Ruak.")
	_link(box, "Mekong Delta (canals and bridges)", "res://game/mekong_delta.tscn", "MekongButton")
	_hint(box, "GTFC versus one enemy. Canals cut the paddies. Bridges are the crossings. Same orders as Sop Ruak.")
	_link(box, "Siege of Chiang Rai (larger team map)", "res://game/chiang_rai.tscn", "ChiangRaiButton")
	_hint(box, "GTFC versus one enemy on a larger field. A river, two fords, and a siege wall. Same orders as Sop Ruak.")
	_link(box, "NMRF (mobile core)", "res://game/nmrf_yard.tscn", "NmrfButton")
	_hint(box, "Olive and emerald. Six boats and rifles. Move the packer, unpack the wharf, then upgrade it. Same orders as Sop Ruak.")
	_link(box, "MVD (internal queue)", "res://game/mvd_yard.tscn", "MvdButton")
	_hint(box, "Charcoal and cyan. Six named units. Queue the hub inside the pad, buy clearance, then place it. Same orders as Sop Ruak.")
	_link(box, "Kokang raid (mission 1)", "res://game/mission_kokang.tscn", "MissionButton")
	_hint(box, "GTFC night raid. Names float on the squad. Select, right click, and press F to strike.")

	_heading(box, "Controls that work", 22)
	_body(box, "Select. On every skirmish and the Kokang raid, left click a named GTFC unit. Drag a box around several. Greybox has no units to select.")
	_body(box, "Move. Right click open ground. The selection walks there. Greybox has no move order.")
	_body(box, "Attack. Right click an enemy labeled Enemy. The selection attacks it. On every skirmish the enemy builds a yard, claims a ruby node, and attacks your units. On Phillips Channel, Engage still runs the scripted fight as well.")
	_body(box, "F ability. On every skirmish, including NMRF and MVD, press F or click Ability (F). That toggles one unit and smart-casts the closest ready unit. On the Kokang raid, press F and the squad strikes the nearest enemy. Greybox ignores F.")
	_body(box, "Camera. On every mode, move the pointer to a screen edge to pan, roll the wheel to zoom toward the cursor, and drag with the middle mouse button to orbit.")
	_body(box, "Phillips Channel buttons: Build pipeline, Cross channel, Ability (F), Engage, and one shot each of Logistics, Arsenal, and Oracle. Sop Ruak and the four other GTFC maps have Ability (F). NMRF adds Move packer, Unpack, and Upgrade wharf. MVD adds Queue hub, Buy clearance, and Place hub. Kokang raid buttons: Raise scaffold, Ruby night shift, Secure rare earth.")

func _heading(box: VBoxContainer, text: String, size: int) -> void:
	var title: Label = Label.new()
	title.text = text
	title.add_theme_font_size_override("font_size", size)
	title.add_theme_color_override("font_color", Color(0.93, 0.94, 0.96))
	box.add_child(title)

func _body(box: VBoxContainer, text: String) -> void:
	var line: Label = Label.new()
	line.text = text
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size = Vector2(1080, 0)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_theme_color_override("font_color", Color(0.86, 0.88, 0.9))
	box.add_child(line)

func _hint(box: VBoxContainer, text: String) -> void:
	var line: Label = Label.new()
	line.text = text
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size = Vector2(1080, 0)
	line.add_theme_font_size_override("font_size", 14)
	line.add_theme_color_override("font_color", Color(0.62, 0.66, 0.7))
	box.add_child(line)

func _link(box: VBoxContainer, caption: String, path: String, node_name: String) -> void:
	var b: Button = Button.new()
	b.name = node_name
	b.text = caption
	b.custom_minimum_size = Vector2(420, 36)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(path)
	)
	box.add_child(b)
