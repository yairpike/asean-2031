extends RefCounted
## Subscribes match scenes to sim signals. The SM scripts do not preload this.

const World = preload("res://game/world_view.gd")
const Forms = preload("res://game/unit_meshes.gd")
const FX = preload("res://game/fx_view.gd")
const SettingsPanel = preload("res://game/settings_panel.gd")
const Settings = preload("res://game/match_settings.gd")
const Clips = preload("res://game/match_audio.gd")
const Cameos = preload("res://game/match_cameos.gd")

static func follow(host: Node) -> void:
	if host == null or bool(host.get_meta("view_bound", false)):
		return
	host.set_meta("view_bound", true)
	var field: SMPointer = host.get("field") as SMPointer
	if field != null:
		follow_pointer(field)
	var sim: SMMatch = host.get("sim") as SMMatch
	if sim != null:
		_follow_match(sim)
	var side: SMSide = host.get("side") as SMSide
	if field != null and side != null:
		field.side_link = side
	if side != null and not bool(side.get_meta("view_bound", false)):
		side.set_meta("view_bound", true)
		side.slab_made.connect(Callable(World, "slab"))
	var raider: SMRaider = host.get("raider") as SMRaider
	if raider != null and not bool(raider.get_meta("view_bound", false)):
		raider.set_meta("view_bound", true)
		raider.marker_made.connect(Callable(World, "slab"))
		raider.banner_made.connect(Callable(World, "billboard"))
	var story: SMStory = host.get("story") as SMStory
	if story != null and not bool(story.get_meta("view_bound", false)):
		story.set_meta("view_bound", true)
		story.pad_made.connect(Callable(World, "plain_slab"))
	var sight: SMSight = host.get("sight") as SMSight
	if sight != null and not bool(sight.get_meta("view_bound", false)):
		sight.set_meta("view_bound", true)
		sight.match_drawn.connect(Callable(World, "sync"))
	var hud: SMHud = host.get("hud") as SMHud
	if hud != null and not bool(hud.get_meta("view_bound", false)):
		hud.set_meta("view_bound", true)
		hud.chrome = Callable(preload("res://game/match_hud_view.gd"), "install")
		hud.layer_mounted.connect(_on_layer)
	Clips.arm(host, "match")
	if host.get_node_or_null("CameraFit") == null:
		var fitter: Node = Node.new()
		fitter.name = "CameraFit"
		fitter.set_script(preload("res://game/camera_fit.gd"))
		host.add_child(fitter)

static func follow_pointer(field: SMPointer) -> void:
	if field == null or bool(field.get_meta("view_bound", false)):
		return
	field.set_meta("view_bound", true)
	field.dressed.connect(Callable(FX, "dress"))
	field.unit_made.connect(_on_unit.bind(field))
	field.unit_posed.connect(Callable(Forms, "animate"))
	field.status_shown.connect(_on_status)
	field.beacon_moved.connect(Callable(World, "place_beacon"))
	field.rally_moved.connect(Callable(World, "place_rally"))
	field.wreck_made.connect(_on_wreck.bind(field))
	field.ping_made.connect(_on_ping.bind(field))
	field.path_moved.connect(Callable(World, "path_mark"))
	field.damage_shown.connect(Callable(World, "damage_pop"))

static func _follow_match(sim: SMMatch) -> void:
	if bool(sim.get_meta("view_bound", false)):
		return
	sim.set_meta("view_bound", true)
	sim.site_made.connect(Callable(World, "place_site"))
	sim.plate_sunk.connect(Callable(World, "sink_named"))
	sim.deck_fit.connect(Callable(World, "fit_deck"))

static func _on_unit(u: RTSUnit, team: int, kind: String, role: String, loco: String, tint: Color, label: String, field: SMPointer) -> void:
	var body: MeshInstance3D = Forms.dress_unit(kind, role, loco, tint)
	u.add_child(body)
	World.dress_spawn(u, team, label)
	field.visual_node = body

static func _on_status(body: MeshInstance3D, frozen: bool) -> void:
	if body == null:
		return
	var mat: Material = null
	if frozen:
		mat = FX.ice_material()
	Forms.paint_status(body, mat)

static func _on_wreck(host: Node3D, at: Vector3, field: SMPointer) -> void:
	field.visual_node = World.wreck(host, at)

static func _on_ping(host: Node3D, at: Vector3, order: String, field: SMPointer) -> void:
	field.visual_node = World.order_ping(host, at, order)

static func _on_layer(who: SMHud, layer: CanvasLayer) -> void:
	SettingsPanel.attach(layer)
	if who == null:
		return
	who.cameo_for = Callable(Cameos, "texture")
	who.apply_cameos()
	Cameos.arm(layer, who)
	if who.sfx == null:
		return
	who.sfx.cue_level = Callable(Settings, "cue_db")
	who.sfx.clip_for = Callable(Clips, "clip_for")
	Clips.color_voice(who.sfx)
	who.sfx.apply_levels()
