class_name SMOutcome
extends RefCounted
## Ends a skirmish after both sides have fielded something and one side is wiped out.

var saw_player: bool = false
var saw_enemy: bool = false
var over: bool = false
var victory: bool = false
var host: Node
var panel: Control
var banner: Label
var back: Button
var _cool: Dictionary[int, float] = {}

func mount(p_host: Node, layer: CanvasLayer) -> void:
	host = p_host
	panel = Control.new()
	panel.name = "MatchEnd"
	panel.position = Vector2.ZERO
	panel.size = Vector2(1280, 720)
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 20
	layer.add_child(panel)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.04, 0.78)
	shade.position = Vector2.ZERO
	shade.size = Vector2(1280, 720)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(shade)
	banner = Label.new()
	banner.name = "MatchBanner"
	banner.position = Vector2(0, 260)
	banner.size = Vector2(1280, 72)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 48)
	banner.add_theme_color_override("font_color", Color(0.95, 0.94, 0.9))
	panel.add_child(banner)
	back = Button.new()
	back.name = "BootMenuButton"
	back.text = "Boot menu"
	back.position = Vector2(520, 360)
	back.custom_minimum_size = Vector2(240, 44)
	back.add_theme_font_size_override("font_size", 18)
	back.pressed.connect(_boot)
	panel.add_child(back)

func consider(player_units: int, player_buildings: int, enemy_units: int, enemy_buildings: int) -> void:
	if over:
		return
	var player_alive: bool = player_units > 0 or player_buildings > 0
	var enemy_alive: bool = enemy_units > 0 or enemy_buildings > 0
	if player_alive:
		saw_player = true
	if enemy_alive:
		saw_enemy = true
	if not saw_player or not saw_enemy:
		return
	if not player_alive:
		_finish(false)
	elif not enemy_alive:
		_finish(true)

func tick(field: SMPointer, player_yards: Array[SMBuildYard], enemy_yards: Array[SMBuildYard], delta: float) -> void:
	if over or field == null:
		return
	var player_units: int = field.count_team(SMPointer.PLAYER)
	var enemy_units: int = field.count_team(SMPointer.ENEMY)
	var player_buildings: int = _living(player_yards)
	var enemy_buildings: int = _living(enemy_yards)
	if (player_units > 0 or player_buildings > 0) and (enemy_units > 0 or enemy_buildings > 0):
		saw_player = true
		saw_enemy = true
	elif player_units > 0 or player_buildings > 0:
		saw_player = true
	elif enemy_units > 0 or enemy_buildings > 0:
		saw_enemy = true
	if saw_player and saw_enemy:
		if enemy_units == 0 and player_units > 0:
			_press(field, field.units_of(SMPointer.PLAYER), enemy_yards, delta)
		elif player_units == 0 and enemy_units > 0:
			_press(field, field.units_of(SMPointer.ENEMY), player_yards, delta)
		player_buildings = _living(player_yards)
		enemy_buildings = _living(enemy_yards)
	consider(player_units, player_buildings, enemy_units, enemy_buildings)

func _living(yards: Array[SMBuildYard]) -> int:
	var total: int = 0
	for yard: SMBuildYard in yards:
		if yard != null:
			total += yard.living_count()
	return total

func _press(field: SMPointer, units: Array[RTSUnit], yards: Array[SMBuildYard], delta: float) -> void:
	for u: RTSUnit in units:
		if not is_instance_valid(u) or not u.is_alive():
			continue
		var best_yard: SMBuildYard = null
		var best_id: StringName = &""
		var best_pos: Vector3 = Vector3.ZERO
		var best_d: float = INF
		for yard: SMBuildYard in yards:
			if yard == null:
				continue
			var id: StringName = yard.nearest_living(u.global_position)
			if id == &"":
				continue
			var pos: Vector3 = yard.position_of(id)
			var dist: float = Vector2(u.global_position.x, u.global_position.z).distance_to(Vector2(pos.x, pos.z))
			if dist < best_d:
				best_d = dist
				best_yard = yard
				best_id = id
				best_pos = pos
		if best_yard == null:
			continue
		if best_d <= u.attack_range:
			u.stop()
			if _fire(u, delta):
				best_yard.damage_structure(best_id, u.attack_damage)
				if not best_yard.structure_alive(best_id):
					_hide(best_id)
		elif not u.is_moving():
			var path: PackedVector3Array = PackedVector3Array()
			if field.nav != null:
				path = field.nav.find_path(u.global_position, best_pos)
			if path.is_empty():
				path = PackedVector3Array([best_pos])
			u.set_path(path)

func _fire(u: RTSUnit, delta: float) -> bool:
	var id: int = u.get_instance_id()
	var left: float = 0.0
	if _cool.has(id):
		left = _cool[id]
	if left > 0.0:
		_cool[id] = maxf(0.0, left - delta)
		return false
	_cool[id] = u.attack_interval
	return true

func _hide(id: StringName) -> void:
	if host == null:
		return
	var node_name: String = "Built_%s" % str(id)
	if id == &"enemy_yard":
		node_name = "EnemyYard"
	elif id == &"packer":
		node_name = "PackerCore"
	elif id == &"command_hub":
		node_name = "HubShell"
	var node: Node = host.get_node_or_null(node_name)
	if node is Node3D:
		(node as Node3D).visible = false
	var built: Node = host.get_node_or_null("Built_%s" % str(id))
	if built is Node3D:
		(built as Node3D).visible = false

func _finish(win: bool) -> void:
	if over:
		return
	over = true
	victory = win
	if panel != null:
		panel.visible = true
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if banner != null:
		banner.text = "Victory" if win else "Defeat"
		var ink: Color = Color(0.95, 0.86, 0.45) if win else Color(0.9, 0.32, 0.28)
		banner.add_theme_color_override("font_color", ink)

func _boot() -> void:
	if host == null:
		return
	host.get_tree().change_scene_to_file("res://game/boot.tscn")
