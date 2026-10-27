extends Node
## Web touch: one finger pans the match camera, two fingers pinch to zoom.

var points: Dictionary[int, Vector2] = {}
var span: float = 0.0

func _unhandled_input(event: InputEvent) -> void:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			points[touch.index] = touch.position
		else:
			points.erase(touch.index)
		span = _span()
		return
	var drag: InputEventScreenDrag = event as InputEventScreenDrag
	if drag == null:
		return
	points[drag.index] = drag.position
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
