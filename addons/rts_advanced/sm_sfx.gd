class_name SMSfx
extends RefCounted
## Plays one procedural cue at a time on the match UI.

var player: AudioStreamPlayer

func mount(parent: Node) -> void:
	player = AudioStreamPlayer.new()
	player.name = "CuePlayer"
	player.volume_db = -8.0
	parent.add_child(player)

func play(kind: String) -> void:
	if player == null:
		return
	player.stream = SMTone.cue(kind)
	player.play()
