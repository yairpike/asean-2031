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
	_body(box, "You play GTFC (crimson / amber) in Phillips Channel and in the Kokang raid. Greybox is a systems demo and has no player faction.")

	_link(box, "Greybox (systems demo)", "res://game/greybox.tscn", "GreyboxButton")
	_hint(box, "Look at the build styles, commodity nodes, and jammer. Camera only.")
	_link(box, "Phillips Channel (1v1 skirmish)", "res://game/phillips_channel.tscn", "PhillipsButton")
	_hint(box, "GTFC versus a scripted opponent. Use the sidebar, then press F.")
	_link(box, "Kokang raid (mission 1)", "res://game/mission_kokang.tscn", "MissionButton")
	_hint(box, "GTFC night raid. Raise the scaffold, run the ruby night shift, then secure rare earth.")

	_heading(box, "Controls that work", 22)
	_body(box, "Select. Not bound. You cannot click a unit in these modes.")
	_body(box, "Move. Not bound. There is no right-click move order.")
	_body(box, "Attack. Not bound. On Phillips Channel, the Engage button runs the scripted fight.")
	_body(box, "F ability. On Phillips Channel, press F or click Ability (F). That toggles one unit and smart-casts the closest ready unit. Greybox and the Kokang raid ignore F.")
	_body(box, "Camera. Move the pointer to a screen edge to pan. Roll the wheel to zoom toward the cursor. On Greybox and Phillips Channel, drag with the middle mouse button to orbit. The Kokang raid does not orbit.")
	_body(box, "Phillips Channel buttons: Build pipeline, Cross channel, Ability (F), Engage, and one shot each of Logistics, Arsenal, and Oracle. Kokang raid buttons: Raise scaffold, Ruby night shift, Secure rare earth.")

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
