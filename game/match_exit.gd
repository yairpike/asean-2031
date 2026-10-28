extends Node
## Esc and a Boot menu button leave a match. Settings still closes on Esc first.
## The how-to closes on the first Esc. A second Esc returns to the boot menu.

func _ready() -> void:
	set_process_unhandled_input(true)
	call_deferred("_arm")

func _arm() -> void:
	var layer: CanvasLayer = _layer()
	if layer == null:
		return
	if layer.find_child("MissionBoot", true, false) != null:
		return
	var back: Button = Button.new()
	back.name = "MissionBoot"
	back.text = "Boot menu"
	back.position = Vector2(568, 40)
	back.custom_minimum_size = Vector2(160, 36)
	back.z_index = 40
	back.pressed.connect(_to_boot)
	layer.add_child(back)

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
	var guide: CanvasItem = host.find_child("HowToOverlay", true, false) as CanvasItem
	if guide != null and guide.visible:
		guide.visible = false
		_handled()
		return
	var boot: BaseButton = host.find_child("MissionBoot", true, false) as BaseButton
	if boot != null:
		boot.pressed.emit()
	else:
		_to_boot()
	_handled()

func _to_boot() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	tree.change_scene_to_file("res://game/boot.tscn")

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
