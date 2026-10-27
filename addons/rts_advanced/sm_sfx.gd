class_name SMSfx
extends RefCounted
## Plays one procedural cue at a time on the match UI.

const Settings = preload("res://game/match_settings.gd")

var player: AudioStreamPlayer
var voice: AudioStreamPlayer

func mount(parent: Node) -> void:
	player = AudioStreamPlayer.new()
	player.name = "CuePlayer"
	player.volume_db = Settings.cue_db(-8.0)
	parent.add_child(player)
	voice = AudioStreamPlayer.new()
	voice.name = "BarkPlayer"
	voice.volume_db = Settings.cue_db(-6.0)
	parent.add_child(voice)

func play(kind: String) -> void:
	if player == null:
		return
	player.volume_db = Settings.cue_db(-8.0)
	player.stream = SMTone.cue(kind)
	player.play()

func bark(pitch: float) -> void:
	if voice == null:
		return
	voice.volume_db = Settings.cue_db(-6.0)
	voice.pitch_scale = maxf(0.5, pitch)
	voice.stream = SMTone.cue("bark")
	voice.play()
