extends RefCounted
## Graphics, volume, and camera preferences. user:// is the source of truth.
## Web builds also mirror the same record into IndexedDB.

const PATH: String = "user://settings.cfg"
const IDB_JS: String = "(function(payload){if(!self.indexedDB)return;var openReq=indexedDB.open('asean2031',1);openReq.onupgradeneeded=function(){if(!openReq.result.objectStoreNames.contains('saves'))openReq.result.createObjectStore('saves');};openReq.onsuccess=function(){var tx=openReq.result.transaction('saves','readwrite');tx.objectStore('saves').put(payload,'settings');};})(%s);"

static var loaded: bool = false
static var graphics: String = "high"
static var master: float = 1.0
static var sfx: float = 1.0
static var pan: float = 1.0
static var edge: bool = true
static var difficulty: String = "normal"
static var lock: String = ""

static func hold(q: String) -> void:
	lock = q

static func quality_for_adapter(adapter: String) -> String:
	var name: String = adapter.to_lower()
	if name.contains("swiftshader") or name.contains("llvmpipe") or name.contains("softpipe") or name.contains("software") or name.contains("lavapipe"):
		return "low"
	return "high"

static func ensure() -> void:
	if loaded:
		return
	if FileAccess.file_exists(PATH):
		loaded = true
		_read()
		return
	var adapter: String = _adapter()
	if adapter.strip_edges() == "" and OS.has_feature("web"):
		return
	loaded = true
	graphics = quality_for_adapter(adapter)
	_write()

static func _adapter() -> String:
	var name: String = RenderingServer.get_video_adapter_name()
	if not OS.has_feature("web"):
		return name
	var js: String = "(function(){try{var c=document.querySelector('canvas');if(!c)return'';var gl=c.getContext('webgl2');if(!gl)return'';var ext=gl.getExtension('WEBGL_debug_renderer_info');if(!ext)return String(gl.getParameter(gl.RENDERER));return String(gl.getParameter(ext.UNMASKED_RENDERER_WEBGL));}catch(e){return'';}})()"
	var extra: String = str(JavaScriptBridge.eval(js))
	if extra == "null" or extra == "<null>":
		extra = ""
	return "%s %s" % [name, extra]

static func reread() -> void:
	loaded = false
	ensure()

static func effective() -> String:
	if lock != "":
		return lock
	ensure()
	return graphics

static func low() -> bool:
	return effective() == "low"

static func idb_script() -> String:
	return IDB_JS

static func set_graphics(q: String) -> void:
	ensure()
	graphics = "low" if q == "low" else "high"
	_write()

static func set_master(v: float) -> void:
	ensure()
	master = clampf(v, 0.0, 1.0)
	_write()

static func set_sfx(v: float) -> void:
	ensure()
	sfx = clampf(v, 0.0, 1.0)
	_write()

static func set_pan(v: float) -> void:
	ensure()
	pan = clampf(v, 0.4, 2.2)
	_write()

static func set_edge(on: bool) -> void:
	ensure()
	edge = on
	_write()

static func set_difficulty(id: String) -> void:
	ensure()
	if id == "easy" or id == "hard":
		difficulty = id
	else:
		difficulty = "normal"
	_write()

static func pace() -> Dictionary:
	ensure()
	if difficulty == "easy":
		return {"income": 0.55, "wave_time": 1.7, "wave_size": 0.55, "react": 1.75, "hp": 0.7, "damage": 0.65}
	if difficulty == "hard":
		return {"income": 2.4, "wave_time": 0.12, "wave_size": 2.0, "react": 0.45, "hp": 1.45, "damage": 1.4}
	return {"income": 1.0, "wave_time": 1.0, "wave_size": 1.0, "react": 1.0, "hp": 1.0, "damage": 1.0}

static func apply_raider(raider: SMRaider) -> void:
	if raider == null:
		return
	var row: Dictionary = pace()
	raider.apply_pace(float(row["income"]), float(row["wave_time"]), float(row["wave_size"]), float(row["react"]))

static func apply_story(story: SMStory) -> void:
	if story == null:
		return
	var row: Dictionary = pace()
	story.prepare_foe(float(row["hp"]), float(row["damage"]))

static func cue_db(base: float) -> float:
	ensure()
	if sfx <= 0.001:
		return -80.0
	return base + linear_to_db(sfx)

static func apply_scene(host: Node) -> void:
	ensure()
	var db: float = -80.0
	if master > 0.001:
		db = linear_to_db(master)
	AudioServer.set_bus_volume_db(0, db)
	if host == null:
		return
	var allow_shadow: bool = not low()
	var lights: Array[Node] = host.find_children("", "DirectionalLight3D", true, false)
	for node: Node in lights:
		var light: DirectionalLight3D = node as DirectionalLight3D
		if light != null:
			light.shadow_enabled = allow_shadow
	var cam: RTSCamera = host.find_child("Camera", true, false) as RTSCamera
	if cam == null:
		return
	if not cam.has_meta("edge_authored"):
		cam.set_meta("edge_authored", cam.edge_pan_px)
	var authored: float = float(cam.get_meta("edge_authored"))
	cam.pan_speed = pan
	cam.edge_pan_px = authored if edge else 0.0

static func _read() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	var stored: String = str(cfg.get_value("game", "graphics", "high"))
	graphics = "low" if stored == "low" else "high"
	master = clampf(float(cfg.get_value("game", "master", 1.0)), 0.0, 1.0)
	sfx = clampf(float(cfg.get_value("game", "sfx", 1.0)), 0.0, 1.0)
	pan = clampf(float(cfg.get_value("game", "pan", 1.0)), 0.4, 2.2)
	edge = bool(cfg.get_value("game", "edge", true))
	var stored_diff: String = str(cfg.get_value("game", "difficulty", "normal"))
	if stored_diff == "easy" or stored_diff == "hard":
		difficulty = stored_diff
	else:
		difficulty = "normal"

static func _write() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("game", "graphics", graphics)
	cfg.set_value("game", "master", master)
	cfg.set_value("game", "sfx", sfx)
	cfg.set_value("game", "pan", pan)
	cfg.set_value("game", "edge", edge)
	cfg.set_value("game", "difficulty", difficulty)
	cfg.save(PATH)
	_mirror()

static func _mirror() -> void:
	if not OS.has_feature("web"):
		return
	var payload: Dictionary = {
		"graphics": graphics,
		"master": master,
		"sfx": sfx,
		"pan": pan,
		"edge": edge,
		"difficulty": difficulty,
	}
	var body: String = JSON.stringify(payload)
	JavaScriptBridge.eval(IDB_JS % JSON.stringify(body))
