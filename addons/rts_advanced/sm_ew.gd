class_name SMEwField
extends RefCounted
## A jammer cuts accuracy of GPS and FPV guidance inside its radius.
## Fiber-optic and frequency-hop links ignore the jammer.

const GPS: int = 0
const FPV: int = 1
const FIBER: int = 2
const HOP: int = 3
const NONE: int = 4

var center: Vector3 = Vector3.ZERO
var radius: float = 1000.0
var penalty: float = 0.4
var active: bool = true

static func guidance_of(name: String) -> int:
	if name == "gps":
		return GPS
	if name == "fpv":
		return FPV
	if name == "fiber":
		return FIBER
	if name == "hop":
		return HOP
	return NONE

func accuracy(pos: Vector3, guidance: int, fiber_active: bool = false, hop_active: bool = false) -> float:
	if not active:
		return 1.0
	if fiber_active or hop_active or guidance == FIBER or guidance == HOP or guidance == NONE:
		return 1.0
	if guidance != GPS and guidance != FPV:
		return 1.0
	if pos.distance_to(center) <= radius:
		return penalty
	return 1.0
