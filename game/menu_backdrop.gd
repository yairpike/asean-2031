extends Control
## Cinematic still, slow drift, and spark motes.
## Faction screens hold cinematic/{gtfc,nmrf,mvd}.webp.
## The main menu rotates every cinematic still. Settings rotates the two neutrals.
## A missing file stays a dark gradient. Sunburst plates are not used.

const HOLD: float = 8.0

var _main_reel: PackedStringArray = PackedStringArray([
	"gtfc", "nmrf", "mvd", "gtfc_tank", "neutral_rain", "neutral_embers",
])
var _neutral_reel: PackedStringArray = PackedStringArray([
	"neutral_embers", "neutral_rain",
])

var faction_id: String = ""
var screen: String = "main"
var _spin: float = 0.0
var _aim: Vector2 = Vector2.ZERO
var _art: Texture2D
var _reel_t: float = 0.0
var _reel_i: int = 0
var _sparks: Array[Vector3] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i: int in 42:
		_sparks.append(Vector3(randf(), randf(), randf_range(0.12, 0.55)))
	_apply_art()
	if OS.has_feature("web"):
		for stem: String in _main_reel:
			if texture(stem) == null:
				_pull("cinematic/%s.webp" % stem, stem)

func set_faction(id: String) -> void:
	faction_id = id
	_apply_art()

func set_screen(which: String) -> void:
	screen = which
	_apply_art()

func _apply_art() -> void:
	var stem: String = _stem()
	_art = texture(stem)
	if _art == null and OS.has_feature("web") and stem != "":
		_pull("cinematic/%s.webp" % stem, stem)
	queue_redraw()

func _stem() -> String:
	if faction_id == "gtfc" or faction_id == "nmrf" or faction_id == "mvd":
		return faction_id
	var reel: PackedStringArray = _neutral_reel if screen == "settings" else _main_reel
	if reel.is_empty():
		return ""
	return reel[_reel_i % reel.size()]

func _process(delta: float) -> void:
	_spin += delta * 0.22
	if faction_id != "gtfc" and faction_id != "nmrf" and faction_id != "mvd":
		_reel_t += delta
		if _reel_t >= HOLD:
			_reel_t = 0.0
			_reel_i += 1
			_apply_art()
	var view: Vector2 = get_viewport_rect().size
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var norm := Vector2.ZERO
	if view.x > 1.0 and view.y > 1.0:
		norm = Vector2(mouse.x / view.x, mouse.y / view.y) * 2.0 - Vector2.ONE
	_aim = _aim.lerp(norm, minf(1.0, delta * 3.0))
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
	if _art != null:
		_cover(_art)
	else:
		_gradient()
	draw_rect(Rect2(0.0, 0.0, minf(size.x * 0.42, 520.0), size.y), Color(0.0, 0.0, 0.0, 0.28))
	_motes()

func _gradient() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.012, 0.014, 0.02))
	draw_rect(Rect2(0.0, 0.0, size.x, size.y * 0.62), Color(0.03, 0.036, 0.048))
	draw_rect(Rect2(size.x * 0.55, size.y * 0.2, size.x * 0.45, size.y * 0.5), Color(0.05, 0.045, 0.04, 0.35))

func _cover(tex: Texture2D) -> void:
	var pulse: float = 1.0 + sin(_spin) * 0.018
	var pad: float = 36.0 * pulse
	var drift := Vector2(sin(_spin * 0.35) * 16.0, cos(_spin * 0.28) * 8.0)
	var nudge := Vector2(_aim.x * 14.0, _aim.y * 8.0) + drift
	draw_texture_rect(tex, Rect2(-pad + nudge.x, -pad + nudge.y, size.x + pad * 2.0, size.y + pad * 2.0), false)

func _motes() -> void:
	for mote: Vector3 in _sparks:
		var at := Vector2(mote.x * size.x, mote.y * size.y)
		var ink := Color(1.0, 0.72, 0.38, 0.35 + mote.z * 0.4)
		draw_rect(Rect2(at, Vector2(1.5 + mote.z * 2.0, 1.5 + mote.z * 2.0)), ink)

func _pull(file_name: String, slot: String) -> void:
	if not OS.has_feature("web") or file_name.contains("..") or file_name.contains("\\"):
		return
	var http := HTTPRequest.new()
	http.timeout = 20.0
	add_child(http)
	http.request_completed.connect(_got.bind(http, slot))
	var err: Error = http.request(_page() + "ui/menu/" + file_name)
	if err != OK:
		http.queue_free()

func _got(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, slot: String) -> void:
	if is_instance_valid(http):
		http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var image := Image.new()
	var err: Error = image.load_webp_from_buffer(body)
	if err != OK:
		err = image.load_png_from_buffer(body)
	if err != OK:
		err = image.load_jpg_from_buffer(body)
	if err != OK:
		return
	var tex := ImageTexture.create_from_image(image)
	_cache[slot] = tex
	if slot == _stem():
		_art = tex
		queue_redraw()

func _page() -> String:
	var href: String = str(JavaScriptBridge.eval("window.location.href", true))
	var cut: int = href.find("?")
	if cut >= 0:
		href = href.substr(0, cut)
	cut = href.find("#")
	if cut >= 0:
		href = href.substr(0, cut)
	var slash: int = href.rfind("/")
	if slash >= 0:
		href = href.substr(0, slash + 1)
	return href

static var _cache: Dictionary = {}

static func texture(stem: String) -> Texture2D:
	if stem == "" or stem.contains("..") or stem.contains("main_bg") or stem.contains("key_art") or stem.contains("\\"):
		return null
	if _cache.has(stem):
		return _cache[stem] as Texture2D
	for ext: String in ["webp", "png", "jpg"]:
		var bytes: PackedByteArray = _read("cinematic/%s.%s" % [stem, ext])
		if bytes.is_empty():
			continue
		var image := Image.new()
		var err: Error = FAILED
		if ext == "webp":
			err = image.load_webp_from_buffer(bytes)
		elif ext == "png":
			err = image.load_png_from_buffer(bytes)
		else:
			err = image.load_jpg_from_buffer(bytes)
		if err != OK:
			continue
		var tex := ImageTexture.create_from_image(image)
		_cache[stem] = tex
		return tex
	return null

static func _read(file_name: String) -> PackedByteArray:
	if file_name.contains("..") or file_name.begins_with("/") or file_name.contains("\\"):
		return PackedByteArray()
	var packed: String = "res://ui/menu/%s" % file_name
	if FileAccess.file_exists(packed):
		return FileAccess.get_file_as_bytes(packed)
	var roots: PackedStringArray = PackedStringArray()
	roots.append(ProjectSettings.globalize_path("res://").path_join("build/web/ui/menu"))
	roots.append(OS.get_executable_path().get_base_dir().path_join("ui/menu"))
	for root: String in roots:
		var path: String = root.path_join(file_name)
		if FileAccess.file_exists(path):
			return FileAccess.get_file_as_bytes(path)
	return PackedByteArray()
