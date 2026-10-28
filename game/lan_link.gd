extends RefCounted
## LAN co-op. The host runs the skirmish. The guest sends move orders and
## receives unit positions. Solo play leaves the session closed.

static var port: int = 7777
static var role: String = ""
static var started: bool = false
static var map_path: String = "res://game/phillips_channel.tscn"
static var faction: String = "gtfc"
static var guest_faction: String = "nmrf"
static var peer: ENetMultiplayerPeer
static var inbox: Array[String] = []
static var _hello_sent: bool = false

static func active_host() -> bool:
	return role == "host" and started and peer != null

static func open_host() -> Error:
	close()
	role = "host"
	started = false
	peer = ENetMultiplayerPeer.new()
	return peer.create_server(port)

static func open_client(address: String) -> Error:
	close()
	role = "client"
	started = false
	var dest: String = address.strip_edges()
	if dest == "":
		dest = "127.0.0.1"
	peer = ENetMultiplayerPeer.new()
	return peer.create_client(dest, port)

static func close() -> void:
	if peer != null:
		peer.close()
	peer = null
	role = ""
	started = false
	inbox.clear()
	_hello_sent = false

static func pump() -> void:
	if peer == null:
		return
	peer.poll()
	while peer.get_available_packet_count() > 0:
		inbox.append(peer.get_packet().get_string_from_utf8())
	if role == "client" and not _hello_sent and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		send({"k": "hello", "faction": faction})
		_hello_sent = true

static func take() -> String:
	if inbox.is_empty():
		return ""
	var line: String = inbox[0]
	inbox.remove_at(0)
	return line

static func send(payload: Dictionary) -> void:
	if peer == null:
		return
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	peer.set_target_peer(0 if role == "host" else 1)
	peer.put_packet(JSON.stringify(payload).to_utf8_buffer())

static func send_start(path: String, host_faction: String, guest: String) -> void:
	map_path = path
	faction = host_faction
	guest_faction = guest
	send({"k": "start", "map": path, "faction": host_faction, "guest": guest})

static func apply_move(host: Node, at: Vector3) -> int:
	var field: SMPointer = host.get("field") as SMPointer
	if field == null:
		return 0
	var live: Array[RTSUnit] = []
	for u: RTSUnit in field.units_of(SMPointer.PLAYER):
		if is_instance_valid(u) and u.is_alive() and not bool(u.get_meta("objective", false)):
			live.append(u)
	if live.is_empty():
		return 0
	RTSOrders.move(live, at, field.nav_for_unit(live[0]))
	return live.size()

static func apply_line(host: Node, raw: String) -> int:
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return 0
	var row: Dictionary = parsed
	if str(row.get("k", "")) != "go":
		return 0
	return apply_move(host, Vector3(float(row.get("x", 0.0)), 0.0, float(row.get("z", 0.0))))

static func state_of(host: Node) -> Dictionary:
	var xs: Array = []
	var zs: Array = []
	var hs: Array = []
	var ts: Array = []
	var field: SMPointer = host.get("field") as SMPointer
	if field != null:
		var n: int = 0
		for u: RTSUnit in field.units:
			if n >= 48:
				break
			if not is_instance_valid(u) or not u.is_alive():
				continue
			xs.append(u.global_position.x)
			zs.append(u.global_position.z)
			hs.append(u.hp)
			ts.append(u.team)
			n += 1
	var status: String = ""
	var label: Label = host.find_child("Status", true, false) as Label
	if label != null:
		status = label.text
	return {"k": "state", "x": xs, "z": zs, "h": hs, "t": ts, "s": status}

static func broadcast_state(host: Node) -> void:
	send(state_of(host))

static func probe(listen_port: int) -> bool:
	var server: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	if server.create_server(listen_port) != OK:
		return false
	var client: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	if client.create_client("127.0.0.1", listen_port) != OK:
		server.close()
		return false
	var ok: bool = false
	for _i: int in 25:
		server.poll()
		client.poll()
		if client.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			client.set_target_peer(1)
			client.put_packet("hello".to_utf8_buffer())
			server.poll()
			if server.get_available_packet_count() > 0:
				ok = server.get_packet().get_string_from_utf8() == "hello"
				break
		OS.delay_msec(20)
	client.close()
	server.close()
	return ok
