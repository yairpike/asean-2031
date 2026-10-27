class_name RTSEconomy
extends RefCounted
## Per-team credits. All spending goes through try_spend() so nothing can go negative.

signal changed(team: int, credits: int)

var _credits: Dictionary[int, int] = {}
var earned_total: Dictionary[int, int] = {}

func credits(team: int) -> int:
	return _credits.get(team, 0)

func set_credits(team: int, amount: int) -> void:
	_credits[team] = maxi(0, amount)
	changed.emit(team, _credits[team])

func earn(team: int, amount: int) -> void:
	if amount <= 0:
		return
	_credits[team] = credits(team) + amount
	earned_total[team] = earned_total.get(team, 0) + amount
	changed.emit(team, _credits[team])

func can_afford(team: int, cost: int) -> bool:
	return credits(team) >= cost

func try_spend(team: int, cost: int) -> bool:
	if cost < 0 or not can_afford(team, cost):
		return false
	_credits[team] = credits(team) - cost
	changed.emit(team, _credits[team])
	return true
