extends RefCounted
## Short menu ticks on the SFX bus. Recorded UI files replace the tones when they land.

const Settings = preload("res://game/match_settings.gd")

static var _player: AudioStreamPlayer

static func play(host: Node, kind: String) -> void:
	if host == null:
		return
	_bus()
	if _player == null or not is_instance_valid(_player):
		_player = AudioStreamPlayer.new()
		_player.name = "MenuSfx"
		_player.bus = "SFX"
		host.get_tree().root.add_child(_player)
	_player.bus = "SFX"
	_player.stream = SMTone.cue(kind)
	_player.play()

static func _bus() -> void:
	var idx: int = AudioServer.get_bus_index("SFX")
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, "SFX")
		AudioServer.set_bus_send(idx, "Master")
	Settings.ensure()
	var db: float = -80.0
	if Settings.sfx > 0.001:
		db = linear_to_db(Settings.sfx)
	AudioServer.set_bus_volume_db(idx, db)
