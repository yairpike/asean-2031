extends RefCounted
## Loads music and barks from the served audio/ folder, outside the pack.
## Desktop runs also read res://audio/. A new bark is
## barks/{unit}_{select|move|attack}_{n}.ogg; re-export picks it up.
## Missing files leave the procedural cues in place.
## User songs live in music/user/ and are fetched one at a time. They are
## not part of the startup clip list.

static var _cache: Dictionary = {}
static var _catalog: Dictionary = {}
static var _inflight: Dictionary = {}
static var _buses_ready: bool = false
static var _web_open: bool = false
static var _held: Array[AudioStreamPlayer] = []
static var _queue: PackedStringArray = PackedStringArray()
static var _at: int = 0
static var _player_name: String = ""
static var now_title: String = ""
static var _said: Dictionary = {}

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
	_begin(host, "MenuMusic", _rels_for("menu"))

static func play_faction(host: Node, faction: String) -> void:
	_buses()
	var id: String = faction
	if id != "gtfc" and id != "nmrf" and id != "mvd" and id != "black_market":
		id = "gtfc"
	_begin(host, "FactionMusic", _rels_for(id))

static func play_sting(host: Node, won: bool) -> void:
	_queue = PackedStringArray()
	_at = 0
	now_title = "Victory" if won else "Defeat"
	var music: AudioStreamPlayer = host.get_node_or_null("FactionMusic") as AudioStreamPlayer
	if music != null:
		music.stop()
		music.set_meta("started", false)
	var player: AudioStreamPlayer = _ensure(host, "StingMusic")
	player.bus = "Music"
	var rel: String = "music/victory_sting.ogg" if won else "music/defeat_sting.ogg"
	_assign(player, rel, false)
	_show_title(host)

static func titles_for(list_id: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for rel: String in _rels_for(list_id):
		out.append(_title_of(rel))
	return out

static func current_title() -> String:
	return now_title

static func is_lazy(rel: String) -> bool:
	return rel.begins_with("music/user/") or rel.begins_with("announcer/")

static func alert_key(text: String) -> String:
	var line: String = text.to_lower().strip_edges()
	if line == "low power":
		return "low_power"
	if line.ends_with(" built"):
		return "construction_complete"
	if line == "cannot train" or line == "cannot import":
		return "insufficient_funds"
	if line == "build blocked" or line == "scaffold stalled":
		return "cannot_deploy_here"
	if line.begins_with("raid complete") or line == "objective complete":
		return "mission_accomplished"
	if line == "objective failed" or line == "raid stalled":
		return "mission_failed"
	return ""

static func announce_line(host: Node, faction: String, text: String) -> void:
	announce_key(host, faction, alert_key(text))

static func announce_key(host: Node, faction: String, key: String) -> void:
	if host == null or key == "":
		return
	var id: String = faction
	if id != "gtfc" and id != "nmrf" and id != "mvd":
		id = "gtfc"
	var now: int = Time.get_ticks_msec()
	var stamp: int = int(_said.get(key, 0))
	if now - stamp < 1600:
		return
	_said[key] = now
	_buses()
	var player: AudioStreamPlayer = _ensure(host, "Announcer")
	player.bus = "Radio"
	player.volume_db = -2.0
	_assign(player, "announcer/%s/%s.ogg" % [id, key], false)

static func tick(host: Node) -> void:
	if host == null or _queue.is_empty():
		return
	var sting: AudioStreamPlayer = host.get_node_or_null("StingMusic") as AudioStreamPlayer
	if sting != null and sting.playing:
		return
	var player: AudioStreamPlayer = host.get_node_or_null(_player_name) as AudioStreamPlayer
	if player == null or bool(player.get_meta("fetching", false)) or player.playing:
		_show_title(host)
		return
	if not bool(player.get_meta("started", false)):
		return
	_at = (_at + 1) % _queue.size()
	_play_current(host)

static func clip_for(unit_id: String, event: String) -> AudioStream:
	if unit_id == "":
		return null
	var file_event: String = event
	if event == "hurt":
		file_event = "under_attack"
	if file_event != "select" and file_event != "move" and file_event != "attack" and file_event != "ability" and file_event != "under_attack":
		return null
	var found: PackedStringArray = _variants(unit_id, file_event)
	if found.is_empty():
		return null
	var which: int = absi(("%s:%s" % [unit_id, event]).hash()) % found.size()
	return _stream(found[which])

static func page_base() -> String:
	return _page_base()

static func remember(rel: String) -> void:
	if not rel.ends_with(".ogg") or rel.contains("..") or rel.begins_with("/"):
		return
	_catalog[rel] = true

static func prefetch(owner: Node, rel: String) -> void:
	if owner == null or not OS.has_feature("web") or _cache.has(rel) or _inflight.has(rel):
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

static func _begin(host: Node, node_name: String, rels: PackedStringArray) -> void:
	for other: String in ["MenuMusic", "FactionMusic"]:
		if other == node_name:
			continue
		var other_player: AudioStreamPlayer = host.get_node_or_null(other) as AudioStreamPlayer
		if other_player != null:
			other_player.stop()
			other_player.set_meta("started", false)
	_queue = rels
	_at = 0
	_player_name = node_name
	_play_current(host)

static func _play_current(host: Node) -> void:
	if host == null or _queue.is_empty():
		return
	var rel: String = _queue[_at]
	now_title = _title_of(rel)
	var player: AudioStreamPlayer = _ensure(host, _player_name)
	player.bus = "Music"
	_assign(player, rel, false)
	_show_title(host)
	var nxt: String = _queue[(_at + 1) % _queue.size()]
	if is_lazy(nxt):
		prefetch(host, nxt)

static func _show_title(host: Node) -> void:
	if host == null:
		return
	var label: Label = host.find_child("NowPlaying", true, false) as Label
	if label != null:
		label.text = now_title

static func _rels_for(list_id: String) -> PackedStringArray:
	var shared: PackedStringArray = PackedStringArray([
		"music/user/poison.ogg",
		"music/user/time.ogg",
	])
	if list_id == "shared":
		return shared
	var own: PackedStringArray = PackedStringArray()
	match list_id:
		"menu":
			own = PackedStringArray([
				"music/menu.ogg",
				"music/user/changes.ogg",
				"music/user/not-needed-anymore.ogg",
			])
		"gtfc":
			own = PackedStringArray([
				"music/gtfc.ogg",
				"music/user/yangonite.ogg",
				"music/user/ready-to-rage-against-the-abnormalities.ogg",
			])
		"nmrf":
			own = PackedStringArray([
				"music/nmrf.ogg",
				"music/user/supayarlat.ogg",
				"music/user/past-cracks.ogg",
			])
		"mvd":
			own = PackedStringArray([
				"music/mvd.ogg",
				"music/user/machinesfuture.ogg",
				"music/user/humanfuture.ogg",
			])
		"black_market":
			own = PackedStringArray([
				"music/black_market.ogg",
				"music/user/night.ogg",
				"music/user/love-drunk.ogg",
			])
		_:
			own = PackedStringArray(["music/gtfc.ogg"])
	if list_id == "menu":
		return own
	for rel: String in shared:
		own.append(rel)
	return own

static func _title_of(rel: String) -> String:
	match rel:
		"music/menu.ogg":
			return "Menu"
		"music/gtfc.ogg":
			return "GTFC"
		"music/nmrf.ogg":
			return "NMRF"
		"music/mvd.ogg":
			return "MVD"
		"music/black_market.ogg":
			return "Black Market"
		"music/user/changes.ogg":
			return "Changes"
		"music/user/not-needed-anymore.ogg":
			return "Not Needed Anymore"
		"music/user/yangonite.ogg":
			return "Yangonite"
		"music/user/ready-to-rage-against-the-abnormalities.ogg":
			return "Ready To Rage Against The Abnormalities"
		"music/user/supayarlat.ogg":
			return "Supayarlat"
		"music/user/past-cracks.ogg":
			return "Past Cracks"
		"music/user/machinesfuture.ogg":
			return "Machinesfuture"
		"music/user/humanfuture.ogg":
			return "Humanfuture"
		"music/user/night.ogg":
			return "Night"
		"music/user/love-drunk.ogg":
			return "Love Drunk"
		"music/user/poison.ogg":
			return "Poison"
		"music/user/time.ogg":
			return "Time"
		_:
			return ""

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
	player.set_meta("started", false)
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
	player.set_meta("started", true)
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
	if _cache.has(rel):
		var cached: AudioStream = _cache[rel] as AudioStream
		if cached != null:
			return cached
	var bytes: PackedByteArray = _read_local(rel)
	var stream: AudioStream = _decode(bytes)
	if stream != null:
		_cache[rel] = stream
	return stream

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
	if _cache.has(rel) and _cache[rel] != null:
		return true
	if _catalog.has(rel):
		return true
	return _local_exists(rel)

static func _local_exists(rel: String) -> bool:
	if not _accepted(rel):
		return false
	var packed: String = "res://audio/%s" % rel
	if FileAccess.file_exists(packed):
		return true
	var roots: PackedStringArray = _roots()
	for root: String in roots:
		if FileAccess.file_exists(root.path_join(rel)):
			return true
	return false

static func _accepted(rel: String) -> bool:
	return rel.ends_with(".ogg") and not rel.contains("..") and not rel.begins_with("/") and not rel.contains("\\")

static func _roots() -> PackedStringArray:
	var roots: PackedStringArray = PackedStringArray()
	roots.append(ProjectSettings.globalize_path("res://").path_join("build/web/audio"))
	roots.append(OS.get_executable_path().get_base_dir().path_join("audio"))
	return roots

static func _decode(bytes: PackedByteArray) -> AudioStream:
	if bytes.is_empty():
		return null
	return AudioStreamOggVorbis.load_from_buffer(bytes)

static func _read_local(rel: String) -> PackedByteArray:
	if not _accepted(rel):
		return PackedByteArray()
	var packed: String = "res://audio/%s" % rel
	if FileAccess.file_exists(packed):
		return FileAccess.get_file_as_bytes(packed)
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
	http.timeout = 120.0
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
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
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
