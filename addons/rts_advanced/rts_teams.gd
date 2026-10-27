class_name RTSTeams
extends RefCounted
## Team relations: every pair of teams is ALLY, ENEMY or NEUTRAL (symmetric).
## A team is always allied with itself. Unknown pairs default to ENEMY.

enum Relation { ALLY, ENEMY, NEUTRAL }

var colors: Dictionary[int, Color] = {}
var _rel: Dictionary[Vector2i, Relation] = {}

func add_team(team: int, color: Color) -> void:
	colors[team] = color

func set_relation(a: int, b: int, r: Relation) -> void:
	_rel[_key(a, b)] = r

func relation(a: int, b: int) -> Relation:
	if a == b:
		return Relation.ALLY
	return _rel.get(_key(a, b), Relation.ENEMY)

func are_enemies(a: int, b: int) -> bool:
	return relation(a, b) == Relation.ENEMY

func are_allies(a: int, b: int) -> bool:
	return relation(a, b) == Relation.ALLY

func color_of(team: int) -> Color:
	return colors.get(team, Color.GRAY)

static func _key(a: int, b: int) -> Vector2i:
	return Vector2i(mini(a, b), maxi(a, b))
