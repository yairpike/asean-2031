class_name RTSResourceNode
extends RefCounted
## A capturable resource point that pays its owner `rate` credits every `interval`
## seconds until `amount` runs out (amount < 0 = infinite). Call advance(delta).

var owner_team: int = -1
var rate: int = 10
var interval: float = 2.0
var amount: int = -1
var position: Vector3 = Vector3.ZERO
var _t: float = 0.0

func _init(pos: Vector3 = Vector3.ZERO, p_rate: int = 10, p_interval: float = 2.0, p_amount: int = -1) -> void:
	position = pos
	rate = p_rate
	interval = p_interval
	amount = p_amount

func depleted() -> bool:
	return amount == 0

## Pays out into `economy`; returns credits paid this call.
func advance(delta: float, economy: RTSEconomy) -> int:
	if owner_team < 0 or depleted() or interval <= 0.0:
		return 0
	_t += delta
	var paid: int = 0
	while _t >= interval and not depleted():
		_t -= interval
		var pay: int = rate if amount < 0 else mini(rate, amount)
		if amount > 0:
			amount -= pay
		paid += pay
	economy.earn(owner_team, paid)
	return paid
