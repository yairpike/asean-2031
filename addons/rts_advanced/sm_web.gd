extends Node
## Browser limits: no MSAA, no shadows, no glow, and a 60 fps cap.

func _ready() -> void:
	if not OS.has_feature("web"):
		return
	Engine.max_fps = 60
	get_tree().node_added.connect(_on_node)
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	vp.msaa_2d = Viewport.MSAA_DISABLED
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED

func _on_node(node: Node) -> void:
	quiet_node(node)

static func quiet_node(node: Node) -> void:
	var light: DirectionalLight3D = node as DirectionalLight3D
	if light != null:
		light.shadow_enabled = false
		return
	var world: WorldEnvironment = node as WorldEnvironment
	if world != null and world.environment != null:
		world.environment.glow_enabled = false
		world.environment.ssao_enabled = false
		world.environment.ssil_enabled = false
		world.environment.sdfgi_enabled = false
