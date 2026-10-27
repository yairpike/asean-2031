class_name SMProtocols
extends RefCounted
## Three branches, one power each. A second cast of the same branch does nothing.

var credits_bonus: int = 0
var damage_mult: float = 1.0
var cryo_applied: bool = false
var cast_count: Dictionary[StringName, int] = {}

func power_name(branch: StringName) -> StringName:
	if branch == &"logistics":
		return &"credit_surge"
	if branch == &"arsenal":
		return &"overcharge"
	if branch == &"oracle":
		return &"cryo_snap"
	return &""

func branches() -> Array[StringName]:
	return [&"logistics", &"arsenal", &"oracle"]

func can_cast(branch: StringName) -> bool:
	return power_name(branch) != &"" and int(cast_count.get(branch, 0)) == 0

func cast(branch: StringName, economy: RTSEconomy, team: int, abilities: SMAbilities, target: int) -> bool:
	if not can_cast(branch):
		return false
	var power: StringName = power_name(branch)
	if power == &"credit_surge":
		economy.earn(team, 250)
		credits_bonus += 250
	elif power == &"overcharge":
		damage_mult = 1.5
	elif power == &"cryo_snap":
		if target >= 0:
			abilities.apply_status(target, SMAbilities.ST_FROZEN, 5.0)
		cryo_applied = true
	else:
		return false
	cast_count[branch] = 1
	return true
