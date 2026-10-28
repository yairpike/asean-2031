extends Control
## Soft left-hand shade and spark motes, painted above the menu video.

var _spin: float = 0.0
var _sparks: Array[Vector3] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for i: int in 42:
		_sparks.append(Vector3(randf(), randf(), randf_range(0.12, 0.55)))

func _process(delta: float) -> void:
	_spin += delta * 0.22
	for i: int in _sparks.size():
		var mote: Vector3 = _sparks[i]
		mote.y -= delta * mote.z * 0.08
		mote.x += delta * 0.01
		if mote.y < 0.0:
			mote.y = 1.0
			mote.x = randf()
		_sparks[i] = mote
	queue_redraw()

func _draw() -> void:
	var reach: float = minf(size.x * 0.5, 640.0)
	var steps: int = 28
	for i: int in steps:
		var t0: float = float(i) / float(steps)
		var t1: float = float(i + 1) / float(steps)
		var falloff: float = (1.0 - t0) * (1.0 - t0)
		draw_rect(Rect2(reach * t0, 0.0, reach * (t1 - t0) + 1.0, size.y), Color(0.0, 0.0, 0.0, 0.62 * falloff))
	for mote: Vector3 in _sparks:
		var at := Vector2(mote.x * size.x, mote.y * size.y)
		var ink := Color(1.0, 0.72, 0.38, 0.35 + mote.z * 0.4)
		draw_rect(Rect2(at, Vector2(1.5 + mote.z * 2.0, 1.5 + mote.z * 2.0)), ink)
