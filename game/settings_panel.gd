extends Control
## Menu and in-match settings. Esc toggles the panel.

const Settings = preload("res://game/match_settings.gd")
const Ground = preload("res://game/ground_view.gd")

var low_button: Button
var high_button: Button
var master_slider: HSlider
var sfx_slider: HSlider
var pan_slider: HSlider
var edge_box: CheckButton
var master_readout: Label
var sfx_readout: Label
var pan_readout: Label
var _syncing: bool = false

static func attach(parent: Node) -> Control:
	var script: GDScript = load("res://game/settings_panel.gd") as GDScript
	var panel: Control = script.new() as Control
	parent.add_child(panel)
	return panel

func _ready() -> void:
	name = "SettingsPanel"
	visible = false
	set_process_unhandled_input(true)
	mouse_filter = Control.MOUSE_FILTER_STOP
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -270.0
	offset_top = -250.0
	offset_right = 270.0
	offset_bottom = 270.0
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.06, 0.07, 0.09, 0.96)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var title: Label = Label.new()
	title.name = "SettingsTitle"
	title.text = "Settings"
	title.theme_type_variation = "Header"
	title.position = Vector2(28, 18)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.95, 0.86, 0.55))
	add_child(title)
	var graphics: Label = _caption("Graphics", Vector2(28, 72))
	add_child(graphics)
	low_button = _choice("GraphicsLow", "Low", Vector2(180, 64))
	high_button = _choice("GraphicsHigh", "High", Vector2(330, 64))
	low_button.pressed.connect(_pick_graphics.bind("low"))
	high_button.pressed.connect(_pick_graphics.bind("high"))
	add_child(low_button)
	add_child(high_button)
	master_readout = _caption("Master", Vector2(28, 124))
	sfx_readout = _caption("SFX", Vector2(28, 176))
	pan_readout = _caption("Pan speed", Vector2(28, 228))
	add_child(master_readout)
	add_child(sfx_readout)
	add_child(pan_readout)
	master_slider = _slider("MasterVolume", 0.0, 1.0, 0.05, Vector2(180, 124))
	sfx_slider = _slider("SfxVolume", 0.0, 1.0, 0.05, Vector2(180, 176))
	pan_slider = _slider("PanSpeed", 0.4, 2.2, 0.1, Vector2(180, 228))
	master_slider.value_changed.connect(_on_master)
	sfx_slider.value_changed.connect(_on_sfx)
	pan_slider.value_changed.connect(_on_pan)
	add_child(master_slider)
	add_child(sfx_slider)
	add_child(pan_slider)
	edge_box = CheckButton.new()
	edge_box.name = "EdgePan"
	edge_box.text = "Edge pan"
	edge_box.position = Vector2(28, 284)
	edge_box.add_theme_font_size_override("font_size", 16)
	edge_box.toggled.connect(_on_edge)
	add_child(edge_box)
	var diff_label: Label = _caption("Difficulty", Vector2(28, 336))
	add_child(diff_label)
	var easy: Button = _choice("SettingsDiffEasy", "Easy", Vector2(28, 368))
	var normal: Button = _choice("SettingsDiffNormal", "Normal", Vector2(168, 368))
	var hard: Button = _choice("SettingsDiffHard", "Hard", Vector2(308, 368))
	easy.pressed.connect(_pick_difficulty.bind("easy"))
	normal.pressed.connect(_pick_difficulty.bind("normal"))
	hard.pressed.connect(_pick_difficulty.bind("hard"))
	add_child(easy)
	add_child(normal)
	add_child(hard)
	var close: Button = Button.new()
	close.name = "SettingsClose"
	close.text = "Close"
	close.position = Vector2(360, 428)
	close.custom_minimum_size = Vector2(140, 44)
	close.add_theme_font_size_override("font_size", 18)
	close.pressed.connect(_close)
	add_child(close)
	var note: Label = Label.new()
	note.text = "Low drops trees, rain, fog, and shadows."
	note.position = Vector2(28, 484)
	note.add_theme_font_size_override("font_size", 14)
	note.add_theme_color_override("font_color", Color(0.7, 0.74, 0.78))
	add_child(note)

func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_ESCAPE:
		return
	visible = not visible
	if visible:
		pull()
	var vp: Viewport = get_viewport()
	if vp != null:
		vp.set_input_as_handled()

func pull() -> void:
	_syncing = true
	Settings.ensure()
	low_button.disabled = Settings.graphics == "low"
	high_button.disabled = Settings.graphics == "high"
	master_slider.value = Settings.master
	sfx_slider.value = Settings.sfx
	pan_slider.value = Settings.pan
	edge_box.button_pressed = Settings.edge
	_mark_difficulty()
	_paint_readouts()
	_syncing = false

func _pick_graphics(q: String) -> void:
	if _syncing:
		return
	Settings.set_graphics(q)
	pull()
	_apply()

func _on_master(v: float) -> void:
	if _syncing:
		return
	Settings.set_master(v)
	_paint_readouts()
	_apply()

func _on_sfx(v: float) -> void:
	if _syncing:
		return
	Settings.set_sfx(v)
	_paint_readouts()
	_apply()

func _on_pan(v: float) -> void:
	if _syncing:
		return
	Settings.set_pan(v)
	_paint_readouts()
	_apply()

func _pick_difficulty(id: String) -> void:
	if _syncing:
		return
	Settings.set_difficulty(id)
	_mark_difficulty()
	var scene: Node = get_tree().current_scene if get_tree() != null else null
	if scene != null and scene.has_method("mark_difficulty"):
		scene.call("mark_difficulty")

func _mark_difficulty() -> void:
	var easy: Button = get_node_or_null("SettingsDiffEasy") as Button
	var normal: Button = get_node_or_null("SettingsDiffNormal") as Button
	var hard: Button = get_node_or_null("SettingsDiffHard") as Button
	if easy != null:
		easy.disabled = Settings.difficulty == "easy"
	if normal != null:
		normal.disabled = Settings.difficulty == "normal"
	if hard != null:
		hard.disabled = Settings.difficulty == "hard"

func _on_edge(on: bool) -> void:
	if _syncing:
		return
	Settings.set_edge(on)
	_apply()

func _close() -> void:
	visible = false

func _paint_readouts() -> void:
	master_readout.text = "Master  %d%%" % int(round(Settings.master * 100.0))
	sfx_readout.text = "SFX  %d%%" % int(round(Settings.sfx * 100.0))
	pan_readout.text = "Pan speed  %.1f" % Settings.pan

func _apply() -> void:
	var scene: Node = get_tree().current_scene if get_tree() != null else null
	Settings.apply_scene(scene)
	var host: Node3D = scene as Node3D
	if host == null:
		return
	var sight: SMSight = host.get("sight") as SMSight
	if sight == null:
		return
	var cam: RTSCamera = host.get_node_or_null("Camera") as RTSCamera
	Ground.apply_sky(host, sight)
	Ground.cull_props(host, cam)

func _caption(text: String, at: Vector2) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.9, 0.91, 0.93))
	return label

func _choice(node_name: String, text: String, at: Vector2) -> Button:
	var button: Button = Button.new()
	button.name = node_name
	button.text = text
	button.position = at
	button.custom_minimum_size = Vector2(130, 40)
	button.add_theme_font_size_override("font_size", 18)
	return button

func _slider(node_name: String, lo: float, hi: float, step: float, at: Vector2) -> HSlider:
	var slider: HSlider = HSlider.new()
	slider.name = node_name
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.position = at
	slider.custom_minimum_size = Vector2(280, 28)
	return slider
