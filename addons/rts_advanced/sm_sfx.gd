class_name SMSfx
extends RefCounted
## Plays one cue at a time on the match UI. A view may supply volume and bark clips.

var player: AudioStreamPlayer
var voice: AudioStreamPlayer
var cue_level: Callable
var clip_for: Callable
var cue_for: Callable

func mount(parent: Node) -> void:
	player = AudioStreamPlayer.new()
	player.name = "CuePlayer"
	player.volume_db = _volume(-8.0)
	parent.add_child(player)
	voice = AudioStreamPlayer.new()
	voice.name = "BarkPlayer"
	voice.volume_db = _volume(-6.0)
	parent.add_child(voice)

func apply_levels() -> void:
	if player != null:
		player.volume_db = _volume(-8.0)
	if voice != null:
		voice.volume_db = _volume(-6.0)

func play(kind: String) -> void:
	if player == null:
		return
	player.volume_db = _volume(-8.0)
	var clip: AudioStream = null
	if cue_for.is_valid():
		var got: Variant = cue_for.call(kind)
		if got is AudioStream:
			clip = got
	player.stream = clip if clip != null else SMTone.cue(kind)
	player.pitch_scale = 0.97 + randf() * 0.06
	player.play()

func bark(pitch: float, unit_id: String = "", event: String = "") -> void:
	if voice == null:
		return
	voice.volume_db = _volume(-6.0)
	voice.pitch_scale = maxf(0.5, pitch)
	var clip: AudioStream = null
	if clip_for.is_valid() and unit_id != "":
		var got: Variant = clip_for.call(unit_id, event)
		if got is AudioStream:
			clip = got
	voice.stream = clip if clip != null else SMTone.cue("bark")
	voice.play()

func _volume(base: float) -> float:
	if cue_level.is_valid():
		return float(cue_level.call(base))
	return base
