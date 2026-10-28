extends Control
## Full-screen settings list. Esc, Back, and a gamepad B close it.

const Settings = preload("res://game/match_settings.gd")
const Ground = preload("res://game/ground_view.gd")
const Backdrop = preload("res://game/menu_backdrop.gd")

var low_button: Button
var high_button: Button
var master_slider: HSlider
var sfx_slider: HSlider
var pan_slider: HSlider
var edge_box: CheckButton
var voice_value: Button
var master_readout: Label
var sfx_readout: Label
var pan_readout: Label
var master_value: Label
var sfx_value: Label
var pan_value: Label
var blurb: Label
var highlight: ColorRect
var _syncing: bool = false
var _rows: Array[Control] = []

static func attach(parent: Node) -> Control:
	var script: GDScript = load("res://game/settings_panel.gd") as GDScript
	var panel: Control = script.new() as Control
	parent.add_child(panel)
	return panel

func _ready() -> void:
	name = "SettingsPanel"
	visible = false
	z_index = 30
	set_process_unhandled_input(true)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var art: Control = Backdrop.new() as Control
	art.name = "SettingsBackdrop"
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.call("set_screen", "settings")
	art.call("set_faction", "")
	add_child(art)
	highlight = ColorRect.new()
	highlight.name = "SettingsHighlight"
	highlight.color = Color(1, 1, 1, 0.12)
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	highlight.visible = false
	add_child(highlight)
	var title: Label = Label.new()
	title.name = "SettingsTitle"
	title.text = "SETTINGS"
	title.theme_type_variation = "Header"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	add_child(title)
	_section("SectionGraphics", "GRAPHICS")
	_section("SectionAudio", "AUDIO")
	_section("SectionControls", "CONTROLS")
	_section("SectionGameplay", "GAMEPLAY")
	_section("SectionHud", "HUD")
	var quality: Label = _caption("QualityLabel", "Quality")
	add_child(quality)
	low_button = _choice("GraphicsLow", "Low")
	high_button = _choice("GraphicsHigh", "High")
	low_button.pressed.connect(_pick_graphics.bind("low"))
	high_button.pressed.connect(_pick_graphics.bind("high"))
	low_button.set_meta("blurb", "Low drops trees, rain, fog, and shadows.")
	high_button.set_meta("blurb", "High keeps trees, rain, fog, and shadows.")
	add_child(low_button)
	add_child(high_button)
	master_readout = _caption("MasterLabel", "Master")
	sfx_readout = _caption("SfxLabel", "SFX")
	pan_readout = _caption("PanLabel", "Pan speed")
	add_child(master_readout)
	add_child(sfx_readout)
	add_child(pan_readout)
	master_value = _caption("MasterValue", "100")
	sfx_value = _caption("SfxValue", "100")
	pan_value = _caption("PanValue", "1.0")
	add_child(master_value)
	add_child(sfx_value)
	add_child(pan_value)
	master_slider = _slider("MasterVolume", 0.0, 1.0, 0.05)
	sfx_slider = _slider("SfxVolume", 0.0, 1.0, 0.05)
	pan_slider = _slider("PanSpeed", 0.4, 2.2, 0.1)
	master_slider.set_meta("blurb", "Overall loudness, including music.")
	sfx_slider.set_meta("blurb", "Menu ticks, weapons, and the radio.")
	pan_slider.set_meta("blurb", "How fast the camera slides.")
	master_slider.value_changed.connect(_on_master)
	sfx_slider.value_changed.connect(_on_sfx)
	pan_slider.value_changed.connect(_on_pan)
	add_child(master_slider)
	add_child(sfx_slider)
	add_child(pan_slider)
	var voice_label: Label = _caption("VoiceLabel", "Voice language")
	add_child(voice_label)
	voice_value = _choice("VoiceValue", "English")
	voice_value.set_meta("blurb", "English, Burmese, Mandarin, Thai, or Malay. A missing line plays the English take.")
	voice_value.pressed.connect(_cycle_voice.bind(1))
	add_child(voice_value)
	edge_box = CheckButton.new()
	edge_box.name = "EdgePan"
	edge_box.text = "Edge pan"
	edge_box.add_theme_font_size_override("font_size", 16)
	edge_box.add_theme_color_override("font_color", Color(1, 1, 1))
	edge_box.set_meta("blurb", "The camera slides when the pointer nears the screen edge.")
	edge_box.toggled.connect(_on_edge)
	add_child(edge_box)
	var diff_label: Label = _caption("DifficultyLabel", "Difficulty")
	add_child(diff_label)
	var easy: Button = _choice("SettingsDiffEasy", "Easy")
	var normal: Button = _choice("SettingsDiffNormal", "Normal")
	var hard: Button = _choice("SettingsDiffHard", "Hard")
	easy.set_meta("blurb", "A slower enemy, for learning the company.")
	normal.set_meta("blurb", "The intended skirmish and campaign pace.")
	hard.set_meta("blurb", "A faster, tougher enemy.")
	easy.pressed.connect(_pick_difficulty.bind("easy"))
	normal.pressed.connect(_pick_difficulty.bind("normal"))
	hard.pressed.connect(_pick_difficulty.bind("hard"))
	add_child(easy)
	add_child(normal)
	add_child(hard)
	var hud_note: Label = _caption("HudNote", "Command deck")
	hud_note.set_meta("blurb", "The match keeps the command deck, minimap, and unit card.")
	add_child(hud_note)
	var hud_value: Label = _caption("HudValue", "On")
	add_child(hud_value)
	var close: Button = _choice("SettingsClose", "Back")
	close.set_meta("blurb", "Return to the previous screen.")
	close.pressed.connect(_close)
	add_child(close)
	var restore: Button = _choice("SettingsRestore", "Restore Defaults")
	restore.set_meta("blurb", "High graphics, full volume, English voices, normal difficulty, edge pan on.")
	restore.pressed.connect(_restore)
	add_child(restore)
	blurb = Label.new()
	blurb.name = "SettingsBlurb"
	blurb.text = "Highlight a row to read what it changes."
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.add_theme_font_size_override("font_size", 16)
	blurb.add_theme_color_override("font_color", Color(1, 1, 1))
	add_child(blurb)
	_watch(low_button)
	_watch(high_button)
	_watch(master_slider)
	_watch(sfx_slider)
	_watch(voice_value)
	_watch(pan_slider)
	_watch(edge_box)
	_watch(easy)
	_watch(normal)
	_watch(hard)
	_watch(close)
	_watch(restore)
	_layout(Vector2(1280, 720))
	resized.connect(_on_resized)

func _on_resized() -> void:
	_layout(size)

func _layout(view: Vector2) -> void:
	var narrow: bool = view.x < 900.0 or view.y > view.x + 4.0
	var left: float = 20.0 if narrow else 64.0
	var list_w: float = view.x - 36.0 if narrow else minf(640.0, view.x * 0.52)
	var y: float = 28.0
	var title: Control = get_node_or_null("SettingsTitle")
	if title != null:
		title.position = Vector2(left, y)
	y = 88.0
	y = _place_section("SectionGraphics", left, y, list_w)
	y = _place_row(get_node_or_null("QualityLabel"), left, y, list_w)
	_place_value(low_button, left + list_w - 168.0, y - 44.0, 76.0)
	_place_value(high_button, left + list_w - 84.0, y - 44.0, 76.0)
	y = _place_section("SectionAudio", left, y, list_w)
	y = _place_slider(master_readout, master_slider, master_value, left, y, list_w)
	y = _place_slider(sfx_readout, sfx_slider, sfx_value, left, y, list_w)
	y = _place_row(get_node_or_null("VoiceLabel"), left, y, list_w)
	_place_value(voice_value, left + list_w - 168.0, y - 44.0, 160.0)
	y = _place_section("SectionControls", left, y, list_w)
	y = _place_row(edge_box, left, y, list_w)
	y = _place_slider(pan_readout, pan_slider, pan_value, left, y, list_w)
	y = _place_section("SectionGameplay", left, y, list_w)
	y = _place_row(get_node_or_null("DifficultyLabel"), left, y, list_w)
	_place_value(get_node_or_null("SettingsDiffEasy"), left + list_w - 252.0, y - 44.0, 76.0)
	_place_value(get_node_or_null("SettingsDiffNormal"), left + list_w - 168.0, y - 44.0, 76.0)
	_place_value(get_node_or_null("SettingsDiffHard"), left + list_w - 84.0, y - 44.0, 76.0)
	y = _place_section("SectionHud", left, y, list_w)
	y = _place_row(get_node_or_null("HudNote"), left, y, list_w)
	_place_value(get_node_or_null("HudValue"), left + list_w - 48.0, y - 40.0, 40.0)
	var back: Control = get_node_or_null("SettingsClose")
	var restore: Control = get_node_or_null("SettingsRestore")
	var foot: float = view.y - 56.0
	if back != null:
		back.position = Vector2(left, foot)
		back.size = Vector2(88, 44)
		back.custom_minimum_size = Vector2(88, 44)
	if restore != null:
		restore.position = Vector2(left + 108.0, foot)
		restore.size = Vector2(200, 44)
		restore.custom_minimum_size = Vector2(200, 44)
	if blurb != null:
		if narrow:
			blurb.position = Vector2(left, minf(y + 8.0, foot - 72.0))
			blurb.size = Vector2(list_w, 64)
		else:
			blurb.position = Vector2(left + list_w + 36.0, 120.0)
			blurb.size = Vector2(maxf(160.0, view.x - blurb.position.x - 28.0), 220)

func _place_section(node_name: String, x: float, y: float, width: float) -> float:
	var label: Control = get_node_or_null(node_name)
	if label == null:
		return y
	label.position = Vector2(x, y)
	label.size = Vector2(width, 22)
	return y + 28.0

func _place_row(node: Control, x: float, y: float, width: float) -> float:
	if node == null:
		return y
	node.position = Vector2(x, y)
	node.size = Vector2(width, 40)
	if node.custom_minimum_size.y < 40.0:
		node.custom_minimum_size = Vector2(node.custom_minimum_size.x, 40)
	return y + 44.0

func _place_value(node: Control, x: float, y: float, width: float) -> void:
	if node == null:
		return
	node.position = Vector2(x, y)
	node.size = Vector2(width, 36)
	node.custom_minimum_size = Vector2(width, 36)

func _place_slider(label: Control, slider: Control, value: Control, x: float, y: float, width: float) -> float:
	y = _place_row(label, x, y, width * 0.4)
	if slider != null:
		slider.position = Vector2(x + width * 0.42, y - 40.0)
		slider.size = Vector2(width * 0.4, 36)
		slider.custom_minimum_size = Vector2(width * 0.4, 36)
	if value != null:
		value.position = Vector2(x + width - 52.0, y - 40.0)
		value.size = Vector2(48, 28)
	return y

func _section(node_name: String, text: String) -> void:
	var label: Label = Label.new()
	label.name = node_name
	label.text = text
	label.theme_type_variation = "Header"
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	add_child(label)
	var rule: ColorRect = ColorRect.new()
	rule.color = Color(1, 1, 1, 0.35)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.size = Vector2(220, 1)
	rule.position = Vector2(0, 20)
	label.add_child(rule)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo:
		if key.keycode == KEY_ESCAPE or key.keycode == KEY_B:
			_close()
			_handled()
		elif key.keycode == KEY_UP:
			_move_row(-1)
			_handled()
		elif key.keycode == KEY_DOWN:
			_move_row(1)
			_handled()
		elif key.keycode == KEY_LEFT:
			_nudge(-1)
			_handled()
		elif key.keycode == KEY_RIGHT:
			_nudge(1)
			_handled()
		return
	var joy: InputEventJoypadButton = event as InputEventJoypadButton
	if joy != null and joy.pressed:
		if joy.button_index == JOY_BUTTON_B or joy.button_index == JOY_BUTTON_DPAD_DOWN or joy.button_index == JOY_BUTTON_DPAD_UP:
			if joy.button_index == JOY_BUTTON_B:
				_close()
			elif joy.button_index == JOY_BUTTON_DPAD_DOWN:
				_move_row(1)
			else:
				_move_row(-1)
			_handled()
		elif joy.button_index == JOY_BUTTON_DPAD_LEFT:
			_nudge(-1)
			_handled()
		elif joy.button_index == JOY_BUTTON_DPAD_RIGHT:
			_nudge(1)
			_handled()

func _handled() -> void:
	var vp: Viewport = get_viewport()
	if vp != null:
		vp.set_input_as_handled()

func _move_row(step: int) -> void:
	if _rows.is_empty():
		return
	var owner: Control = get_viewport().gui_get_focus_owner()
	var current: int = 0
	for i: int in _rows.size():
		if _rows[i] == owner:
			current = i
	_rows[posmod(current + step, _rows.size())].grab_focus()

func _nudge(step: int) -> void:
	var owner: Control = get_viewport().gui_get_focus_owner()
	var slider: HSlider = owner as HSlider
	if slider != null:
		slider.value = clampf(slider.value + slider.step * float(step), slider.min_value, slider.max_value)
		return
	if owner == low_button or owner == high_button:
		_pick_graphics("high" if step > 0 else "low")
		return
	if owner != null and str(owner.name).begins_with("SettingsDiff"):
		var order: PackedStringArray = PackedStringArray(["easy", "normal", "hard"])
		var at: int = order.find(Settings.difficulty)
		_pick_difficulty(order[posmod(at + step, order.size())])
		return
	if owner == voice_value:
		_cycle_voice(step)

func pull() -> void:
	_syncing = true
	Settings.ensure()
	low_button.disabled = Settings.graphics == "low"
	high_button.disabled = Settings.graphics == "high"
	low_button.add_theme_color_override("font_color", Color(1, 1, 1, 1 if Settings.graphics == "low" else 0.45))
	high_button.add_theme_color_override("font_color", Color(1, 1, 1, 1 if Settings.graphics == "high" else 0.45))
	master_slider.value = Settings.master
	sfx_slider.value = Settings.sfx
	pan_slider.value = Settings.pan
	edge_box.button_pressed = Settings.edge
	_mark_difficulty()
	_paint_voice()
	_paint_readouts()
	_syncing = false
	_layout(size if size.x > 32.0 else Vector2(1280, 720))

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

func _cycle_voice(step: int) -> void:
	if _syncing:
		return
	var order: PackedStringArray = Settings.voice_ids()
	var at: int = order.find(Settings.voice)
	if at < 0:
		at = 0
	Settings.set_voice(order[posmod(at + step, order.size())])
	_paint_voice()
	var clips: GDScript = load("res://game/match_audio.gd") as GDScript
	clips.call("note_voice", self)

func _paint_voice() -> void:
	if voice_value == null:
		return
	voice_value.text = Settings.voice_name(Settings.voice)

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
		easy.add_theme_color_override("font_color", Color(1, 1, 1, 1 if Settings.difficulty == "easy" else 0.45))
	if normal != null:
		normal.disabled = Settings.difficulty == "normal"
		normal.add_theme_color_override("font_color", Color(1, 1, 1, 1 if Settings.difficulty == "normal" else 0.45))
	if hard != null:
		hard.disabled = Settings.difficulty == "hard"
		hard.add_theme_color_override("font_color", Color(1, 1, 1, 1 if Settings.difficulty == "hard" else 0.45))

func _on_edge(on: bool) -> void:
	if _syncing:
		return
	Settings.set_edge(on)
	_apply()

func _close() -> void:
	visible = false
	var host: Node = get_parent()
	if host != null and host.has_method("_sync_art"):
		host.call("_sync_art")

func _restore() -> void:
	Settings.restore()
	pull()
	_apply()
	var host: Node = get_parent()
	if host != null and host.has_method("mark_difficulty"):
		host.call("mark_difficulty")

func _paint_readouts() -> void:
	master_readout.text = "Master"
	sfx_readout.text = "SFX"
	pan_readout.text = "Pan speed"
	master_value.text = "%d" % int(round(Settings.master * 100.0))
	sfx_value.text = "%d" % int(round(Settings.sfx * 100.0))
	pan_value.text = "%.1f" % Settings.pan

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

func _caption(node_name: String, text: String) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	return label

func _choice(node_name: String, text: String) -> Button:
	var button: Button = Button.new()
	button.name = node_name
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color(1, 1, 1))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1))
	var empty := StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, empty)
	return button

func _slider(node_name: String, lo: float, hi: float, step: float) -> HSlider:
	var slider: HSlider = HSlider.new()
	slider.name = node_name
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.custom_minimum_size = Vector2(120, 36)
	return slider

func _watch(node: Control) -> void:
	if node == null:
		return
	_rows.append(node)
	node.mouse_entered.connect(_show_blurb.bind(node))
	node.focus_entered.connect(_show_blurb.bind(node))

func _show_blurb(node: Control) -> void:
	if blurb == null or node == null:
		return
	var text: String = str(node.get_meta("blurb", ""))
	if text != "":
		blurb.text = text
	if highlight == null:
		return
	highlight.visible = true
	highlight.position = node.position + Vector2(-8, -2)
	highlight.size = Vector2(maxf(node.size.x, 160.0) + 16.0, maxf(node.size.y, 32.0) + 4.0)
