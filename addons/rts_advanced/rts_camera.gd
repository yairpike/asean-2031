class_name RTSCamera
extends Camera3D
## Three-quarter RTS camera: pans a focus point on the ground, zooms by distance,
## pitch steepens as it zooms out, focus is clamped to `bounds` (XZ rect).
## Input-free core (pan/zoom methods) so it is testable; RTSBindings drives it.

@export var bounds: Rect2 = Rect2(-40, -40, 80, 80)
@export var zoom_min: float = 12.0
@export var zoom_max: float = 60.0
@export var pitch_near: float = 45.0
@export var pitch_far: float = 60.0
@export var yaw_degrees: float = 0.0
@export var pan_speed: float = 1.0
@export var edge_pan_px: float = 0.0

var focus: Vector3 = Vector3.ZERO
var distance: float = 30.0

func _ready() -> void:
	apply()

func zoom_ratio() -> float:
	return inverse_lerp(zoom_min, zoom_max, distance)

func pitch() -> float:
	return lerpf(pitch_near, pitch_far, zoom_ratio())

## Pans in camera-relative XZ (x = right, y = forward), scaled by zoom distance.
func pan(dir: Vector2, delta: float) -> void:
	var yaw: float = deg_to_rad(yaw_degrees)
	var right: Vector3 = Vector3(cos(yaw), 0, -sin(yaw))
	var fwd: Vector3 = Vector3(-sin(yaw), 0, -cos(yaw))
	focus += (right * dir.x + fwd * dir.y) * distance * pan_speed * delta
	apply()

func zoom(steps: float) -> void:
	distance = clampf(distance * pow(0.9, steps), zoom_min, zoom_max)
	apply()

func focus_on(p: Vector3) -> void:
	focus = p
	apply()

func apply() -> void:
	focus.x = clampf(focus.x, bounds.position.x, bounds.end.x)
	focus.z = clampf(focus.z, bounds.position.y, bounds.end.y)
	focus.y = 0.0
	var p: float = deg_to_rad(pitch())
	var yaw: float = deg_to_rad(yaw_degrees)
	var back: Vector3 = Vector3(sin(yaw), 0, cos(yaw)) * cos(p) * distance
	position = focus + back + Vector3(0, sin(p) * distance, 0)
	if position.distance_squared_to(focus) > 0.0001:
		look_at(focus, Vector3.UP)

## World point on the y=0 ground plane under a screen position (INF if none).
func ground_at(screen: Vector2) -> Vector3:
	var o: Vector3 = project_ray_origin(screen)
	var d: Vector3 = project_ray_normal(screen)
	if absf(d.y) < 0.0001:
		return Vector3.INF
	var t: float = -o.y / d.y
	return Vector3.INF if t < 0.0 else o + d * t
