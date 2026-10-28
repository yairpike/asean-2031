extends RefCounted
## LAN co-op for two players. The host runs the skirmish and is authoritative.
## The guest does not simulate. It sends move orders and receives positions.
## This is not lockstep. Solo play leaves the session closed.
## The peer is any MultiplayerPeer. Desktop LAN uses ENet.
## A later browser or WAN build can attach a WebRTCMultiplayerPeer
## after its own signalling server has connected the peer.
## Discovery is a UDP broadcast on beacon_port. The game port stays separate.

static var port: int = 7777
static var beacon_port: int = 7778
static var role: String = ""
static var started: bool = false
static var map_path: String = "res://game/phillips_channel.tscn"
static var faction: String = "gtfc"
static var guest_faction: String = "nmrf"
static var peer: MultiplayerPeer
static var inbox: Array[String] = []
static var _hello_sent: bool = false
static var _seen: Array[Dictionary] = []
static var _beacon: PacketPeerUDP
static var _hear: PacketPeerUDP
static var _beacon_at: int = 0

static func show_controls() -> bool:
	return not OS.has_feature("web")

static func lan_note(web: bool) -> String:
	if web:
		return "LAN play needs the desktop build."
	return "Host a skirmish on this LAN, or join one. The guest commands the host's company."

static func active_host() -> bool:
	return role == "host" and started and peer != null

static func open_host() -> Error:
	if not show_controls():
		return ERR_UNAVAILABLE
	close()
	role = "host"
	started = false
	var enet: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = enet.create_server(port)
	if err != OK:
		role = ""
		enet.close()
		return err
	peer = enet
	_arm_beacon()
	return OK

static func open_client(address: String) -> Error:
	if not show_controls():
		return ERR_UNAVAILABLE
	close()
	role = "client"
	started = false
	var dest: String = address.strip_edges()
	if dest == "":
		dest = "127.0.0.1"
	var enet: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = enet.create_client(dest, port)
	if err != OK:
		role = ""
		enet.close()
		return err
	peer = enet
	return OK

static func attach_peer(next: MultiplayerPeer, as_host: bool) -> Error:
	if next == null:
		return ERR_INVALID_PARAMETER
	close()
	peer = next
	role = "host" if as_host else "client"
	started = false
	return OK

static func close() -> void:
	if peer != null:
		peer.close()
	peer = null
	role = ""
	started = false
	inbox.clear()
	_hello_sent = false
	_stop_beacon()
	hush_listen()

static func pump() -> void:
	_send_beacon()
	if peer == null:
		return
	peer.poll()
	while peer.get_available_packet_count() > 0:
		inbox.append(peer.get_packet().get_string_from_utf8())
	if role == "client" and not _hello_sent and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		send({"k": "hello", "faction": faction})
		_hello_sent = true

static func listen() -> Error:
	if not show_controls():
		return ERR_UNAVAILABLE
	if _hear != null:
		return OK
	var udp: PacketPeerUDP = PacketPeerUDP.new()
	udp.set_broadcast_enabled(true)
	var err: Error = udp.bind(beacon_port)
	if err != OK:
		return err
	_hear = udp
	return OK

static func gather() -> void:
	if _hear == null:
		return
	while _hear.get_available_packet_count() > 0:
		var raw: PackedByteArray = _hear.get_packet()
		var ip: String = _hear.get_packet_ip()
		note_beacon(ip, raw)

static func hush_listen() -> void:
	if _hear != null:
		_hear.close()
	_hear = null

static func note_beacon(ip: String, raw: PackedByteArray) -> void:
	var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var row: Dictionary = parsed
	if str(row.get("k", "")) != "here":
		return
	var host_ip: String = ip
	if host_ip.begins_with("::ffff:"):
		host_ip = host_ip.substr(7)
	if host_ip == "":
		return
	var game_port: int = int(row.get("port", port))
	var label: String = _map_label(str(row.get("map", "")))
	var fresh: Dictionary = {
		"ip": host_ip,
		"port": game_port,
		"label": label,
		"at": Time.get_ticks_msec(),
	}
	for i: int in _seen.size():
		if str(_seen[i].get("ip", "")) == host_ip:
			_seen[i] = fresh
			return
	_seen.append(fresh)

static func forget_hosts() -> void:
	_seen.clear()

static func hosts() -> PackedStringArray:
	var now: int = Time.get_ticks_msec()
	var keep: Array[Dictionary] = []
	var out: PackedStringArray = PackedStringArray()
	for row: Dictionary in _seen:
		if now - int(row.get("at", 0)) > 4000:
			continue
		keep.append(row)
		out.append("%s:%d  %s" % [str(row.get("ip", "")), int(row.get("port", 0)), str(row.get("label", ""))])
	_seen = keep
	return out

static func host_address(index: int) -> String:
	if index < 0 or index >= _seen.size():
		return ""
	return str(_seen[index].get("ip", ""))

static func loopback_beacon(listen_port: int) -> bool:
	var recv: PacketPeerUDP = PacketPeerUDP.new()
	if recv.bind(listen_port) != OK:
		return false
	var send: PacketPeerUDP = PacketPeerUDP.new()
	if send.bind(listen_port + 1) != OK:
		recv.close()
		return false
	send.set_dest_address("127.0.0.1", listen_port)
	var body: String = JSON.stringify({"k": "here", "port": port, "map": map_path, "name": "ASEAN 2031"})
	send.put_packet(body.to_utf8_buffer())
	var ok: bool = false
	for _i: int in 20:
		if recv.get_available_packet_count() > 0:
			var raw: PackedByteArray = recv.get_packet()
			var ip: String = recv.get_packet_ip()
			note_beacon(ip, raw)
			ok = true
			break
		OS.delay_msec(10)
	send.close()
	recv.close()
	return ok

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
	if not show_controls():
		return false
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

static func _map_label(path: String) -> String:
	var base: String = path.get_file().get_basename()
	if base == "":
		return "skirmish"
	return base.replace("_", " ")

static func _arm_beacon() -> void:
	_stop_beacon()
	if not show_controls():
		return
	var udp: PacketPeerUDP = PacketPeerUDP.new()
	udp.set_broadcast_enabled(true)
	if udp.bind(0) != OK:
		return
	if udp.set_dest_address("255.255.255.255", beacon_port) != OK:
		udp.close()
		return
	_beacon = udp
	_beacon_at = 0

static func _stop_beacon() -> void:
	if _beacon != null:
		_beacon.close()
	_beacon = null

static func _send_beacon() -> void:
	if role != "host" or _beacon == null:
		return
	var now: int = Time.get_ticks_msec()
	if _beacon_at != 0 and now - _beacon_at < 1000:
		return
	_beacon_at = now
	var body: String = JSON.stringify({
		"k": "here",
		"port": port,
		"map": map_path,
		"name": "ASEAN 2031",
	})
	_beacon.put_packet(body.to_utf8_buffer())
