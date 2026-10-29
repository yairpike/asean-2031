extends SceneTree
## Windowed screenshot of a match HUD. Not part of the test suite.
## godot --path . --resolution 1280x720 -s res://tools/hud_shot.gd -- --scene res://game/burma_road.tscn --faction gtfc --out /tmp/a.png [--skin black_market] [--wait 3] [--menu boot|pause|settings]

var _args: Dictionary = {}
var _clock: float = 0.0
var _selected: bool = false
var _opened: bool = false

func _initialize() -> void:
	var raw: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = 0
	while i < raw.size():
		var key: String = raw[i].trim_prefix("--")
		var value: String = raw[i + 1] if i + 1 < raw.size() else ""
		_args[key] = value
		i += 2
	SMFront.faction_id = str(_args.get("faction", "gtfc"))
	if _args.has("skin"):
		root.set_meta("hud_skin", str(_args["skin"]))
	change_scene_to_file(str(_args.get("scene", "res://game/burma_road.tscn")))

func _process(delta: float) -> bool:
	_clock += delta
	var scene: Node = current_scene
	if scene == null:
		return false
	var wait: float = float(_args.get("wait", "3"))
	if not _selected and _clock > wait * 0.5:
		_selected = true
		var field: SMPointer = scene.get("field") as SMPointer
		if field != null:
			var mine: Array[RTSUnit] = field.units_of(SMPointer.PLAYER)
			var pick: Array[RTSUnit] = []
			var want: int = int(_args.get("select", "1"))
			for u: RTSUnit in mine:
				if pick.size() < want:
					pick.append(u)
			if not pick.is_empty():
				field.select_only(pick)
	if not _opened and _clock > wait * 0.7:
		_opened = true
		var menu: String = str(_args.get("menu", ""))
		if menu == "pause":
			var pause: CanvasItem = scene.find_child("PauseMenu", true, false) as CanvasItem
			if pause != null:
				pause.visible = true
		elif menu == "settings":
			var settings: Control = scene.find_child("SettingsPanel", true, false) as Control
			if settings != null:
				settings.visible = true
		elif menu == "guide":
			var guide: CanvasItem = scene.find_child("HowToOverlay", true, false) as CanvasItem
			if guide != null:
				guide.visible = true
		elif menu == "alert":
			var hud: SMHud = scene.get("hud") as SMHud
			if hud != null:
				hud.show_line("Unit ready")
	if _clock > wait:
		var image: Image = root.get_texture().get_image()
		image.save_png(str(_args.get("out", "/tmp/hud_shot.png")))
		quit()
	return false
