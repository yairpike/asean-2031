class_name SMProtocols
extends RefCounted
## Three branches. Each blueprint power is named, has a visible effect, and
## cannot be cast again until its rule allows it. The first power of a branch
## is what cast(branch) still fires.

const COOL_POWER: StringName = &"point_defense_drones"
const COOL_TIME: float = 8.0

var credits_bonus: int = 0
var damage_mult: float = 1.0
var cryo_applied: bool = false
var grinder_speed: float = 1.0
var night_shift: bool = false
var swarm_count: int = 0
var defoliation: bool = false
var printed: int = 0
var satellite_lock: bool = false
var napalm: int = 0
var discharged: bool = false
var kamikaze: int = 0
var point_defense: int = 0
var ambush: bool = false
var pirate_haul: int = 0
var balloons: int = 0
var assembled: bool = false
var tech_rank: int = 0
var bomber: bool = false
var trade_open: bool = false
var recon: bool = false
var spoofed: bool = false
var bomb_armed: bool = false
var thermal: bool = false
var cryo_wave: bool = false
var cast_count: Dictionary[StringName, int] = {}
var cool_left: Dictionary[StringName, float] = {}
var marks: Dictionary[StringName, String] = {}

func power_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.append_array(_logistics())
	ids.append_array(_arsenal())
	ids.append_array(_oracle())
	return ids

func display_name(id: StringName) -> String:
	if id == &"cash_bounty":
		return "Cash Bounty"
	if id == &"grinder_treads":
		return "Grinder Treads"
	if id == &"mogok_night_shift":
		return "Mogok Night-Shift Overdrive"
	if id == &"thai_border_mass_print":
		return "Thai Border Mass Print"
	if id == &"robotic_assembly":
		return "Robotic Assembly"
	if id == &"free_trade":
		return "Free Trade"
	if id == &"high_technology":
		return "High Technology"
	if id == &"advanced_rocket_pods":
		return "Advanced Rocket Pods"
	if id == &"magnetic_satellite":
		return "Magnetic Satellite"
	if id == &"su30_napalm":
		return "Su-30 napalm run"
	if id == &"honorable_discharge":
		return "Honorable Discharge"
	if id == &"kamikaze_drone_squadron":
		return "Kamikaze Drone Squadron"
	if id == &"point_defense_drones":
		return "Point-Defense Drones"
	if id == &"drone_swarm_23":
		return "23-Drone Swarm"
	if id == &"toxic_defoliation":
		return "Toxic Defoliation"
	if id == &"straits_pirate_raid":
		return "Straits Pirate Raid"
	if id == &"balloon_bomb_barrage":
		return "Balloon Bomb Barrage"
	if id == &"century_carpet_bomber":
		return "Century Carpet Bomber"
	if id == &"cryoshot":
		return "Cryoshot"
	if id == &"cryogeddon":
		return "Cryogeddon"
	if id == &"satellite_recon":
		return "Satellite Recon"
	if id == &"gps_spoofing":
		return "GPS Spoofing"
	if id == &"orlan_thermal_scan":
		return "Orlan Thermal Scan"
	if id == &"time_bomb":
		return "Time Bomb"
	if id == &"sleeper_ambush":
		return "Sleeper Ambush"
	return ""

func blurb(id: StringName) -> String:
	var name: String = display_name(id)
	if name == "":
		return ""
	return "%s. %s" % [name, _hint(id)]

func _hint(id: StringName) -> String:
	if id == &"cash_bounty":
		return "Pays 250 credits once."
	if id == &"grinder_treads":
		return "Speeds the company up. One cast."
	if id == &"mogok_night_shift":
		return "Mines rubies. One cast."
	if id == &"thai_border_mass_print":
		return "Prints a batch of units. One cast."
	if id == &"robotic_assembly":
		return "Opens robotic assembly. One cast."
	if id == &"free_trade":
		return "Opens trade income. One cast."
	if id == &"high_technology":
		return "Raises the tech rank. One cast."
	if id == &"advanced_rocket_pods":
		return "Raises weapon damage. One cast."
	if id == &"magnetic_satellite":
		return "Locks a satellite on the target. One cast."
	if id == &"su30_napalm":
		return "A napalm run. It does not finish the mission."
	if id == &"honorable_discharge":
		return "Discharges a held unit. One cast."
	if id == &"kamikaze_drone_squadron":
		return "Sends a drone squadron. One cast."
	if id == &"point_defense_drones":
		return "Raises a shield. It can be cast again after it cools."
	if id == &"drone_swarm_23":
		return "Chips the towers. It does not finish the mission."
	if id == &"toxic_defoliation":
		return "Freezes the tank column. It does not finish the mission."
	if id == &"straits_pirate_raid":
		return "A pirate haul. One cast."
	if id == &"balloon_bomb_barrage":
		return "A balloon barrage. One cast."
	if id == &"century_carpet_bomber":
		return "A carpet run. One cast."
	if id == &"cryoshot":
		return "Freezes one target. One cast."
	if id == &"cryogeddon":
		return "Freezes the trimarans for a while. It does not finish the mission."
	if id == &"satellite_recon":
		return "Reveals the field. One cast."
	if id == &"gps_spoofing":
		return "Spoofs GPS guidance. One cast."
	if id == &"orlan_thermal_scan":
		return "A thermal scan. One cast."
	if id == &"time_bomb":
		return "Arms a bomb. One cast."
	if id == &"sleeper_ambush":
		return "Sets an ambush. One cast."
	return "One cast, then it is spent."

func effect_of(id: StringName) -> String:
	return str(marks.get(id, ""))

func power_name(branch: StringName) -> StringName:
	if branch == &"logistics":
		return &"cash_bounty"
	if branch == &"arsenal":
		return &"advanced_rocket_pods"
	if branch == &"oracle":
		return &"cryoshot"
	return &""

func branches() -> Array[StringName]:
	return [&"logistics", &"arsenal", &"oracle"]

func can_cast(branch: StringName) -> bool:
	var power: StringName = power_name(branch)
	return power != &"" and can_cast_power(power)

func can_cast_power(id: StringName) -> bool:
	if display_name(id) == "":
		return false
	if id == COOL_POWER:
		return float(cool_left.get(id, 0.0)) <= 0.0
	return int(cast_count.get(id, 0)) == 0

func cast(branch: StringName, economy: RTSEconomy, team: int, abilities: SMAbilities, target: int) -> bool:
	var power: StringName = power_name(branch)
	if power == &"":
		return false
	return cast_power(power, economy, team, abilities, target)

func cast_power(id: StringName, economy: RTSEconomy, team: int, abilities: SMAbilities, target: int) -> bool:
	if not can_cast_power(id):
		return false
	_apply(id, economy, team, abilities, target)
	cast_count[id] = int(cast_count.get(id, 0)) + 1
	if id == COOL_POWER:
		cool_left[id] = COOL_TIME
	return true

func cool(delta: float) -> void:
	for id: StringName in cool_left.keys():
		cool_left[id] = maxf(0.0, float(cool_left[id]) - delta)

func mount_panel(layer: CanvasLayer, economy: RTSEconomy, team: int, abilities: SMAbilities, say: Callable) -> ScrollContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Protocols"
	scroll.visible = false
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.clip_contents = true
	scroll.z_index = 8
	scroll.custom_minimum_size = Vector2(320, 120)
	_dock(scroll, 72.0, 100.0, 432.0, 340.0, 0.0, 0.0, 0.0, 0.0)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(grid)
	for id: StringName in power_ids():
		var b: Button = Button.new()
		b.name = "Proto_%s" % str(id)
		b.text = display_name(id)
		b.clip_text = false
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(148, 52)
		b.add_theme_font_size_override("font_size", 12)
		var line: String = blurb(id)
		b.tooltip_text = ""
		b.set_meta("tip", line)
		b.mouse_entered.connect(_show_tip.bind(layer, line))
		b.mouse_exited.connect(_show_tip.bind(layer, ""))
		b.pressed.connect(_press_power.bind(id, economy, team, abilities, say))
		grid.add_child(b)
	layer.add_child(scroll)
	scroll.set_meta("book", self)
	var toggle: Button = Button.new()
	toggle.name = "ProtocolsToggle"
	toggle.text = "⚡"
	toggle.clip_text = true
	toggle.custom_minimum_size = Vector2(56, 56)
	toggle.z_index = 9
	toggle.tooltip_text = ""
	toggle.set_meta("tip", "Protocols (P)")
	toggle.add_theme_font_size_override("font_size", 22)
	var bolt: Font = ThemeDB.fallback_font
	if bolt != null:
		toggle.add_theme_font_override("font", bolt)
	_dock(toggle, 8.0, 36.0, 64.0, 92.0, 0.0, 0.0, 0.0, 0.0)
	toggle.pressed.connect(_toggle_panel.bind(scroll))
	layer.add_child(toggle)
	return scroll

func _toggle_panel(scroll: CanvasItem) -> void:
	scroll.visible = not scroll.visible

func _dock(node: Control, left: float, top: float, right: float, bottom: float, anchor_l: float, anchor_t: float, anchor_r: float, anchor_b: float) -> void:
	node.anchor_left = anchor_l
	node.anchor_top = anchor_t
	node.anchor_right = anchor_r
	node.anchor_bottom = anchor_b
	node.offset_left = left
	node.offset_top = top
	node.offset_right = right
	node.offset_bottom = bottom

func _show_tip(layer: Node, text: String) -> void:
	SMHud.present_tip(layer, text)

func _press_power(id: StringName, economy: RTSEconomy, team: int, abilities: SMAbilities, say: Callable) -> void:
	var target: int = -1
	if abilities != null and abilities.index_of(10) >= 0:
		target = 10
	elif abilities != null and abilities.index_of(2) >= 0:
		target = 2
	var ok: bool = cast_power(id, economy, team, abilities, target)
	if say.is_valid():
		say.call(display_name(id) if ok else "protocol spent")

func _apply(id: StringName, economy: RTSEconomy, team: int, abilities: SMAbilities, target: int) -> void:
	if id == &"cash_bounty":
		economy.earn(team, 250)
		credits_bonus += 250
		marks[id] = "credits +250"
	elif id == &"grinder_treads":
		grinder_speed = 1.4
		marks[id] = "speed 1.4"
	elif id == &"mogok_night_shift":
		night_shift = true
		marks[id] = "mine rubies"
	elif id == &"thai_border_mass_print":
		printed = 8
		marks[id] = "printed 8"
	elif id == &"robotic_assembly":
		assembled = true
		marks[id] = "assembly"
	elif id == &"free_trade":
		trade_open = true
		marks[id] = "trade open"
	elif id == &"high_technology":
		tech_rank = 1
		marks[id] = "tech 1"
	elif id == &"advanced_rocket_pods":
		damage_mult = 1.5
		marks[id] = "damage 1.5"
	elif id == &"magnetic_satellite":
		satellite_lock = true
		marks[id] = "satellite lock"
	elif id == &"su30_napalm":
		napalm = 36
		marks[id] = "napalm 36"
	elif id == &"honorable_discharge":
		discharged = true
		marks[id] = "discharged"
	elif id == &"kamikaze_drone_squadron":
		kamikaze = 6
		marks[id] = "kamikaze 6"
	elif id == &"point_defense_drones":
		point_defense += 1
		marks[id] = "shield %d" % point_defense
	elif id == &"drone_swarm_23":
		swarm_count = 23
		marks[id] = "swarm 23"
	elif id == &"toxic_defoliation":
		defoliation = true
		marks[id] = "defoliation"
	elif id == &"straits_pirate_raid":
		pirate_haul = 120
		marks[id] = "haul 120"
	elif id == &"balloon_bomb_barrage":
		balloons = 9
		marks[id] = "balloons 9"
	elif id == &"century_carpet_bomber":
		bomber = true
		marks[id] = "carpet"
	elif id == &"cryoshot":
		if target >= 0 and abilities != null:
			abilities.apply_status(target, SMAbilities.ST_FROZEN, 5.0)
		cryo_applied = true
		marks[id] = "frozen"
	elif id == &"cryogeddon":
		if target >= 0 and abilities != null:
			abilities.apply_status(target, SMAbilities.ST_FROZEN, 8.0)
		cryo_wave = true
		marks[id] = "cryo wave"
	elif id == &"satellite_recon":
		recon = true
		marks[id] = "recon"
	elif id == &"gps_spoofing":
		spoofed = true
		marks[id] = "spoofed"
	elif id == &"orlan_thermal_scan":
		thermal = true
		marks[id] = "thermal"
	elif id == &"time_bomb":
		bomb_armed = true
		marks[id] = "bomb armed"
	elif id == &"sleeper_ambush":
		ambush = true
		marks[id] = "ambush"

func _logistics() -> Array[StringName]:
	return [&"cash_bounty", &"grinder_treads", &"mogok_night_shift", &"thai_border_mass_print", &"robotic_assembly", &"free_trade", &"high_technology"]

func _arsenal() -> Array[StringName]:
	return [&"advanced_rocket_pods", &"magnetic_satellite", &"su30_napalm", &"honorable_discharge", &"kamikaze_drone_squadron", &"point_defense_drones", &"drone_swarm_23", &"toxic_defoliation", &"straits_pirate_raid", &"balloon_bomb_barrage", &"century_carpet_bomber"]

func _oracle() -> Array[StringName]:
	return [&"cryoshot", &"cryogeddon", &"satellite_recon", &"gps_spoofing", &"orlan_thermal_scan", &"time_bomb", &"sleeper_ambush"]
