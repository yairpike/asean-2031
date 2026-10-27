extends Control

func _ready() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box: VBoxContainer = VBoxContainer.new()
	box.position = Vector2(80, 80)
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	var title: Label = Label.new()
	title.text = "Shattered Monsoon"
	title.add_theme_font_size_override("font_size", 32)
	box.add_child(title)
	var sub: Label = Label.new()
	sub.text = "Golden Triangle, the Mekong, and the Strait of Malacca."
	box.add_child(sub)
	_link(box, "Greybox", "res://game/greybox.tscn", "GreyboxButton")
	_link(box, "Phillips Channel", "res://game/phillips_channel.tscn", "PhillipsButton")
	_link(box, "Kokang and Mogok night raid", "res://game/mission_kokang.tscn", "MissionButton")

func _link(box: VBoxContainer, caption: String, path: String, node_name: String) -> void:
	var b: Button = Button.new()
	b.name = node_name
	b.text = caption
	b.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(path)
	)
	box.add_child(b)
