extends Node
## Web touch: one finger pans the match camera, two fingers pinch to zoom.

var points: Dictionary[int, Vector2] = {}
var span: float = 0.0
var moved: bool = false
var travel: float = 0.0
var last_group: int = -1
var last_group_ms: int = 0

func _unhandled_input(event: InputEvent) -> void:
	if _toggle_help(event):
		return
	if _toggle_protocols(event):
		return
	if _command_key(event):
		return
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			points[touch.index] = touch.position
			if points.size() == 1:
				moved = false
				travel = 0.0
		else:
			points.erase(touch.index)
		span = _span()
		return
	var drag: InputEventScreenDrag = event as InputEventScreenDrag
	if drag == null:
		return
	points[drag.index] = drag.position
	travel += drag.relative.length()
	if travel > 12.0:
		moved = true
	var camera: RTSCamera = _camera()
	if camera == null:
		return
	if points.size() >= 2:
		var next: float = _span()
		if span > 1.0 and next > 1.0:
			pinch_camera(camera, span, next)
		span = next
	else:
		pan_camera(camera, drag.relative)

func _toggle_help(event: InputEvent) -> bool:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_H:
		return false
	var overlay: Control = get_tree().root.find_child("HowToOverlay", true, false) as Control
	if overlay == null:
		return false
	overlay.visible = not overlay.visible
	get_viewport().set_input_as_handled()
	return true

func _toggle_protocols(event: InputEvent) -> bool:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_P:
		return false
	var toggle: BaseButton = get_tree().root.find_child("ProtocolsToggle", true, false) as BaseButton
	if toggle == null:
		return false
	toggle.pressed.emit()
	get_viewport().set_input_as_handled()
	return true

func _command_key(event: InputEvent) -> bool:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return false
	var match_field: SMPointer = _field()
	if match_field == null:
		return false
	if key.keycode == KEY_X:
		match_field.halt_selected()
		get_viewport().set_input_as_handled()
		return true
	if key.keycode == KEY_Q:
		var aim_cam: RTSCamera = _camera()
		var at: Vector3 = match_field.aim_from_camera(aim_cam, get_viewport().get_mouse_position())
		match_field.attack_move_at(at)
		get_viewport().set_input_as_handled()
		return true
	if key.keycode == KEY_E:
		match_field.select_same()
		get_viewport().set_input_as_handled()
		return true
	if key.keycode == KEY_Z:
		match_field.toggle_line()
		get_viewport().set_input_as_handled()
		return true
	if key.keycode == KEY_R:
		var board: SMHud = _hud()
		if board == null:
			return false
		var rally_cam: RTSCamera = _camera()
		board.set_rally(match_field.aim_from_camera(rally_cam, get_viewport().get_mouse_position()))
		get_viewport().set_input_as_handled()
		return true
	var index: int = _digit(key.keycode)
	if index < 1:
		return false
	if key.ctrl_pressed or key.meta_pressed:
		match_field.bind_group(index, true)
	else:
		match_field.bind_group(index, false)
		var now: int = Time.get_ticks_msec()
		if last_group == index and now - last_group_ms < 420:
			var focus: Vector3 = match_field.selection_focus()
			var jump_cam: RTSCamera = _camera()
			if jump_cam != null and focus != Vector3.INF:
				jump_cam.focus_on(focus)
		last_group = index
		last_group_ms = now
	get_viewport().set_input_as_handled()
	return true

func _digit(code: Key) -> int:
	if code >= KEY_1 and code <= KEY_9:
		return int(code) - int(KEY_1) + 1
	if code >= KEY_KP_1 and code <= KEY_KP_9:
		return int(code) - int(KEY_KP_1) + 1
	return 0

func _hud() -> SMHud:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	var raw: Variant = scene.get("hud")
	if raw is SMHud:
		return raw as SMHud
	return null

func _field() -> SMPointer:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	var raw: Variant = scene.get("field")
	if raw is SMPointer:
		return raw as SMPointer
	return null

func _process(_delta: float) -> void:
	if points.is_empty():
		moved = false
		travel = 0.0

func pan_camera(camera: RTSCamera, slide: Vector2) -> void:
	if camera == null:
		return
	camera.pan(Vector2(slide.x, -slide.y) * 0.02, 1.0)

func pinch_camera(camera: RTSCamera, previous: float, current: float) -> void:
	if camera == null or previous <= 1.0 or current <= 1.0:
		return
	var steps: float = (current - previous) / 30.0
	camera.zoom(steps)

func _camera() -> RTSCamera:
	var vp: Viewport = get_viewport()
	if vp == null:
		return null
	return vp.get_camera_3d() as RTSCamera

func _span() -> float:
	if points.size() < 2:
		return 0.0
	var keys: Array[int] = []
	for key: int in points.keys():
		keys.append(key)
		if keys.size() == 2:
			break
	return points[keys[0]].distance_to(points[keys[1]])
