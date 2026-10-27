class_name SMFront
extends RefCounted
## Faction chosen on the boot screen. The next skirmish plays as this side.

static var faction_id: String = "gtfc"

static func current() -> String:
	if faction_id == "nmrf" or faction_id == "mvd":
		return faction_id
	return "gtfc"

static func display_name() -> String:
	if current() == "nmrf":
		return "NMRF"
	if current() == "mvd":
		return "MVD"
	return "GTFC"

static func kinds() -> Array[StringName]:
	if current() == "nmrf":
		return SMPointer.NMRF_KINDS
	if current() == "mvd":
		return SMPointer.MVD_KINDS
	return SMPointer.GTFC_KINDS

static func train_kind() -> StringName:
	if current() == "nmrf":
		return &"olive_ranger"
	if current() == "mvd":
		return &"cyan_sentry"
	return &"crimson_sapper"

static func banner() -> String:
	if current() == "nmrf":
		return "NMRF  olive / emerald"
	if current() == "mvd":
		return "MVD  charcoal / cyan"
	return "GTFC  crimson / amber"

static func color_line() -> String:
	if current() == "nmrf":
		return "Olive / emerald"
	if current() == "mvd":
		return "Charcoal / cyan"
	return "Crimson / amber"

static func style_line() -> String:
	if current() == "nmrf":
		return "Mobile core"
	if current() == "mvd":
		return "Internal queue"
	return "Scaffold yard"

static func primary() -> Color:
	if current() == "nmrf":
		return Color.html("#5A6824")
	if current() == "mvd":
		return Color.html("#2A2E32")
	return Color.html("#B81E2D")

static func accent() -> Color:
	if current() == "nmrf":
		return Color.html("#1F9E66")
	if current() == "mvd":
		return Color.html("#26BFD1")
	return Color.html("#E0A106")
