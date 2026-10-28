extends RefCounted
## Warheed falls back to Operation Napalm. Neither face uses the system font.

static var _pinned: bool = false

static func pin() -> void:
	if _pinned:
		return
	var warheed: FontFile = load("res://assets/fonts/Warheed.otf") as FontFile
	var napalm: FontFile = load("res://assets/fonts/OperationNapalm-Regular.ttf") as FontFile
	if warheed == null or napalm == null:
		return
	_pinned = true
	warheed.allow_system_fallback = false
	napalm.allow_system_fallback = false
	var faces: Array[Font] = []
	faces.append(napalm)
	warheed.fallbacks = faces
	var system_faces: Array[Font] = []
	if ThemeDB.fallback_font != null:
		system_faces.append(ThemeDB.fallback_font)
	napalm.fallbacks = system_faces
