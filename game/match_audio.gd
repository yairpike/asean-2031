extends RefCounted
## Loads music and barks from files beside the page, outside the pack.
## A new bark is barks/{unit}_{select|move|attack}_{n}.ogg; re-export picks it up.
## Missing files leave the procedural cues in place.

const STORE_AUDIO: String = "/cursor/stores/bc-03b4e731-23cd-492a-9d17-7e9a1ed71677/internal/assets/audio"
const HELD_BARK: String = "barks/crimson_sapper_select_2.ogg"

static var _cache: Dictionary = {}
static var _catalog: Dictionary = {}
static var _inflight: Dictionary = {}
static var _buses_ready: bool = false
static var _web_open: bool = false
static var _held: Array[AudioStreamPlayer] = []

static func arm(host: Node, mode: String) -> void:
	if host == null or host.get_node_or_null("MatchAudio") != null:
		return
	_buses()
	var node: Node = (load("res://game/match_audio_player.gd") as GDScript).new() as Node
	node.name = "MatchAudio"
	node.set_meta("mode", mode)
	host.add_child(node)

static func play_menu(host: Node) -> void:
	_buses()
	var player: AudioStreamPlayer = _ensure(host, "MenuMusic")
	player.bus = "Music"
	_assign(player, "music/menu.ogg", true)

static func play_faction(host: Node, faction: String) -> void:
	_buses()
	var player: AudioStreamPlayer = _ensure(host, "FactionMusic")
	player.bus = "Music"
	var id: String = faction
	if id != "gtfc" and id != "nmrf" and id != "mvd" and id != "black_market":
		id = "gtfc"
	_assign(player, "music/%s.ogg" % id, true)

static func play_sting(host: Node, won: bool) -> void:
	var music: AudioStreamPlayer = host.get_node_or_null("FactionMusic") as AudioStreamPlayer
	if music != null:
		music.stop()
	var player: AudioStreamPlayer = _ensure(host, "StingMusic")
	player.bus = "Music"
	var rel: String = "music/victory_sting.ogg" if won else "music/defeat_sting.ogg"
	_assign(player, rel, false)

static func clip_for(unit_id: String, event: String) -> AudioStream:
	if unit_id == "" or (event != "select" and event != "move" and event != "attack"):
		return null
	var found: PackedStringArray = _variants(unit_id, event)
	if found.is_empty():
		return null
	var which: int = absi(("%s:%s" % [unit_id, event]).hash()) % found.size()
	return _stream(found[which])

static func page_base() -> String:
	return _page_base()

static func remember(rel: String) -> void:
	if _skipped(rel) or not rel.ends_with(".ogg") or rel.contains("..") or rel.begins_with("/"):
		return
	_catalog[rel] = true

static func prefetch(owner: Node, rel: String) -> void:
	if owner == null or not OS.has_feature("web") or _skipped(rel) or _cache.has(rel) or _inflight.has(rel):
		return
	if not rel.ends_with(".ogg") or rel.contains("..") or rel.begins_with("/"):
		return
	_inflight[rel] = true
	var http: HTTPRequest = HTTPRequest.new()
	http.timeout = 60.0
	http.accept_gzip = false
	http.name = "ClipFetch"
	owner.add_child(http)
	http.request_completed.connect(_prefetched.bind(http, rel))
	var err: Error = http.request(_page_base() + "audio/" + rel)
	if err != OK:
		_inflight.erase(rel)
		http.queue_free()

static func unlock() -> void:
	_web_open = true
	if OS.has_feature("web"):
		var state: String = str(JavaScriptBridge.eval("window.__aseanUnlockAudio ? window.__aseanUnlockAudio() : 'missing'", true))
		print("audio context state: ", state)
	var pending: Array[AudioStreamPlayer] = []
	for held: AudioStreamPlayer in _held:
		pending.append(held)
	_held.clear()
	for pending_player: AudioStreamPlayer in pending:
		if is_instance_valid(pending_player):
			_start(pending_player)

static func color_voice(sfx: SMSfx) -> void:
	_buses()
	if sfx != null and sfx.voice != null:
		sfx.voice.bus = "Radio"

static func _ensure(host: Node, node_name: String) -> AudioStreamPlayer:
	var found: AudioStreamPlayer = host.get_node_or_null(node_name) as AudioStreamPlayer
	if found != null:
		return found
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = node_name
	host.add_child(player)
	return player

static func _assign(player: AudioStreamPlayer, rel: String, loop: bool) -> void:
	var stream: AudioStream = _stream(rel)
	if stream != null:
		_arm_player(player, stream, loop)
		return
	if OS.has_feature("web"):
		_begin_fetch(player, rel, loop)

static func _arm_player(player: AudioStreamPlayer, stream: AudioStream, loop: bool) -> void:
	var ogg: AudioStreamOggVorbis = stream as AudioStreamOggVorbis
	if ogg != null:
		ogg.loop = loop
	player.stream = stream
	player.volume_db = 0.0
	if _audible():
		_start(player)
	elif not _held.has(player):
		_held.append(player)

static func _audible() -> bool:
	return (not OS.has_feature("web")) or _web_open

static func _start(player: AudioStreamPlayer) -> void:
	if player == null or player.stream == null or player.playing:
		return
	player.play()
	if not OS.has_feature("web"):
		return
	var label: String = "audio"
	if player.name == "MenuMusic":
		label = "menu"
	elif player.name == "FactionMusic":
		label = "faction"
	elif player.name == "StingMusic":
		label = "sting"
	JavaScriptBridge.eval("console.log('%s music playing')" % label, true)

static func _stream(rel: String) -> AudioStream:
	if _skipped(rel):
		return null
	if _cache.has(rel):
		var cached: AudioStream = _cache[rel] as AudioStream
		if cached != null:
			return cached
	var bytes: PackedByteArray = _read_local(rel)
	var stream: AudioStream = _decode(bytes)
	if stream != null:
		_cache[rel] = stream
	return stream

static func _skipped(rel: String) -> bool:
	return rel == HELD_BARK

static func _variants(unit_id: String, event: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var n: int = 1
	while n <= 8:
		var rel: String = "barks/%s_%s_%d.ogg" % [unit_id, event, n]
		if _present(rel):
			found.append(rel)
		n += 1
	return found

static func _present(rel: String) -> bool:
	if _skipped(rel):
		return false
	if _cache.has(rel) and _cache[rel] != null:
		return true
	if _catalog.has(rel):
		return true
	return _local_exists(rel)

static func _local_exists(rel: String) -> bool:
	var roots: PackedStringArray = _roots()
	for root: String in roots:
		if FileAccess.file_exists(root.path_join(rel)):
			return true
	return false

static func _roots() -> PackedStringArray:
	var roots: PackedStringArray = PackedStringArray()
	roots.append(OS.get_executable_path().get_base_dir().path_join("audio"))
	roots.append(ProjectSettings.globalize_path("res://").path_join("build/web/audio"))
	roots.append(STORE_AUDIO)
	return roots

static func _decode(bytes: PackedByteArray) -> AudioStream:
	if bytes.is_empty():
		return null
	return AudioStreamOggVorbis.load_from_buffer(bytes)

static func _read_local(rel: String) -> PackedByteArray:
	var roots: PackedStringArray = _roots()
	for root: String in roots:
		var path: String = root.path_join(rel)
		if FileAccess.file_exists(path):
			return FileAccess.get_file_as_bytes(path)
	return PackedByteArray()

static func _buses() -> void:
	if _buses_ready:
		return
	_buses_ready = true
	_bus("Music", false)
	_bus("Radio", true)

static func _bus(bus_name: String, radio: bool) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var idx: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")
	if not radio:
		return
	var high: AudioEffectHighPassFilter = AudioEffectHighPassFilter.new()
	high.cutoff_hz = 400.0
	AudioServer.add_bus_effect(idx, high)
	var low: AudioEffectLowPassFilter = AudioEffectLowPassFilter.new()
	low.cutoff_hz = 3400.0
	AudioServer.add_bus_effect(idx, low)
	var grit: AudioEffectDistortion = AudioEffectDistortion.new()
	grit.drive = 0.15
	AudioServer.add_bus_effect(idx, grit)

static func _begin_fetch(player: AudioStreamPlayer, rel: String, loop: bool) -> void:
	if player == null or bool(player.get_meta("fetching", false)):
		return
	player.set_meta("fetching", true)
	var http: HTTPRequest = HTTPRequest.new()
	http.name = "AudioFetch"
	http.timeout = 30.0
	http.accept_gzip = false
	player.add_child(http)
	http.request_completed.connect(_fetched.bind(player, http, rel, loop))
	var err: Error = http.request(_page_base() + "audio/" + rel)
	if err != OK:
		player.set_meta("fetching", false)

static func _fetched(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, player: AudioStreamPlayer, http: HTTPRequest, rel: String, loop: bool) -> void:
	if is_instance_valid(player):
		player.set_meta("fetching", false)
	if is_instance_valid(http):
		http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var stream: AudioStream = _decode(body)
	if stream == null or not is_instance_valid(player):
		return
	_cache[rel] = stream
	_catalog[rel] = true
	_arm_player(player, stream, loop)

static func _prefetched(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, rel: String) -> void:
	_inflight.erase(rel)
	if is_instance_valid(http):
		http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or _skipped(rel):
		return
	var stream: AudioStream = _decode(body)
	if stream == null:
		return
	_cache[rel] = stream
	_catalog[rel] = true

static func _page_base() -> String:
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
