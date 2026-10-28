extends Node
## Scripted opener for a story mission.
## Beats are presentation. They do not change the win.
## A hero line plays from dialogue/<language>/<mission>/<beat>.ogg
## when that clip exists. Otherwise the subtitle stands alone.

const Clips = preload("res://game/match_audio.gd")
const Cameos = preload("res://game/match_cameos.gd")

var mission_id: String = ""
var stage: int = 0
var line_text: String = ""
var intro_done: bool = false
var outro_started: bool = false
var outro_done: bool = false
var bridge_down: bool = false
var betrayed: bool = false
var ambush_spawned: bool = false
var reinforced: bool = false
var weather_turned: bool = false
var bonus_done: bool = false
var bonus_at: Vector3 = Vector3(12.0, 0.0, -8.0)
var home_focus: Vector3 = Vector3.ZERO
var home_distance: float = 18.0
var wide_distance: float = 42.0
var faction: String = "gtfc"
var cameo_id: String = "militia"
var speaker_name: String = "Night commander"
var last_voiced: bool = false

var _host: Node3D
var _clock: float = 0.0
var _armed: bool = false
var _outro_t: float = 0.0
var _outro_from: float = 18.0
var _intro_from: Vector3 = Vector3.ZERO
var _intro_to: Vector3 = Vector3.ZERO
var _plate: ColorRect
var _portrait: TextureRect
var _speaker: Label
var _subtitle: Label
var _bonus: Label
var _bridge: MeshInstance3D

static func attach(host: Node3D, id: String) -> void:
	if host == null:
		return
	if not _covered(id):
		return
	if host.get_node_or_null("SetPiece") != null:
		return
	var piece: Node = Node.new()
	piece.name = "SetPiece"
	piece.set_script(load("res://game/set_piece.gd") as GDScript)
	host.add_child(piece)
	piece.call("open", host, id)

func open(host: Node3D, id: String) -> void:
	_host = host
	mission_id = id
	_cast()
	_chrome()
	_span()
	_say(_line("open"), "", "open")

func drive(delta: float) -> void:
	if _host == null:
		return
	_clock += maxf(delta, 0.0)
	if not _armed:
		_arm_camera()
	var story: SMStory = _host.get("story") as SMStory
	if story != null and (story.done or story.lost):
		_outro(delta)
		return
	_intro()
	if _clock >= 5.0 and not ambush_spawned:
		_ambush()
	if _clock >= 11.0 and not bridge_down:
		_blow()
	if _clock >= 17.0 and not reinforced:
		_reinforce()
	if _clock >= 23.0 and not weather_turned:
		_weather()
	_bonus_check()
	_press_patani()
	_recount()

static func _covered(id: String) -> bool:
	return id == "kokang" or id == "tachileik" or id == "shwe_kokko" or id == "operation_1027" or id == "andaman" or id == "ghosts_of_patani" or id == "kilometer_watch" or id == "black_haze" or id == "archipelago_rising" or id == "wrath_of_the_garuda" or id == "fog_over_pakbeng" or id == "keng_tung" or id == "plain_of_jars" or id == "tonle_sap" or id == "shattered_monsoon"

func _cast() -> void:
	faction = "gtfc"
	cameo_id = "militia"
	speaker_name = "Night commander"
	bonus_at = Vector3(12.0, 0.0, -8.0)
	if mission_id == "tachileik":
		cameo_id = "slag_hauler"
		speaker_name = "Caravan master"
		bonus_at = Vector3(-16.0, 0.0, 8.0)
	elif mission_id == "shwe_kokko":
		cameo_id = "bullion_truck"
		speaker_name = "Compound runner"
		bonus_at = Vector3(16.0, 0.0, -10.0)
	elif mission_id == "operation_1027":
		cameo_id = "orlan10"
		speaker_name = "Strip lead"
		bonus_at = Vector3(-16.0, 0.0, 10.0)
	elif mission_id == "andaman":
		cameo_id = "channel_skiff"
		speaker_name = "Beach master"
		bonus_at = Vector3(-16.0, 0.0, 8.0)
	elif mission_id == "ghosts_of_patani":
		faction = "nmrf"
		cameo_id = "river_rifle"
		speaker_name = "River commander"
		bonus_at = Vector3(-14.0, 0.0, 8.0)
	elif mission_id == "kilometer_watch":
		faction = "nmrf"
		cameo_id = "olive_ranger"
		speaker_name = "Watch captain"
		bonus_at = Vector3(-16.0, 0.0, 10.0)
	elif mission_id == "black_haze":
		faction = "nmrf"
		cameo_id = "mangrove_skiff"
		speaker_name = "Haze coxswain"
		bonus_at = Vector3(16.0, 0.0, 10.0)
	elif mission_id == "archipelago_rising":
		faction = "nmrf"
		cameo_id = "packer"
		speaker_name = "Packer captain"
		bonus_at = Vector3(-18.0, 0.0, -10.0)
	elif mission_id == "wrath_of_the_garuda":
		faction = "nmrf"
		cameo_id = "emerald_gunboat"
		speaker_name = "Fleet captain"
		bonus_at = Vector3(18.0, 0.0, 8.0)
	elif mission_id == "fog_over_pakbeng":
		faction = "mvd"
		cameo_id = "clearance_trooper"
		speaker_name = "Clearance commander"
		bonus_at = Vector3(-14.0, 0.0, 8.0)
	elif mission_id == "keng_tung":
		faction = "mvd"
		cameo_id = "charcoal_mortar"
		speaker_name = "Defoliation lead"
		bonus_at = Vector3(-16.0, 0.0, 12.0)
	elif mission_id == "plain_of_jars":
		faction = "mvd"
		cameo_id = "spectrum_prism"
		speaker_name = "Beam officer"
		bonus_at = Vector3(16.0, 0.0, -12.0)
	elif mission_id == "tonle_sap":
		faction = "mvd"
		cameo_id = "cyan_skiff"
		speaker_name = "Ferry warden"
		bonus_at = Vector3(-18.0, 0.0, 6.0)
	elif mission_id == "shattered_monsoon":
		faction = "mvd"
		cameo_id = "hub_drone"
		speaker_name = "Citadel officer"
		bonus_at = Vector3(18.0, 0.0, -8.0)

func _line(beat: String) -> String:
	if mission_id == "tachileik":
		if beat == "ambush":
			return "Contact on the jade road."
		if beat == "bridge":
			return "The span is cut, and the guide has sold the road."
		if beat == "relief":
			return "Two rifles from Tachileik are with the wagon."
		if beat == "weather":
			return "Rain on the jade road. Keep the wagon moving."
		return "The jade wagon is on the road. Break the ambush."
	if mission_id == "shwe_kokko":
		if beat == "ambush":
			return "Garrison in the trees."
		if beat == "bridge":
			return "The span drops. The runner turns."
		if beat == "relief":
			return "A pair from the river are in."
		if beat == "weather":
			return "Rain on the compound. Keep the siphon up."
		return "Both server blocks are live. Take the compound."
	if mission_id == "operation_1027":
		if beat == "ambush":
			return "Escorts on the strip."
		if beat == "bridge":
			return "The span is down. The guide is with the junta."
		if beat == "relief":
			return "Two more rifles for the strip."
		if beat == "weather":
			return "Rain over the airfield. Finish the towers."
		return "The jammers are up. The hangars are still parked."
	if mission_id == "andaman":
		if beat == "ambush":
			return "Boats in the cut."
		if beat == "bridge":
			return "The span is gone. The pilot turns."
		if beat == "relief":
			return "Two rifles from the near shore are in."
		if beat == "weather":
			return "The squall is on. Cross while it lasts."
		return "The channel is held. Land the far shore."
	if mission_id == "kilometer_watch":
		if beat == "ambush":
			return "Contact on the kilometer road."
		if beat == "bridge":
			return "The span is cut. The guide has sold the watch."
		if beat == "relief":
			return "Two rifles from the watch are in."
		if beat == "weather":
			return "Rain on the road. Hold the radar."
		return "The hydro radar is dark. Take the garrison and light the water."
	if mission_id == "black_haze":
		if beat == "ambush":
			return "Raiders in the black haze."
		if beat == "bridge":
			return "The span drops. The pilot turns."
		if beat == "relief":
			return "Two boats from the mangrove are in."
		if beat == "weather":
			return "Rain cuts the haze. Keep the radar."
		return "The haze is thick. Take the radar and stay on it."
	if mission_id == "archipelago_rising":
		if beat == "ambush":
			return "Picket boats in the cut."
		if beat == "bridge":
			return "The span is gone. The guide turns with the tide."
		if beat == "relief":
			return "Two rifles from the near islet are in."
		if beat == "weather":
			return "The squall is on. Unpack while it lasts."
		return "The atoll is held by boats. Sail the packer in and raise the wharf."
	if mission_id == "wrath_of_the_garuda":
		if beat == "ambush":
			return "Pickets off the bow."
		if beat == "bridge":
			return "The span is down. The pilot is with them."
		if beat == "relief":
			return "Two gunboats from the river are in."
		if beat == "weather":
			return "Rain on the fleet. Finish the hulls."
		return "The joint fleet is in the channel. Sink it."
	if mission_id == "ghosts_of_patani":
		if beat == "ambush":
			return "Ambush in the mist."
		if beat == "bridge":
			return "The guide turns on us. The span is down."
		if beat == "relief":
			return "Boats are in. Hold the company together."
		if beat == "weather":
			return "The sky is closing."
		return "The jammer is live. Fiber holds. GPS does not."
	if mission_id == "keng_tung":
		if beat == "ambush":
			return "Infantry screen in the trees."
		if beat == "bridge":
			return "The span is cut. The guide is with the column."
		if beat == "relief":
			return "Two troopers from Keng Tung are in."
		if beat == "weather":
			return "Rain on the column. Keep the spray on the tanks."
		return "The tank column is on the road. Freeze it, then break it."
	if mission_id == "plain_of_jars":
		if beat == "ambush":
			return "A screen on the jars."
		if beat == "bridge":
			return "The span drops. The guide turns."
		if beat == "relief":
			return "Two rifles for the beam crew."
		if beat == "weather":
			return "Rain on the plain. Keep the beam on the phantom."
		return "The phantom is on the plain. Hold the beam until it freezes."
	if mission_id == "tonle_sap":
		if beat == "ambush":
			return "Trimarans in the channel."
		if beat == "bridge":
			return "The span is gone. The pilot turns on the ferry."
		if beat == "relief":
			return "Two rifles from the near bank are in."
		if beat == "weather":
			return "The squall is on. Keep the ferry afloat."
		return "The ferry has to live. Hold it through the trimarans."
	if mission_id == "shattered_monsoon":
		if beat == "ambush":
			return "Garrison off the citadel."
		if beat == "bridge":
			return "The span is cut. The guide is inside."
		if beat == "relief":
			return "Two troopers from the hub are in."
		if beat == "weather":
			return "The monsoon is on. Finish both weapons."
		return "Both superweapons are live. Break the screen and drop them."
	if mission_id == "fog_over_pakbeng":
		if beat == "ambush":
			return "Raiders in the murk."
		if beat == "bridge":
			return "An ally breaks. The span is down."
		if beat == "relief":
			return "Relief is on the road."
		if beat == "weather":
			return "The haze has closed in. Do not leave the radar."
		return "The haze is the weapon. Hold the radar."
	if beat == "ambush":
		return "Contact on the road. Ambush."
	if beat == "bridge":
		return "The slag bridge is cut, and the guide has turned."
	if beat == "relief":
		return "Two rifles from the night shift are here."
	if beat == "weather":
		return "The rain is on. Keep the company moving."
	return "Raise the yard before the Orlans find the pits."

func _chrome() -> void:
	var layer: CanvasLayer = _host.get("ui_layer") as CanvasLayer
	if layer == null:
		return
	var panel: Control = Control.new()
	panel.name = "SetDialogue"
	panel.position = Vector2(220.0, 500.0)
	panel.size = Vector2(720.0, 128.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	_plate = ColorRect.new()
	_plate.name = "SetPortraitPlate"
	_plate.position = Vector2(0.0, 8.0)
	_plate.size = Vector2(84.0, 84.0)
	_plate.color = _tint()
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_plate)
	_portrait = TextureRect.new()
	_portrait.name = "SetPortrait"
	_portrait.position = Vector2(0.0, 8.0)
	_portrait.size = Vector2(84.0, 84.0)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.texture = Cameos.texture(faction, cameo_id)
	panel.add_child(_portrait)
	_speaker = Label.new()
	_speaker.name = "SetSpeaker"
	_speaker.position = Vector2(96.0, 4.0)
	_speaker.size = Vector2(600.0, 22.0)
	_speaker.text = speaker_name
	_speaker.add_theme_font_size_override("font_size", 15)
	_speaker.add_theme_color_override("font_color", _tint())
	_speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_speaker)
	_subtitle = Label.new()
	_subtitle.name = "SetSubtitle"
	_subtitle.position = Vector2(96.0, 28.0)
	_subtitle.size = Vector2(600.0, 48.0)
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.clip_text = true
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle.add_theme_font_size_override("font_size", 16)
	_subtitle.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	panel.add_child(_subtitle)
	_bonus = Label.new()
	_bonus.name = "SetBonus"
	_bonus.position = Vector2(96.0, 80.0)
	_bonus.size = Vector2(600.0, 24.0)
	_bonus.text = "Bonus: reach the side cache"
	_bonus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bonus.add_theme_font_size_override("font_size", 14)
	_bonus.add_theme_color_override("font_color", Color(0.78, 0.84, 0.7))
	panel.add_child(_bonus)

func _tint() -> Color:
	if faction == "nmrf":
		return Color(0.35, 0.62, 0.28)
	if faction == "mvd":
		return Color(0.15, 0.75, 0.82)
	return Color(0.72, 0.12, 0.18)

func _span() -> void:
	_bridge = MeshInstance3D.new()
	_bridge.name = "SetBridge"
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(6.0, 0.35, 1.2)
	_bridge.mesh = mesh
	_bridge.position = Vector3(0.0, 0.7, 11.0)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.38, 0.28)
	_bridge.material_override = mat
	_host.add_child(_bridge)

func _arm_camera() -> void:
	_armed = true
	var cam: RTSCamera = _host.get_node_or_null("Camera") as RTSCamera
	if cam == null:
		return
	home_focus = cam.focus
	home_distance = cam.distance
	_intro_to = home_focus
	_intro_from = home_focus + Vector3(0.0, 0.0, 12.0)
	wide_distance = minf(cam.zoom_max, home_distance + 24.0)

func _intro() -> void:
	if intro_done:
		return
	var cam: RTSCamera = _host.get_node_or_null("Camera") as RTSCamera
	if cam == null:
		intro_done = true
		return
	var t: float = clampf(_clock / 3.0, 0.0, 1.0)
	cam.focus = _intro_from.lerp(_intro_to, t)
	cam.distance = lerpf(wide_distance, home_distance, t)
	cam.apply()
	if t >= 1.0:
		intro_done = true

func _outro(delta: float) -> void:
	var cam: RTSCamera = _host.get_node_or_null("Camera") as RTSCamera
	if not outro_started:
		outro_started = true
		_outro_from = cam.distance if cam != null else home_distance
	_outro_t += maxf(delta, 0.0)
	if cam == null:
		return
	var t: float = clampf(_outro_t / 3.0, 0.0, 1.0)
	cam.distance = lerpf(_outro_from, minf(cam.zoom_max, _outro_from + 16.0), t)
	cam.apply()
	if t >= 1.0:
		outro_done = true

func _ambush() -> void:
	_quiet(SMPointer.ENEMY, Vector3(14.0, 0.0, 7.0), "ambush")
	_quiet(SMPointer.ENEMY, Vector3(12.0, 0.0, 9.0), "ambush")
	ambush_spawned = true
	_say(_line("ambush"), "base_under_attack", "ambush")

func _blow() -> void:
	if _bridge != null:
		_bridge.position.y = -2.4
		var mat: StandardMaterial3D = _bridge.material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_color = Color(0.22, 0.18, 0.16)
	var turncoat: RTSUnit = _quiet(SMPointer.PLAYER, Vector3(2.0, 0.0, 11.0), "guide")
	if turncoat != null:
		turncoat.team = SMPointer.ENEMY
		turncoat.set_meta("duty", "betray")
		turncoat.set_meta("was_ally", true)
		turncoat.attack_damage = 0.0
	betrayed = true
	bridge_down = true
	_say(_line("bridge"), "unit_lost", "bridge")

func _reinforce() -> void:
	var left: RTSUnit = _quiet(SMPointer.PLAYER, Vector3(-11.0, 0.0, -7.0), "relief")
	var right: RTSUnit = _quiet(SMPointer.PLAYER, Vector3(-9.0, 0.0, -8.0), "relief")
	var dest: Vector3 = Vector3(-6.0, 0.0, -3.0)
	if left != null:
		left.speed = 5.0
		left.set_path(PackedVector3Array([dest]))
	if right != null:
		right.speed = 5.0
		right.set_path(PackedVector3Array([dest + Vector3(1.6, 0.0, 0.4)]))
	reinforced = true
	_say(_line("relief"), "", "relief")

func _weather() -> void:
	weather_turned = true
	if mission_id == "fog_over_pakbeng":
		_say(_line("weather"), "", "weather")
		return
	var sky: SMSight = SMSight.new()
	sky.force_monsoon(true)
	var hud: SMHud = _host.get("hud") as SMHud
	if hud != null:
		hud.use_sight(sky)
		hud.refresh()
	_say(_line("weather"), "", "weather")

func _bonus_check() -> void:
	if bonus_done:
		return
	var field: SMPointer = _host.get("field") as SMPointer
	if field == null:
		return
	for u: RTSUnit in field.units_of(SMPointer.PLAYER):
		if not is_instance_valid(u) or not u.is_alive():
			continue
		if bool(u.get_meta("objective", false)):
			continue
		if u.global_position.distance_to(bonus_at) > 2.4:
			continue
		bonus_done = true
		if _bonus != null:
			_bonus.text = "Bonus complete: side cache"
		return

func _press_patani() -> void:
	if mission_id != "ghosts_of_patani" or not _only_spectacle():
		return
	var field: SMPointer = _host.get("field") as SMPointer
	if field == null:
		return
	var prey: RTSUnit = null
	for u: RTSUnit in field.units_of(SMPointer.ENEMY):
		if is_instance_valid(u) and u.is_alive():
			prey = u
			break
	if prey == null:
		return
	var live: Array[RTSUnit] = []
	for u: RTSUnit in field.units_of(SMPointer.PLAYER):
		if is_instance_valid(u) and u.is_alive() and not bool(u.get_meta("objective", false)) and u.attack_damage > 0.0:
			live.append(u)
	if live.is_empty():
		return
	RTSOrders.attack(live, prey, field.nav_for_unit(live[0]), field.teams)

func _only_spectacle() -> bool:
	var field: SMPointer = _host.get("field") as SMPointer
	if field == null:
		return false
	var any: bool = false
	for u: RTSUnit in field.units_of(SMPointer.ENEMY):
		if not is_instance_valid(u) or not u.is_alive():
			continue
		any = true
		var duty: String = str(u.get_meta("duty", ""))
		if duty != "ambush" and duty != "betray":
			return false
	return any

func _quiet(team: int, at: Vector3, duty: String) -> RTSUnit:
	var field: SMPointer = _host.get("field") as SMPointer
	if field == null:
		return null
	var u: RTSUnit = field.spawn(team, at, &"militia")
	u.max_hp = 16.0
	u.hp = 16.0
	u.attack_damage = 0.0
	u.speed = 0.0
	u.attack_range = 2.0
	u.set_meta("duty", duty)
	u.set_meta("set_piece", true)
	return u

func _say(text: String, key: String, beat: String) -> void:
	line_text = text
	if _subtitle != null:
		_subtitle.text = text
	if _speaker != null:
		_speaker.text = speaker_name
	last_voiced = Clips.dialogue(_host, mission_id, beat)
	if key != "":
		Clips.announce_key(_host, faction, key)

func _recount() -> void:
	var n: int = 1
	if ambush_spawned:
		n += 1
	if bridge_down:
		n += 1
	if reinforced:
		n += 1
	if weather_turned:
		n += 1
	stage = n
