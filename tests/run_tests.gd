extends SceneTree
## Lite strict headless suite: tools/run_tests.sh. Exit 0 = PASS (RESULT: PASS).
## Subset of the Pro suite for the core systems, plus Lite-only checks.

const Harness = preload("res://tests/harness.gd")
var H: Harness

func check(cond: bool, msg: String) -> void:
	H.check(cond, msg)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	H = Harness.new()
	if Harness.selftest_mode() == "crash":
		await H.section("harness_crash_selftest", H.crash_selftest)
		quit(H.finish())
		return
	if Harness.selftest_mode() == "exit":
		quit(0)
		return
	await H.section("test_teams", test_teams)
	await H.section("test_economy", test_economy)
	await H.section("test_resource_nodes", test_resource_nodes)
	await H.section("test_formation", test_formation)
	await H.section("test_grid_nav", test_grid_nav)
	await H.section("test_unit", test_unit)
	await H.section("test_selection", test_selection)
	await H.section("test_selection_box", test_selection_box)
	await H.section("test_orders", test_orders)
	await H.section("test_production", test_production)
	await H.section("test_camera", test_camera)
	await H.section("test_bindings", test_bindings)
	await H.section("test_localization", test_localization)
	await H.section("test_demo", test_demo)
	await H.section("test_separation", test_separation)
	await H.section("test_lite_scope", test_lite_scope)
	await H.section("test_scrub", test_scrub)
	quit(H.finish())

func _unit(team: int, at: Vector3, t: StringName = &"unit") -> RTSUnit:
	var u: RTSUnit = RTSUnit.new()
	u.team = team
	u.unit_type = t
	u.position = at
	root.add_child(u)
	return u

## Top-down projection for selection tests: screen = world XZ * 10.
func _proj(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z) * 10.0

func test_teams() -> void:
	var t: RTSTeams = RTSTeams.new()
	t.add_team(0, Color.BLUE)
	check(t.are_allies(3, 3), "a team is allied with itself")
	check(t.are_enemies(0, 1), "unknown pair defaults to enemy")
	t.set_relation(1, 0, RTSTeams.Relation.ALLY)
	check(t.are_allies(0, 1) and t.are_allies(1, 0), "relations are symmetric")
	t.set_relation(0, 2, RTSTeams.Relation.NEUTRAL)
	check(not t.are_enemies(0, 2) and not t.are_allies(0, 2), "neutral is neither")
	check(t.color_of(0) == Color.BLUE and t.color_of(9) == Color.GRAY, "team colours with fallback")

func test_economy() -> void:
	var e: RTSEconomy = RTSEconomy.new()
	check(e.credits(0) == 0, "starts empty")
	e.earn(0, 100)
	e.earn(0, -5)
	check(e.credits(0) == 100 and e.earned_total[0] == 100, "earn ignores negatives, tracks total")
	check(e.try_spend(0, 60) and e.credits(0) == 40, "spend")
	check(not e.try_spend(0, 41) and e.credits(0) == 40, "cannot overspend")
	check(not e.try_spend(0, -10), "negative cost refused")
	e.set_credits(1, -50)
	check(e.credits(1) == 0, "set_credits clamps at zero")

func test_resource_nodes() -> void:
	var e: RTSEconomy = RTSEconomy.new()
	var r: RTSResourceNode = RTSResourceNode.new(Vector3.ZERO, 10, 2.0, 25)
	check(r.advance(5.0, e) == 0, "unowned node pays nothing")
	r.owner_team = 1
	check(r.advance(4.0, e) == 20 and e.credits(1) == 20, "two intervals pay 2x rate")
	check(r.advance(1.0, e) == 0, "partial interval pays nothing yet")
	check(r.advance(9.0, e) == 5 and r.depleted(), "last payout capped by remaining amount")
	check(r.advance(10.0, e) == 0 and e.credits(1) == 25, "depleted node stops")
	var inf: RTSResourceNode = RTSResourceNode.new(Vector3.ZERO, 3, 1.0, -1)
	inf.owner_team = 0
	check(inf.advance(100.0, e) == 300 and not inf.depleted(), "infinite node")

func test_formation() -> void:
	var s: Array[Vector3] = RTSFormation.box(Vector3(0, 0, 10), Vector3.ZERO, 9, 2.0)
	check(s.size() == 9, "box makes one slot per unit")
	var c: Vector3 = Vector3.ZERO
	for p: Vector3 in s:
		c += p
	check((c / 9.0).length() < 0.01, "box is centred on the target")
	var unique: Dictionary[Vector3, bool] = {}
	var min_d: float = INF
	for i: int in s.size():
		unique[s[i].snapped(Vector3.ONE * 0.01)] = true
		for j: int in range(i + 1, s.size()):
			min_d = minf(min_d, s[i].distance_to(s[j]))
	check(unique.size() == 9 and min_d >= 1.99, "slots distinct and >= spacing apart")
	var l: Array[Vector3] = RTSFormation.line(Vector3(0, 0, 10), Vector3.ZERO, 4, 2.0)
	check(is_equal_approx(l[0].z, 0.0) and is_equal_approx(l[3].z, 0.0) and is_equal_approx(absf(l[0].x - l[3].x), 6.0), "line is perpendicular to travel")
	check(RTSFormation.box(Vector3.ZERO, Vector3.ZERO, 0).is_empty(), "zero units, no slots")
	var pos: Array[Vector3] = [Vector3(10, 0, 0), Vector3(-10, 0, 0)]
	var slots: Array[Vector3] = [Vector3(-9, 0, 0), Vector3(9, 0, 0)]
	var a: Array[int] = RTSFormation.assign(pos, slots)
	check(a[0] == 1 and a[1] == 0, "assignment pairs nearest slots (no crossing)")

func test_grid_nav() -> void:
	var n: RTSGridNav = RTSGridNav.new(10, 10, 2.0, Vector3.ZERO)
	check(n.cell_at(Vector3(3.9, 0, 0.1)) == Vector2i(1, 0) and n.cell_center(Vector2i(1, 0)) == Vector3(3, 0, 1), "cell <-> world")
	var p: PackedVector3Array = n.find_path(Vector3(1, 0, 1), Vector3(17, 0, 1))
	check(p.size() == 8 and p[p.size() - 1].is_equal_approx(Vector3(17, 0, 1)), "straight path ends at the exact target")
	n.block_rect(Rect2i(4, 0, 1, 9))
	check(n.is_blocked(Vector2i(4, 3)) and not n.is_blocked(Vector2i(4, 9)), "wall blocked, gap open")
	p = n.find_path(Vector3(1, 0, 1), Vector3(17, 0, 1))
	var through_gap: bool = false
	var hits_wall: bool = false
	for q: Vector3 in p:
		if n.cell_at(q) == Vector2i(4, 9): through_gap = true
		if n.is_blocked(n.cell_at(q)): hits_wall = true
	check(not p.is_empty() and through_gap and not hits_wall, "detours through the gap, never through the wall")
	n.set_blocked(Vector2i(4, 9))
	check(n.find_path(Vector3(1, 0, 1), Vector3(17, 0, 1)).is_empty(), "sealed wall = no path")
	check(n.nearest_open(Vector2i(4, 4)) != Vector2i(4, 4) and not n.is_blocked(n.nearest_open(Vector2i(4, 4))), "nearest open cell")
	check(n.is_blocked(Vector2i(-1, 0)), "out of bounds counts as blocked")

func test_unit() -> void:
	var u: RTSUnit = _unit(0, Vector3.ZERO)
	await process_frame
	check(u.hp == 100.0 and u.is_alive(), "spawns at max hp")
	u.speed = 5.0
	u.set_path(PackedVector3Array([Vector3(10, 0, 0)]))
	var arrived: Array[bool] = [false]
	u.arrived.connect(func(_x: RTSUnit) -> void: arrived[0] = true)
	u.advance(1.0)
	check(u.position.is_equal_approx(Vector3(5, 0, 0)) and u.is_moving(), "moves speed*delta")
	u.advance(5.0)
	check(u.position.is_equal_approx(Vector3(10, 0, 0)) and not u.is_moving() and arrived[0], "stops exactly at the end, emits arrived")
	var e: RTSUnit = _unit(1, Vector3(14, 0, 0))
	await process_frame
	u.attack_target = e
	u.attack_range = 6.0
	u.attack_damage = 30.0
	u.advance(0.1)
	check(e.hp == 70.0, "attacks a target in range")
	u.advance(0.1)
	check(e.hp == 70.0, "respects attack interval")
	e.position = Vector3(30, 0, 0)
	u.advance(1.0)
	check(u.position.x > 10.0, "chases a target that moved away")
	var dead: Array[bool] = [false]
	e.died.connect(func(_x: RTSUnit) -> void: dead[0] = true)
	e.take_damage(500.0)
	check(not e.is_alive() and e.hp == 0.0 and dead[0], "dies once at 0 hp")
	u.advance(0.1)
	check(u.attack_target == null, "drops dead targets")
	u.free()
	e.free()

func test_selection() -> void:
	var a: RTSUnit = _unit(0, Vector3(1, 0, 1), &"tank")
	var b: RTSUnit = _unit(0, Vector3(2, 0, 2), &"scout")
	var c: RTSUnit = _unit(0, Vector3(20, 0, 20), &"tank")
	var foe: RTSUnit = _unit(1, Vector3(1.5, 0, 1.5))
	await process_frame
	var all: Array = [a, b, c, foe]
	var s: RTSSelection = RTSSelection.new()
	check(s.preview_count(Rect2(0, 0, 4, 4), all, _proj) == 0, "tiny drag = no box count")
	check(s.preview_count(Rect2(30, 30, -30, -30), all, _proj) == 2, "live count, reversed drag, own team only")
	check(s.select_box(Rect2(0, 0, 30, 30), all, _proj) == 2 and a.selected and not foe.selected, "box selects own units")
	s.select_box(Rect2(190, 190, 20, 20), all, _proj, true)
	check(s.count() == 3, "shift-add")
	s.select_at(Vector2(10, 10), all, _proj, false, true)
	check(s.count() == 2 and not a.selected, "ctrl-click toggles off")
	s.select_at(Vector2(200, 200), all, _proj)
	check(s.count() == 1 and s.units[0] == c, "plain click replaces")
	s.select_box(Rect2(0, 0, 300, 300), all, _proj)
	var tc: Dictionary[StringName, int] = s.type_counts()
	check(tc[&"tank"] == 2 and tc[&"scout"] == 1, "type counts for the panel")
	s.save_group(1)
	s.clear()
	check(s.count() == 0 and not b.selected, "clear")
	b.take_damage(1000.0)
	check(s.recall_group(1) == 2, "recall group skips dead units")
	for u: RTSUnit in [a, b, c, foe]:
		u.free()

func test_selection_box() -> void:
	var sb: RTSSelectionBox = RTSSelectionBox.new()
	sb.count_provider = func(_r: Rect2) -> int: return 3
	root.add_child(sb)
	await process_frame
	sb.begin(Vector2(100, 100))
	sb.update_drag(Vector2(104, 102))
	sb.refresh()
	check(not sb.is_box() and not sb.tag.visible, "small drag shows nothing")
	sb.update_drag(Vector2(40, 20))
	sb.refresh()
	check(sb.is_box() and sb.rect() == Rect2(40, 20, 60, 80), "rect normalised for any drag direction")
	check(sb.tag.visible and sb.tag.text == "3 units", "live count tag (localized)")
	sb.count_provider = func(_r: Rect2) -> int: return 1
	sb.refresh()
	check(sb.tag.text == "1 unit", "singular form")
	sb.end()
	check(not sb.active and not sb.tag.visible, "end hides the box")
	sb.free()

func test_orders() -> void:
	var nav: RTSGridNav = RTSGridNav.new(20, 20, 2.0, Vector3.ZERO)
	nav.block_rect(Rect2i(8, 0, 1, 15))
	var us: Array[RTSUnit] = []
	for i: int in 4:
		us.append(_unit(0, Vector3(2 + i, 0, 2)))
	await process_frame
	var slots: Array[Vector3] = RTSOrders.move(us, Vector3(30, 0, 4), nav)
	check(slots.size() == 4, "every unit gets a slot")
	var ok: bool = true
	for u: RTSUnit in us:
		ok = ok and u.is_moving()
	check(ok, "every unit has a path")
	for i: int in 400:
		for u: RTSUnit in us:
			u.advance(0.05)
	var arrived: int = 0
	for u: RTSUnit in us:
		if not u.is_moving() and u.position.x > 24.0: arrived += 1
		check(not nav.is_blocked(nav.cell_at(u.position)), "unit ended on an open cell")
	check(arrived == 4, "all four crossed the wall via the gap and arrived")
	var teams: RTSTeams = RTSTeams.new()
	var foe: RTSUnit = _unit(1, Vector3(30, 0, 30))
	var friend: RTSUnit = _unit(0, Vector3(30, 0, 34))
	await process_frame
	check(RTSOrders.attack(us, foe, nav, teams) == 4 and us[0].attack_target == foe, "attack order on an enemy")
	check(RTSOrders.attack(us, friend, nav, teams) == 0, "attack on a friendly unit ignored")
	RTSOrders.stop(us)
	check(not us[0].is_moving() and us[0].attack_target == null, "stop clears path and target")
	for u: RTSUnit in us:
		u.free()
	foe.free()
	friend.free()

func test_production() -> void:
	var e: RTSEconomy = RTSEconomy.new()
	e.set_credits(0, 250)
	var cat: Dictionary[StringName, Dictionary] = {&"a": {"cost": 100, "time": 2.0}, &"b": {"cost": 50, "time": 1.0}}
	var q: RTSProductionQueue = RTSProductionQueue.new(0, cat)
	q.max_items = 3
	q.rally = Vector3(5, 0, 5)
	var made: Array[StringName] = []
	q.produced.connect(func(t: StringName, r: Vector3) -> void:
		made.append(t)
		check(r == Vector3(5, 0, 5), "produced at the rally point"))
	check(q.enqueue(&"a", e) and e.credits(0) == 150, "queue pays up front")
	check(q.can_queue(&"zzz", e) == "unknown unit", "unknown type refused")
	q.enqueue(&"b", e)
	q.enqueue(&"b", e)
	check(q.can_queue(&"b", e) == "queue full", "queue limit")
	check(e.credits(0) == 50, "three items paid")
	q.advance(1.0)
	check(is_equal_approx(q.head_ratio(), 0.5) and made.is_empty(), "head progresses")
	check(q.cancel(e) == 50 and e.credits(0) == 100 and q.items.size() == 2, "cancel last refunds in full")
	check(q.advance(2.5) == 2 and made == [&"a", &"b"], "overflow time carries into the next item")
	check(q.items.is_empty() and q.head_ratio() == 0.0, "queue drained")
	e.set_credits(0, 10)
	check(q.can_queue(&"b", e) == "not enough credits", "cannot afford")

func test_camera() -> void:
	var cam: RTSCamera = RTSCamera.new()
	cam.bounds = Rect2(-10, -10, 20, 20)
	root.add_child(cam)
	await process_frame
	cam.distance = 30.0
	cam.focus_on(Vector3(3, 0, 4))
	var fwd: Vector3 = -cam.global_transform.basis.z
	var hit: Vector3 = cam.ground_at(cam.unproject_position(Vector3(3, 0, 4)))
	check(hit.distance_to(Vector3(3, 0, 4)) < 0.05, "ground_at inverts unproject at the focus")
	check(fwd.y < -0.5, "looks down at the ground")
	cam.focus_on(Vector3(100, 0, -100))
	check(cam.focus == Vector3(10, 0, -10), "focus clamped to bounds")
	cam.zoom(50)
	check(cam.distance == cam.zoom_min, "zoom in clamps at minimum")
	var p_near: float = cam.pitch()
	cam.zoom(-50)
	check(cam.distance == cam.zoom_max and cam.pitch() > p_near, "zoom out clamps and steepens pitch")
	cam.focus_on(Vector3.ZERO)
	cam.pan(Vector2(1, 0), 0.1)
	check(cam.focus.x > 0.0 and absf(cam.focus.z) < 0.001, "pan right moves focus +x")
	cam.pan(Vector2(0, 1), 0.1)
	check(cam.focus.z < 0.0, "pan up moves focus forward (-z)")
	cam.free()

func test_bindings() -> void:
	RTSBindings.install()
	check(RTSBindings.key_of(&"rts_produce") == KEY_B, "default key installed")
	check(RTSBindings.label(&"rts_pan_up") == "W", "readable label")
	check(RTSBindings.rebind(&"rts_produce", KEY_X) == &"rts_stop", "rebind onto a used key reports the conflict")
	check(RTSBindings.key_of(&"rts_produce") == KEY_B, "conflicting rebind not applied")
	check(RTSBindings.rebind(&"rts_produce", KEY_G) == &"" and RTSBindings.key_of(&"rts_produce") == KEY_G, "rebind to a free key")
	var path: String = "user://rts_bindings_test.cfg"
	check(RTSBindings.save(path) == OK, "save bindings")
	RTSBindings.reset()
	check(RTSBindings.key_of(&"rts_produce") == KEY_B, "reset to defaults")
	check(RTSBindings.load_from(path) == OK and RTSBindings.key_of(&"rts_produce") == KEY_G, "load restores the rebinding")
	RTSBindings.reset()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = KEY_B
	ev.pressed = true
	check(ev.is_action_pressed(&"rts_produce"), "InputMap matches the bound key")

func test_localization() -> void:
	TranslationServer.set_locale("en")
	check(RTSLoc.t("UI_CREDITS", {"credits": 42}) == "Credits: 42", "translate with params")
	var lab: Label = Label.new()
	root.add_child(lab)
	RTSLoc.bind(lab, "UI_SELECTED", {"count": 3})
	check(lab.text == "Selected: 3", "bind sets text")
	check(RTSLoc.set_language("fr", root) >= 1 and lab.text == "Sélection : 3", "live language switch re-renders bound texts")
	check(RTSLoc.missing_keys("fr").is_empty(), "second locale has every key")
	check(RTSLoc.t("NO_SUCH_KEY") == "NO_SUCH_KEY", "missing key falls back to the key")
	TranslationServer.set_locale("en")
	lab.free()

func test_demo() -> void:
	TranslationServer.set_locale("en")
	var d: Node = (load("res://examples/demo.tscn") as PackedScene).instantiate()
	d.set("auto_tick", false)
	root.add_child(d)
	await process_frame
	await process_frame
	var units: Array[RTSUnit] = d.get("units")
	var econ: RTSEconomy = d.get("economy")
	var sel: RTSSelection = d.get("selection")
	check(units.size() == 10 and econ.credits(0) == 200, "demo spawns 6 + 4 units, 200 credits")
	var proj: Callable = Callable(d, "project")
	var n: int = sel.select_box(Rect2(Vector2(-1e5, -1e5), Vector2(2e5, 2e5)), units, proj)
	check(n == 6, "select-all box picks the 6 player units only")
	check(d.call("produce", &"scout") and econ.credits(0) == 150, "production queue in the demo")
	d.call("command_at", Vector3(4, 0, 22))
	var moving: int = 0
	for u: RTSUnit in sel.units:
		if u.is_moving(): moving += 1
	check(moving == 6, "right-click move gives all six a path (crossing the wall)")
	for i: int in 360:
		d.call("tick", 0.05)
	check(units.size() == 11, "the queued scout was produced")
	var res: Array[RTSResourceNode] = d.get("resources")
	var owned: int = 0
	for r: RTSResourceNode in res:
		if r.owner_team == 0: owned += 1
	check(owned >= 1 and econ.credits(0) > 150, "a resource point was captured and pays income")
	var scout: RTSUnit = d.call("spawn_unit", 0, &"tank", Vector3(17, 0, -17))
	for i: int in 40:
		d.call("tick", 0.05)
	check(int(d.get("shots_fired")) > 0, "units fire automatically in range (shot effects spawned)")
	await process_frame
	var hurt: int = 0
	for u: RTSUnit in units:
		if u.hp < u.max_hp and (u.get_node("HealthBar") as Node3D).visible and (u.get_node("HealthBar") as Node3D).scale.x < 1.0: hurt += 1
	check(hurt > 0, "damaged units show a shrinking health bar")
	var close: int = 0
	for i: int in units.size():
		for j: int in range(i + 1, units.size()):
			var a: RTSUnit = units[i]
			var b: RTSUnit = units[j]
			if not a.is_moving() and not b.is_moving() and Vector2(a.position.x - b.position.x, a.position.z - b.position.z).length() < (a.radius + b.radius) * 0.5: close += 1
	check(close == 0 and scout != null, "idle units do not stack (separation)")
	d.queue_free()
	await process_frame

func test_separation() -> void:
	var a: RTSUnit = _unit(0, Vector3(0, 0, 0))
	var b: RTSUnit = _unit(0, Vector3(0.2, 0, 0))
	var c: RTSUnit = _unit(0, Vector3(0, 0, 0))
	await process_frame
	var us: Array = [a, b, c]
	check(RTSSeparation.apply(us, 0.1) == 3, "three overlapping pairs found")
	for i: int in 60:
		RTSSeparation.apply(us, 0.1)
	var ok: bool = true
	for i: int in 3:
		for j: int in range(i + 1, 3):
			var u: RTSUnit = us[i]
			var v: RTSUnit = us[j]
			ok = ok and Vector2(u.position.x - v.position.x, u.position.z - v.position.z).length() >= u.radius + v.radius - 0.01
	check(ok, "after relaxing, no two units overlap (even exact stacks)")
	var w: RTSUnit = _unit(0, Vector3(10, 0, 0))
	var x: RTSUnit = _unit(0, Vector3(10.1, 0, 0))
	await process_frame
	RTSSeparation.apply([w, x], 1.0, 8.0, func(p: Vector3) -> bool: return p.x >= 10.0)
	check(w.position.x >= 10.0, "pushes never move a unit onto blocked ground")
	check(RTSSeparation.apply([a, w], 0.1) == 0, "far apart = untouched")
	for u: RTSUnit in [a, b, c, w, x]:
		u.free()

func test_lite_scope() -> void:
	print("Lite scope (no Pro systems)")
	var bad: Array[String] = []
	for cls: Dictionary in ProjectSettings.get_global_class_list():
		if str(cls["path"]).contains("/pro/") or str(cls["class"]) in ["RTSTerrain", "RTSCombat", "RTSFog", "RTSAIPlayer", "RTSSaveGame", "RTSMinimap"]:
			bad.append(str(cls["class"]))
	check(bad.is_empty(), "no Pro classes in Lite %s" % [bad])
	check(not DirAccess.dir_exists_absolute("res://assets") and not DirAccess.dir_exists_absolute("res://examples/skirmish"), "no third-party assets, no skirmish")
	check(FileAccess.get_file_as_string("res://LICENSE").contains("Permission is hereby granted, free of charge"), "Lite is MIT")

const TEXT_EXT: PackedStringArray = ["gd", "tscn", "tres", "md", "txt", "csv", "json", "cfg", "godot", "sh", "py", "js", "gdshader", "import"]
const SKIP: PackedStringArray = ["res://.godot", "res://.git", "res://tests/scrub_terms.rot13", "res://tests/last_run.txt"]

static func rot13(s: String) -> String:
	var out: String = ""
	for ch: String in s:
		var c: int = ch.unicode_at(0)
		if c >= 97 and c <= 122: c = (c - 97 + 13) % 26 + 97
		elif c >= 65 and c <= 90: c = (c - 65 + 13) % 26 + 65
		out += String.chr(c)
	return out

func _files(dir: String, out: Array[String]) -> void:
	for s: String in SKIP:
		if dir == s: return
	var d: DirAccess = DirAccess.open(dir)
	if d == null: return
	d.include_hidden = true
	for f: String in d.get_files():
		var p: String = dir.path_join(f)
		if not SKIP.has(p): out.append(p)
	for sub: String in d.get_directories():
		_files(dir.path_join(sub), out)

func test_scrub() -> void:
	var terms: Array[String] = []
	for line: String in (FileAccess.get_file_as_string("res://tests/scrub_terms.rot13") if FileAccess.file_exists("res://tests/scrub_terms.rot13") else "").split("\n"):
		if line.strip_edges() != "" and not line.begins_with("#"):
			terms.append(rot13(line.strip_edges()))
	var shipped: bool = not FileAccess.file_exists("res://tests/scrub_terms.rot13")
	# the term list is a dev-only file (RELEASE_EXCLUDE.txt); a release extraction runs the generic checks only
	check(terms.size() >= 100 or shipped, "scrub list loaded (%d terms)%s" % [terms.size(), " - dev-only list not shipped" if shipped else ""])
	var pat: String = "(?i)\\b(" + "|".join(terms.map(func(t: String) -> String: return t.replace(" ", "[ _-]"))) + ")\\b"
	if terms.is_empty():
		pat = "(?!x)x"
	var rx: RegEx = RegEx.create_from_string(pat)
	# built from code points so this file does not contain the letters it bans
	var nordic: RegEx = RegEx.create_from_string("[" + "".join([0xE5, 0xE4, 0xF6, 0xC5, 0xC4, 0xD6].map(func(c: int) -> String: return String.chr(c))) + "]")
	var milestone: RegEx = RegEx.create_from_string("(?i)(\\bM(1[0-9]|[1-9])\\b|_m[0-9]{1,2}\\b|\\bm[0-9]{1,2}_|\\bM" + str(2) + "[A-Z])")
	var files: Array[String] = []
	_files("res://", files)
	check(files.size() > 20, "scanned %d files" % files.size())
	var hits: Array[String] = []
	for p: String in files:
		var rel: String = p.trim_prefix("res://")
		for r: RegEx in [rx, nordic, milestone]:
			var m: RegExMatch = r.search(rel)
			if m != null: hits.append("name %s: '%s'" % [rel, m.get_string()])
		if TEXT_EXT.has(p.get_extension()):
			var txt: String = FileAccess.get_file_as_string(p)
			for r: RegEx in [rx, nordic, milestone]:
				var mt: RegExMatch = r.search(txt)
				if mt != null: hits.append("text %s: '%s'" % [rel, mt.get_string()])
	check(hits.is_empty(), "no identifying terms, Nordic letters or milestone tags in files or names %s" % [hits.slice(0, 8)])
	# authors / commit messages (only when run inside the kit's own git repo)
	var root_dir: String = ProjectSettings.globalize_path("res://")
	if DirAccess.dir_exists_absolute(root_dir.path_join(".git")):
		var out: Array = []
		var code: int = OS.execute("git", ["-C", root_dir, "log", "--format=%an <%ae> %s"], out)
		var log_txt: String = "\n".join(out)
		var bad: Array[String] = []
		for r: RegEx in [rx, nordic, milestone]:
			for mg: RegExMatch in r.search_all(log_txt):
				bad.append(mg.get_string())
		var authors_ok: bool = true
		for l: String in log_txt.split("\n", false):
			if not l.begins_with("Kit Author <kit-author@example.invalid>"): authors_ok = false
		check(code == 0 and bad.is_empty() and authors_ok, "git history: neutral author only, clean messages %s" % [bad])
	else:
		check(true, "no .git here (release extraction); history check runs in the kit repo")
