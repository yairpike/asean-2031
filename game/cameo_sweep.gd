extends Control
## Clock wipe over a cameo. ratio is 0..1 build progress. The dark wedge is the part still left.

var ratio: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout_mode = 1
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0

func _draw() -> void:
	if ratio <= 0.02 or ratio >= 0.98:
		return
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.5
	if radius < 2.0:
		return
	var left: float = 1.0 - ratio
	var steps: int = 18
	var points: PackedVector2Array = PackedVector2Array()
	points.append(center)
	var sweep: float = TAU * left
	for i: int in steps + 1:
		var ang: float = -PI * 0.5 + sweep * float(i) / float(steps)
		points.append(center + Vector2(cos(ang), sin(ang)) * radius)
	draw_colored_polygon(points, Color(0.02, 0.03, 0.04, 0.62))
