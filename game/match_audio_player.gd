extends Node
## Starts faction music after the match has chosen a side, then a sting at the end.

const Clips = preload("res://game/match_audio.gd")

var _started: bool = false
var _stung: bool = false

func _process(_delta: float) -> void:
	var host: Node = get_parent()
	if host == null:
		return
	if not _started:
		_started = true
		if str(get_meta("mode", "match")) == "menu":
			Clips.play_menu(host)
		else:
			var faction: String = "gtfc"
			var field: SMPointer = host.get("field") as SMPointer
			if field != null:
				faction = field.faction_id
			Clips.play_faction(host, faction)
		return
	if _stung or str(get_meta("mode", "match")) == "menu":
		return
	var ended: bool = false
	var won: bool = false
	var outcome: SMOutcome = host.get("outcome") as SMOutcome
	if outcome != null and outcome.over:
		ended = true
		won = outcome.victory
	var story: SMStory = host.get("story") as SMStory
	if story != null and (story.done or story.lost):
		ended = true
		won = story.done and not story.lost
	if not ended:
		return
	_stung = true
	Clips.play_sting(host, won)
