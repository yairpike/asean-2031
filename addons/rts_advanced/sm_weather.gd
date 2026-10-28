class_name SMWeather
extends RefCounted
## Monsoon mud. RTSUnit keeps the upstream step. This scales that step.

static func step(u: RTSUnit, delta: float) -> void:
	if u == null or not is_instance_valid(u):
		return
	var drag: float = 1.0
	if u.has_meta("weather_drag"):
		drag = float(u.get_meta("weather_drag"))
	if drag < 0.0:
		drag = 0.0
	if is_equal_approx(drag, 1.0):
		u.advance(delta)
		return
	var saved: float = u.speed_scale
	u.speed_scale = saved * drag
	u.advance(delta)
	u.speed_scale = saved
