extends Node
## On the host match: apply guest move orders and stream unit positions.

const Lan = preload("res://game/lan_link.gd")

var _acc: float = 0.0

func _process(delta: float) -> void:
	if not Lan.active_host():
		return
	var host: Node = get_parent()
	if host == null:
		return
	Lan.pump()
	var raw: String = Lan.take()
	while raw != "":
		Lan.apply_line(host, raw)
		raw = Lan.take()
	_acc += delta
	if _acc < 0.1:
		return
	_acc = 0.0
	Lan.broadcast_state(host)
