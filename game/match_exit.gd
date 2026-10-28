extends Node
## Esc opens the pause menu. Settings still closes on Esc first.
## The how-to closes on Esc while it is open. Quit to menu returns to boot.

func _ready() -> void:
	set_process_unhandled_input(true)
	call_deferred("_arm")

func _arm() -> void:
	var layer: CanvasLayer = _layer()
	if layer == null:
		return
	if layer.find_child("MissionBoot", true, false) == null:
		var back: Button = Button.new()
		back.name = "MissionBoot"
		back.text = "Boot menu"
		back.position = Vector2(568, 40)
		back.custom_minimum_size = Vector2(160, 36)
		back.z_index = 40
		back.pressed.connect(_to_boot)
		layer.add_child(back)
	if layer.find_child("PauseMenu", true, false) == null:
		_build_pause(layer)

func _build_pause(layer: CanvasLayer) -> void:
	var dim: ColorRect = ColorRect.new()
	dim.name = "PauseMenu"
	dim.visible = false
	dim.color = Color(0.02, 0.03, 0.05, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.z_index = 60
	layer.add_child(dim)
	var title: Label = Label.new()
	title.name = "PauseTitle"
	title.text = "PAUSED"
	title.position = Vector2(96, 96)
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.add_child(title)
	_pause_row(dim, "PauseResume", "Resume", 220.0, _resume)
	_pause_row(dim, "PauseSettings", "Settings", 276.0, _open_settings)
	_pause_row(dim, "PauseControls", "Controls", 332.0, _open_controls)
	_pause_row(dim, "PauseRestart", "Restart", 388.0, _restart)
	_pause_row(dim, "PauseQuit", "Quit to menu", 444.0, _to_boot)

func _pause_row(parent: Control, node_name: String, caption: String, y: float, call: Callable) -> void:
	var button: Button = Button.new()
	button.name = node_name
	button.text = caption
	button.position = Vector2(96, y)
	button.custom_minimum_size = Vector2(280, 44)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(call)
	parent.add_child(button)

func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_ESCAPE:
		return
	var host: Node = get_parent()
	if host == null:
		return
	var settings: Control = host.find_child("SettingsPanel", true, false) as Control
	if settings != null and settings.visible:
		return
	var pause: CanvasItem = host.find_child("PauseMenu", true, false) as CanvasItem
	if pause != null and pause.visible:
		pause.visible = false
		_handled()
		return
	var guide: CanvasItem = host.find_child("HowToOverlay", true, false) as CanvasItem
	if guide != null and guide.visible:
		guide.visible = false
		_handled()
		return
	if pause != null:
		pause.visible = true
		_handled()
		return
	var boot: BaseButton = host.find_child("MissionBoot", true, false) as BaseButton
	if boot != null:
		boot.pressed.emit()
	else:
		_to_boot()
	_handled()

func _resume() -> void:
	var pause: CanvasItem = _pause()
	if pause != null:
		pause.visible = false

func _open_settings() -> void:
	_resume()
	var host: Node = get_parent()
	if host == null:
		return
	var settings: Control = host.find_child("SettingsPanel", true, false) as Control
	if settings == null:
		return
	settings.visible = true
	if settings.has_method("pull"):
		settings.call("pull")

func _open_controls() -> void:
	_resume()
	var host: Node = get_parent()
	if host == null:
		return
	var guide: CanvasItem = host.find_child("HowToOverlay", true, false) as CanvasItem
	if guide != null:
		guide.visible = true

func _restart() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	tree.reload_current_scene()

func _to_boot() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	tree.change_scene_to_file("res://game/boot.tscn")

func _pause() -> CanvasItem:
	var host: Node = get_parent()
	if host == null:
		return null
	return host.find_child("PauseMenu", true, false) as CanvasItem

func _layer() -> CanvasLayer:
	var host: Node = get_parent()
	if host == null:
		return null
	var named: CanvasLayer = host.get_node_or_null("UI") as CanvasLayer
	if named != null:
		return named
	var found: Node = host.find_child("Status", true, false)
	if found != null:
		return found.get_parent() as CanvasLayer
	for child: Node in host.get_children():
		var layer: CanvasLayer = child as CanvasLayer
		if layer != null:
			return layer
	return null

func _handled() -> void:
	var tree: SceneTree = get_tree()
	if tree != null and tree.root != null:
		tree.root.set_input_as_handled()
