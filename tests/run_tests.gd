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
	await H.section("test_sm_build", test_sm_build)
	await H.section("test_sm_nodes", test_sm_nodes)
	await H.section("test_sm_tech", test_sm_tech)
	await H.section("test_sm_abilities", test_sm_abilities)
	await H.section("test_sm_domain", test_sm_domain)
	await H.section("test_sm_ew", test_sm_ew)
	await H.section("test_sm_catalog", test_sm_catalog)
	await H.section("test_sm_camera_rig", test_sm_camera_rig)
	await H.section("test_sm_greybox", test_sm_greybox)
	await H.section("test_sm_phillips", test_sm_phillips)
	await H.section("test_sm_bots", test_sm_bots)
	await H.section("test_sm_mission", test_sm_mission)
	await H.section("test_sm_sop_ruak", test_sm_sop_ruak)
	await H.section("test_sm_maps", test_sm_maps)
	await H.section("test_sm_factions", test_sm_factions)
	await H.section("test_sm_raider", test_sm_raider)
	await H.section("test_sm_roster", test_sm_roster)
	await H.section("test_sm_campaign", test_sm_campaign)
	await H.section("test_sm_hud", test_sm_hud)
	await H.section("test_sm_boot", test_sm_boot)
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

func test_sm_build() -> void:
	var econ: RTSEconomy = RTSEconomy.new()
	econ.set_credits(0, 2000)
	var yard: SMBuildYard = SMBuildYard.new()
	yard.economy = econ
	yard.team = 0
	yard.style = SMBuildYard.Style.SCAFFOLD
	yard.center = Vector3.ZERO
	yard.radius = 10.0
	yard.drain_per_sec = 5
	yard.tech_order = [&"yard", &"barracks", &"armory"]
	yard.building_time[&"yard"] = 4.0
	yard.building_time[&"barracks"] = 3.0
	yard.building_time[&"armory"] = 3.0
	check(not yard.begin_scaffold(&"yard", Vector3(20, 0, 0), 100.0), "scaffold rejects a footprint outside the yard")
	check(yard.begin_scaffold(&"yard", Vector3(2, 0, 0), 100.0), "scaffold accepts a footprint inside")
	check(yard.vulnerable, "scaffold is vulnerable while it builds")
	yard.damage_scaffold(40.0)
	check(yard.scaffold_hp == 60.0 and yard.vulnerable, "damage lands on the scaffold")
	yard.advance(2.0)
	check(yard.drained == 10 and yard.scaffold_active, "credits drain while the scaffold stands")
	yard.advance(2.0)
	check(yard.finished.has(&"yard") and not yard.vulnerable, "finished scaffold ends the drain")
	check(not yard.can_build(&"armory"), "linear tech skips nothing")
	check(yard.can_build(&"barracks"), "next building unlocks")
	check(yard.begin_scaffold(&"barracks", Vector3(1, 0, 1), 80.0), "second scaffold starts")
	yard.advance(3.0)
	check(yard.finished.has(&"barracks") and yard.can_build(&"armory"), "armory waits for the previous building")
	var mvd: SMBuildYard = SMBuildYard.new()
	mvd.style = SMBuildYard.Style.INTERNAL
	mvd.economy = econ
	mvd.team = 0
	mvd.center = Vector3.ZERO
	mvd.radius = 10.0
	mvd.clearance = 1
	mvd.building_tier[&"bay"] = 2
	mvd.building_tier[&"siege"] = 3
	mvd.building_time[&"bay"] = 2.0
	mvd.building_time[&"siege"] = 2.0
	check(not mvd.queue_internal(&"bay"), "clearance 1 cannot queue tier 2")
	check(not mvd.buy_clearance(3, 50), "clearance 3 before 2 is refused")
	check(mvd.buy_clearance(2, 50) and mvd.radius == 16.0, "clearance 2 grows the radius")
	check(mvd.queue_internal(&"bay"), "tier 2 queues inside the hub")
	check(mvd.placed.is_empty(), "the hub has not placed the shell yet")
	mvd.advance(2.0)
	check(mvd.ready.has(&"bay"), "the hub finishes the building")
	check(not mvd.place_finished(&"bay", Vector3(30, 0, 0)), "place rejects a point outside the radius")
	check(mvd.place_finished(&"bay", Vector3(12, 0, 0)), "place accepts a point inside the grown radius")
	check(mvd.buy_clearance(3, 50) and mvd.clearance == 3, "clearance 3 unlocks the next tier")
	check(mvd.queue_internal(&"siege"), "tier 3 queues after clearance 3")
	var grid: SMDomainGrid = SMDomainGrid.new(8, 8, 2.0, Vector3.ZERO)
	grid.set_domain(Vector2i(3, 0), SMDomainGrid.Domain.DEEP)
	var nmrf: SMBuildYard = SMBuildYard.new()
	nmrf.style = SMBuildYard.Style.MOBILE
	nmrf.grid = grid
	check(nmrf.move_packer(grid.cell_center(Vector2i(0, 0))), "packer starts on land")
	check(nmrf.move_packer(grid.cell_center(Vector2i(3, 0))), "packer sails into deep water")
	check(nmrf.unpack(&"boat_shed"), "packer unpacks")
	check(not nmrf.move_packer(grid.cell_center(Vector2i(0, 0))), "an unpacked core does not drive")
	check(nmrf.upgrade_factory(&"boat_shed") and nmrf.factory_level(&"boat_shed") == 2, "factory tier upgrade")
	check(nmrf.upgrade_factory(&"boat_shed") and nmrf.factory_level(&"boat_shed") == 3, "a second factory upgrade")
	check(not nmrf.upgrade_factory(&"boat_shed"), "factory tier stops at 3")

func test_sm_nodes() -> void:
	var net: SMCommodityNet = SMCommodityNet.new()
	var econ: RTSEconomy = RTSEconomy.new()
	check(SMCommodityNet.all_kinds().size() == 5, "five commodities")
	check(SMCommodityNet.display_name(SMCommodityNet.KIND_SLAG) == "Golden Slag / Aurum-9", "slag storefront name")
	check(SMCommodityNet.display_name(SMCommodityNet.KIND_RARE) == "rare earth", "rare earth name")
	check(SMCommodityNet.display_name(SMCommodityNet.KIND_RUBY) == "ruby", "ruby name")
	check(SMCommodityNet.display_name(SMCommodityNet.KIND_JADE) == "jade", "jade name")
	check(SMCommodityNet.display_name(SMCommodityNet.KIND_BULLION) == "gold bullion", "bullion name")
	net.add_node(&"s", SMCommodityNet.KIND_SLAG, Vector3.ZERO, 10, false)
	net.add_node(&"r", SMCommodityNet.KIND_RARE, Vector3(3, 0, 0), 0, true)
	net.add_node(&"u", SMCommodityNet.KIND_RUBY, Vector3(6, 0, 0), 10, false)
	net.add_node(&"j", SMCommodityNet.KIND_JADE, Vector3(9, 0, 0), 10, false)
	net.add_node(&"b", SMCommodityNet.KIND_BULLION, Vector3(12, 0, 0), 10, false)
	check(net.snap_refinery(&"s", 0), "refinery snaps to a node")
	check(net.has_collector(&"s"), "one collector spawns")
	check(not net.snap_refinery(&"s", 1), "a second refinery on the same node is rejected")
	check(net.advance(4.0, econ) == 10, "the collector loop pays")
	check(not net.set_night_shift(&"s", true), "slag has no night shift")
	check(net.set_night_shift(&"u", true) and net.visible_through_fog(&"u"), "ruby night shift is visible through fog")
	check(net.set_night_shift(&"j", true) and net.night_on(&"j"), "jade night shift toggles")
	check(net.snap_refinery(&"u", 0), "ruby refinery")
	var before: int = econ.credits(0)
	check(net.advance(2.0, econ) == 10 and econ.credits(0) - before == 10, "night shift pays a full loop in half the time")
	check(net.snap_refinery(&"r", 0), "rare-earth refinery")
	var credits_before: int = econ.credits(0)
	net.advance(4.0, econ)
	check(net.stock_of(0) == 1, "rare-earth stock is a separate counter")
	check(econ.credits(0) >= credits_before, "stock does not spend credits")
	check(not net.try_spend_stock(0, 2), "tier-3 gear cannot spend stock it lacks")
	check(net.try_spend_stock(0, 1) and net.stock_of(0) == 0, "rare-earth stock spends")
	check(net.harm_infantry(Vector3(3, 0, 0), false, 1.0) == 8.0, "adjacent water harms unshielded infantry")
	check(net.harm_infantry(Vector3(3, 0, 0), true, 1.0) == 0.0, "shielded infantry are spared")

func test_sm_tech() -> void:
	var tech: SMTechNet = SMTechNet.new()
	var econ: RTSEconomy = RTSEconomy.new()
	econ.set_credits(0, 0)
	econ.set_credits(1, 100)
	tech.add_site(&"c", SMTechNet.CYBER, Vector3.ZERO)
	tech.add_site(&"b", SMTechNet.BAZAAR, Vector3(2, 0, 0))
	tech.add_site(&"h", SMTechNet.CLINIC, Vector3(4, 0, 0))
	tech.add_site(&"r", SMTechNet.RADAR, Vector3(6, 0, 0))
	check(tech.capture(&"c", 0), "cyber compound captures")
	tech.advance(1.0, econ, 1)
	check(tech.income_of(&"c") == 12 and tech.siphon_of(&"c") == 4, "cyber income and siphon")
	check(econ.credits(1) == 96, "the siphon takes enemy credits")
	check(tech.capture(&"b", 0), "arms bazaar captures")
	check(is_equal_approx(tech.discount(0, "drone"), 0.7) and is_equal_approx(tech.discount(0, "infantry"), 0.7), "bazaar discounts drones and infantry")
	check(tech.discount(0, "armor") == 1.0, "bazaar leaves other tags alone")
	tech.set_import("rotary_slot", true)
	check(tech.import_open("rotary_slot"), "an import slot is a data flag")
	check(tech.capture(&"h", 0), "field clinic captures")
	tech.advance(1.0, econ, 1)
	check(tech.clinic_healed(0) >= 6.0, "field clinic heals")
	check(tech.capture(&"r", 0) and tech.reveals_water(0), "hydro radar reveals water")

func test_sm_abilities() -> void:
	var book: SMAbilities = SMAbilities.new()
	book.add_unit(1, Vector3.ZERO, SMAbilities.TOGGLE, 2.0, 1.0)
	book.add_unit(2, Vector3(1, 0, 0), SMAbilities.TOGGLE, 2.0, 1.0)
	check(book.group_toggle([1, 2]) == 2 and book.toggle_on(1) and book.toggle_on(2), "group toggle flips the group")
	book.add_unit(3, Vector3.ZERO, SMAbilities.SMART, 3.0, 1.0)
	book.add_unit(4, Vector3(6, 0, 0), SMAbilities.SMART, 3.0, 1.0)
	check(book.smart_cast([3, 4], Vector3.ZERO) == 3, "smart-cast picks the closest ready unit")
	check(book.fired_count(4) == 0, "the farther unit holds its fire")
	book.set_ready(3, 5.0)
	check(book.smart_cast([3, 4], Vector3.ZERO) == 4, "an unready closest unit is skipped")
	book.add_unit(5, Vector3.ZERO, SMAbilities.BEAM, 1.0, 1.0)
	book.add_unit(6, Vector3(2, 0, 0), SMAbilities.TOGGLE, 1.0, 1.0)
	check(book.begin_beam(5, 6), "channeled beam starts")
	book.advance(2.0)
	check(book.beam_done(5) == 1 and book.status_of(6) == SMAbilities.ST_FROZEN, "the beam completes and freezes the target")
	book.add_unit(7, Vector3.ZERO, SMAbilities.BEAM, 1.0, 1.0)
	check(book.begin_beam(7, 6), "a second beam starts")
	book.apply_status(7, SMAbilities.ST_FROZEN, 4.0)
	book.advance(2.0)
	check(book.beam_done(7) == 0 and not book.is_channeling(7), "frozen breaks the channel")
	book.apply_status(1, SMAbilities.ST_SHRUNK, 5.0)
	check(is_equal_approx(book.radius_of(1), 0.5), "shrunk halves the radius")
	book.apply_status(2, SMAbilities.ST_BLACK_HOLE, 5.0)
	check(is_equal_approx(book.damage_to(2, 50.0), 10.0) and is_equal_approx(book.hp_of(2), 90.0), "black-hole armor cuts incoming damage")
	book.advance(6.0)
	check(book.status_of(1) == SMAbilities.ST_NONE and is_equal_approx(book.radius_of(1), 1.0), "shrink wears off")

func test_sm_domain() -> void:
	var g: SMDomainGrid = SMDomainGrid.phillips_layout()
	check(g.domain_at_cell(Vector2i(8, 4)) == SMDomainGrid.Domain.LAND, "west land")
	check(g.domain_at_cell(Vector2i(30, 12)) == SMDomainGrid.Domain.LAND, "east land")
	check(g.domain_at_cell(Vector2i(20, 12)) == SMDomainGrid.Domain.DEEP, "deep channel")
	check(g.domain_at_cell(Vector2i(16, 5)) == SMDomainGrid.Domain.SHALLOW, "shallow crossing")
	check(g.domain_at_cell(Vector2i(5, 11)) == SMDomainGrid.Domain.CLIFF, "cliff flag")
	check(g.domain_at_cell(Vector2i(19, 10)) == SMDomainGrid.Domain.AIR, "air flag")
	_domain_seen.clear()
	g.domain_changed.connect(_on_test_domain)
	check(g.move_unit(3, g.cell_center(Vector2i(12, 5)), SMDomainGrid.Loco.AMPHIBIOUS), "amphibious steps onto land")
	check(_domain_seen.is_empty(), "the first placement does not signal")
	check(g.move_unit(3, g.cell_center(Vector2i(16, 5)), SMDomainGrid.Loco.AMPHIBIOUS), "amphibious enters shallow water")
	check(_domain_seen.size() == 2 and _domain_seen[0] == SMDomainGrid.Domain.LAND and _domain_seen[1] == SMDomainGrid.Domain.SHALLOW, "domain change at the shoreline")
	check(not g.move_unit(4, g.cell_center(Vector2i(20, 12)), SMDomainGrid.Loco.GROUND), "ground movement stops at deep water")
	check(not g.move_unit(5, g.cell_center(Vector2i(5, 11)), SMDomainGrid.Loco.AMPHIBIOUS), "a cliff blocks movement")
	check(g.move_unit(6, g.cell_center(Vector2i(19, 10)), SMDomainGrid.Loco.AIR), "air enters an air cell")
	check(g.move_unit(7, g.cell_center(Vector2i(20, 12)), SMDomainGrid.Loco.NAVAL), "naval enters deep water")

var _domain_seen: Array[int] = []

func _on_test_domain(_unit_id: int, from_domain: int, to_domain: int) -> void:
	_domain_seen.append(from_domain)
	_domain_seen.append(to_domain)

func test_sm_ew() -> void:
	var ew: SMEwField = SMEwField.new()
	ew.center = Vector3.ZERO
	ew.radius = 10.0
	var inside: Vector3 = Vector3(2, 0, 0)
	var outside: Vector3 = Vector3(30, 0, 0)
	check(is_equal_approx(ew.accuracy(inside, SMEwField.GPS), ew.penalty), "gps guidance is jammed")
	check(is_equal_approx(ew.accuracy(inside, SMEwField.FPV), ew.penalty), "fpv guidance is jammed")
	check(ew.accuracy(inside, SMEwField.FIBER) == 1.0, "fiber-optic ignores the jammer")
	check(ew.accuracy(inside, SMEwField.HOP) == 1.0, "frequency-hop ignores the jammer")
	check(ew.accuracy(inside, SMEwField.GPS, true, false) == 1.0, "an active fiber link is exempt")
	check(ew.accuracy(inside, SMEwField.FPV, false, true) == 1.0, "an active hop link is exempt")
	check(ew.accuracy(outside, SMEwField.GPS) == 1.0, "outside the jammer radius")
	check(ew.accuracy(inside, SMEwField.NONE) == 1.0, "unguided weapons are not jammed")

func test_sm_catalog() -> void:
	for id: String in ["gtfc", "mvd", "nmrf"]:
		var data: Dictionary = SMCatalog.faction(id)
		var units: Array[Dictionary] = SMCatalog.units_of(data)
		check(units.size() == 16, "%s fields sixteen catalog units" % id)
		for unit: Dictionary in units:
			check(SMCatalog.entry_ok(unit), "%s %s has a weapon and one secondary" % [id, str(unit.get("id", ""))])
	var gtfc: Dictionary = SMCatalog.faction("gtfc")
	var mvd: Dictionary = SMCatalog.faction("mvd")
	var nmrf: Dictionary = SMCatalog.faction("nmrf")
	var gtfc_colors: Dictionary = gtfc["colors"]
	var mvd_colors: Dictionary = mvd["colors"]
	var nmrf_colors: Dictionary = nmrf["colors"]
	check(str(gtfc_colors["primary"]) == "crimson" and str(gtfc_colors["accent"]) == "amber", "gtfc crimson and amber")
	check(str(mvd_colors["primary"]) == "charcoal" and str(mvd_colors["accent"]) == "cyan", "mvd charcoal and cyan")
	check(str(nmrf_colors["primary"]) == "olive" and str(nmrf_colors["accent"]) == "emerald", "nmrf olive and emerald")
	check(SMCatalog.stock_cost(mvd, "siege_works") == 1, "tier-3 gear requires rare-earth stock")
	var market: Dictionary = SMCatalog.faction("black_market")
	var flags: Dictionary = market["import_flags"]
	check(bool(flags.get("rotary_slot", false)) and bool(flags.get("strike_slot", false)) and bool(flags.get("spotter_slot", false)), "black-market imports are flags")
	var market_units: Array[Dictionary] = SMCatalog.units_of(market)
	check(market_units.size() == 4, "black market air is in the catalog")
	for unit: Dictionary in market_units:
		check(SMCatalog.entry_ok(unit), "black market %s has a weapon and one secondary" % str(unit.get("id", "")))
	var banned: PackedStringArray = PackedStringArray(["opium", "heroin", "cocaine", "fentanyl", "yaba", "methamphetamine"])
	var hits: PackedStringArray = PackedStringArray()
	for faction_id: String in ["gtfc", "mvd", "nmrf", "black_market"]:
		var text: String = FileAccess.get_file_as_string("res://data/factions/%s/faction.json" % faction_id).to_lower()
		for word: String in banned:
			if text.contains(word):
				hits.append("%s:%s" % [faction_id, word])
	check(hits.is_empty(), "faction data has no street-drug names %s" % [hits])

func test_sm_camera_rig() -> void:
	var cam: RTSCamera = RTSCamera.new()
	cam.bounds = Rect2(-40, -40, 80, 80)
	cam.edge_pan_px = 16.0
	root.add_child(cam)
	await process_frame
	cam.focus_on(Vector3.ZERO)
	cam.distance = 30.0
	var dir: Vector2 = cam.edge_scroll(Vector2(1, 200), Vector2(400, 400), 0.2)
	check(dir.x < 0.0 and cam.focus.x < 0.0, "edge scroll pans from the left margin")
	cam.focus_on(Vector3.ZERO)
	cam.distance = 40.0
	cam.zoom_toward(3.0, Vector3(10, 0, 0))
	check(cam.distance < 40.0 and cam.focus.x > 0.0, "zoom toward the cursor shifts the focus")
	var yaw: float = cam.yaw_degrees
	cam.orbit(25.0)
	check(absf(cam.yaw_degrees - yaw - 25.0) < 0.01, "orbit yaws around the focus")
	cam.free()

func test_sm_greybox() -> void:
	var scene: Node = (load("res://game/greybox.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	for node_name: String in ["BuildScaffold", "BuildInternal", "BuildMobile", "NodeSlag", "NodeRare", "NodeRuby", "NodeJade", "NodeBullion", "Jammer"]:
		check(scene.get_node_or_null(node_name) is MeshInstance3D, "greybox mesh %s" % node_name)
	var scaffold: MeshInstance3D = scene.get_node("BuildScaffold") as MeshInstance3D
	var internal: MeshInstance3D = scene.get_node("BuildInternal") as MeshInstance3D
	check(scaffold.mesh is CapsuleMesh and internal.mesh is BoxMesh, "scaffold is a capsule and the hub is a box")
	scene.free()
	await process_frame

func test_sm_phillips() -> void:
	var scene: Node = (load("res://game/phillips_channel.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var side: Node = scene.find_child("Sidebar", true, false)
	var bar: Node = scene.find_child("Protocols", true, false)
	check(side != null, "command sidebar is present")
	check(bar != null, "protocols bar is present")
	check(scene.find_child("GroupBuildings", true, false) != null and scene.find_child("GroupUnits", true, false) != null and scene.find_child("GroupAbility", true, false) != null, "the command column groups buildings, units, and ability")
	check(bool(scene.call("scripted_playthrough")), "phillips playthrough finishes")
	var played: SMMatch = scene.get("sim") as SMMatch
	check(played.finished and played.winner == 0, "the passive opponent is defeated")
	check(played.pipeline_ok and played.claimed, "the base is up and a node is claimed")
	check(played.f_smart == 11 and played.f_toggles == 1, "F fires a smart-cast and a toggle")
	check(played.domain_log.size() >= 2, "an amphibious unit crossed the channel")
	var field: SMPointer = scene.get("field") as SMPointer
	check(field != null and field.count_team(0) >= 3 and field.count_team(1) >= 2, "phillips places friendly and enemy units")
	check(scene.find_child("SelectionBox", true, false) != null, "phillips shows a selection box")
	var friends: Array[RTSUnit] = field.units_of(0)
	var picked: RTSUnit = field.select_click(_proj(friends[0].global_position), Callable(self, "_proj"))
	check(picked == friends[0] and field.selection.count() == 1, "left click selects one friendly unit")
	var step: Vector3 = friends[0].global_position + Vector3(0, 0, 8)
	var moved: StringName = field.command_at(step, _proj(step), Callable(self, "_proj"))
	check(moved == &"move" and friends[0].is_moving(), "right click on ground moves the selection")
	var foes: Array[RTSUnit] = field.units_of(1)
	var attacked: StringName = field.command_at(foes[0].global_position, _proj(foes[0].global_position), Callable(self, "_proj"))
	check(attacked == &"attack" and friends[0].attack_target == foes[0], "right click on an enemy attacks")
	var a: Vector2 = _proj(friends[0].global_position)
	var b: Vector2 = _proj(friends[1].global_position)
	var boxed: int = field.select_drag(Rect2(a, b - a).abs().grow(4.0), Callable(self, "_proj"))
	check(boxed >= 2, "a drag box selects several friendlies")
	check(_gtfc_names(field), "phillips labels the six GTFC placeholders")
	check(field.name_of(foes[0]) == "Enemy", "phillips labels the enemy")
	scene.free()
	await process_frame

func test_sm_bots() -> void:
	var played: SMMatch = SMMatch.new()
	for personality: StringName in SMBot.personalities():
		var bot: SMBot = SMBot.new(personality)
		var result: Dictionary = played.run_bot(bot)
		check(int(result["refineries"]) == int(result["refinery_target"]), "%s opens with two refineries" % str(personality))
		check(bool(result["water"]) and bool(result["gem"]), "%s expands to water and a gem node" % str(personality))
		check(bool(result["captured"]), "%s captures a tech building" % str(personality))
		check(bool(result["fired"]), "%s fires an ability" % str(personality))
		check(bool(result["protocols"]) and bool(result["audio_combat"]) and bool(result["silent"]), "%s protocols and silent stems" % str(personality))
	var isk: Dictionary = played.run_bot(SMBot.new(&"iskandar"))
	check(bool(isk["naval"]) and str(isk["faction"]) == "nmrf", "iskandar takes the naval lane")
	var tran: Dictionary = played.run_bot(SMBot.new(&"tran"))
	check(bool(tran["frozen"]) and bool(tran["flew"]) and str(tran["faction"]) == "gtfc", "tran uses cryo and air")
	var bo: Dictionary = played.run_bot(SMBot.new(&"bo_mya"))
	check(str(bo["faction"]) == "mvd" and bool(bo["fired"]), "bo mya fields drones")

func test_sm_mission() -> void:
	var scene: Node = (load("res://game/mission_kokang.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	check(str(scene.get("briefing_text")).contains("Kokang"), "the raid opens on a text briefing")
	check(bool(scene.call("scripted_playthrough")), "the raid is finishable")
	var raid: SMMission = scene.get("mission") as SMMission
	check(raid.won and raid.ruby_paid >= 30 and raid.goods.stock_of(0) >= 1, "night-shift ruby income and rare-earth stock")
	check(raid.yard.finished.has(&"scaffold_yard"), "the scaffold yard finishes")
	var field: SMPointer = scene.get("field") as SMPointer
	check(field != null and field.count_team(0) >= 2 and field.count_team(1) >= 1, "the raid places a squad and an enemy")
	check(scene.find_child("SelectionBox", true, false) != null, "the raid shows a selection box")
	var foe: RTSUnit = field.units_of(1)[0]
	var before: float = foe.hp
	var struck: int = int(scene.call("fire_secondary"))
	check(struck > 0 and foe.hp < before, "F strikes an enemy on the raid")
	check(_hud_text(scene, "HudFaction") == "GTFC" and _hud_text(scene, "HudCredits") == "Credits 50000" and _hud_text(scene, "HudPower") == "Power 90" and _hud_text(scene, "HudMap") == SMCampaign.title_of("kokang") and _hud_text(scene, "HudSelection") == "Nothing selected", "the raid shows faction, credits, power, and the mission name")
	var raid_map: SMMinimap = scene.find_child("Minimap", true, false) as SMMinimap
	if raid_map != null:
		raid_map.sample()
	var raid_cam: RTSCamera = scene.get_node("Camera") as RTSCamera
	check(scene.find_child("CompanyList", true, false) == null and raid_map != null and raid_map.saw_land and not raid_map.saw_water and raid_map.player_dots == field.count_team(0) and raid_map.enemy_dots == field.count_team(1) and raid_map.covers_focus() and raid_cam != null, "the raid minimap shows land, your units, enemies, and the camera")
	check(_click_east(scene), "clicking the raid minimap moves the camera")
	var raid_build: Button = scene.find_child("Build_scaffold_yard", true, false) as Button
	var raid_train: Button = scene.find_child("Train_militia", true, false) as Button
	var raid_ability: Button = scene.find_child("AbilityButton", true, false) as Button
	check(raid_build != null and raid_train != null and raid_ability != null and raid_ability.text == "Ability (F)" and scene.find_child("GroupBuildings", true, false) != null and scene.find_child("GroupUnits", true, false) != null and scene.find_child("GroupAbility", true, false) != null, "the raid command column builds, trains, and uses F")
	check(_gtfc_names(field), "the raid labels the six GTFC placeholders")
	check(field.name_of(foe) == "Enemy", "the raid labels the enemy")
	var boot: Node = (load("res://game/boot.tscn") as PackedScene).instantiate()
	root.add_child(boot)
	await process_frame
	check(boot.find_child("GreyboxButton", true, false) != null, "boot offers the greybox")
	check(boot.find_child("CardPhillips", true, false) != null, "boot offers Phillips Channel")
	var raid_button: Button = boot.find_child("Mission_kokang", true, false) as Button
	check(raid_button != null and raid_button.text == "Kokang raid (mission 1)", "boot offers the night raid")
	boot.free()
	scene.free()
	await process_frame

func test_sm_sop_ruak() -> void:
	var grid: SMDomainGrid = SMDomainGrid.sop_ruak_layout()
	var land: int = SMDomainGrid.Domain.LAND
	var deep: int = SMDomainGrid.Domain.DEEP
	check(grid.domain_at_cell(Vector2i(8, 24)) == land and grid.domain_at_cell(Vector2i(28, 24)) == land and grid.domain_at_cell(Vector2i(18, 6)) == land, "sop ruak has three land sectors")
	check(grid.domain_at_cell(Vector2i(17, 28)) == deep and grid.domain_at_cell(Vector2i(8, 8)) == deep and grid.domain_at_cell(Vector2i(27, 8)) == deep, "a Y of deep water splits the shores")
	check(grid.domain_at_cell(Vector2i(17, 24)) == land and grid.domain_at_cell(Vector2i(10, 10)) == land and grid.domain_at_cell(Vector2i(24, 10)) == land, "a ford crosses each arm of the river")
	var scene: Node = (load("res://game/sop_ruak.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	check(scene.get_node_or_null("WestSector") is MeshInstance3D and scene.get_node_or_null("EastSector") is MeshInstance3D and scene.get_node_or_null("NorthSector") is MeshInstance3D and scene.get_node_or_null("RiverStem") is MeshInstance3D, "sop ruak shows three shores and the river")
	var field: SMPointer = scene.get("field") as SMPointer
	var east_path: PackedVector3Array = field.nav.find_path(grid.cell_center(Vector2i(8, 24)), grid.cell_center(Vector2i(28, 24)))
	var north_path: PackedVector3Array = field.nav.find_path(grid.cell_center(Vector2i(8, 24)), grid.cell_center(Vector2i(18, 6)))
	check(east_path.size() > 0 and north_path.size() > 0, "fords link the west shore to the east and the north")
	check(_gtfc_names(field), "sop ruak labels the six GTFC placeholders")
	check(field.name_of(field.units_of(1)[0]) == "Enemy", "sop ruak labels the enemy")
	check(scene.find_child("SelectionBox", true, false) != null, "sop ruak shows a selection box")
	var friends: Array[RTSUnit] = field.units_of(0)
	var picked: RTSUnit = field.select_click(_proj(friends[0].global_position), Callable(self, "_proj"))
	check(picked == friends[0] and field.selection.count() == 1, "left click selects one friendly unit")
	var north: Vector3 = grid.cell_center(Vector2i(18, 6))
	var moved: StringName = field.command_at(north, _proj(north), Callable(self, "_proj"))
	check(moved == &"move" and friends[0].is_moving(), "right click on ground moves the selection")
	var foes: Array[RTSUnit] = field.units_of(1)
	var attacked: StringName = field.command_at(foes[0].global_position, _proj(foes[0].global_position), Callable(self, "_proj"))
	check(attacked == &"attack" and friends[0].attack_target == foes[0], "right click on an enemy attacks")
	check(bool(scene.call("fire_ability")), "F fires the sop ruak ability")
	var boot: Node = (load("res://game/boot.tscn") as PackedScene).instantiate()
	root.add_child(boot)
	await process_frame
	check(_card_line(boot, "CardSopRuak", "Sop Ruak", "River"), "boot names the river skirmish")
	boot.free()
	scene.free()
	await process_frame

func test_sm_maps() -> void:
	var land: int = SMDomainGrid.Domain.LAND
	var deep: int = SMDomainGrid.Domain.DEEP
	var cliff: int = SMDomainGrid.Domain.CLIFF
	var shallow: int = SMDomainGrid.Domain.SHALLOW
	var burma: SMDomainGrid = SMDomainGrid.burma_road_layout()
	check(burma.domain_at_cell(Vector2i(2, 2)) == cliff and burma.domain_at_cell(Vector2i(18, 4)) == cliff, "burma highlands and the wall are cliffs")
	check(burma.domain_at_cell(Vector2i(18, 13)) == land and burma.domain_at_cell(Vector2i(4, 14)) == land and burma.domain_at_cell(Vector2i(34, 14)) == land, "the burma road is land between the shores")
	var atolls: SMDomainGrid = SMDomainGrid.ten_degree_atolls_layout()
	check(atolls.domain_at_cell(Vector2i(0, 0)) == deep and atolls.domain_at_cell(Vector2i(18, 30)) == deep, "the atolls sit in deep water")
	check(atolls.domain_at_cell(Vector2i(4, 17)) == land and atolls.domain_at_cell(Vector2i(28, 17)) == land and atolls.domain_at_cell(Vector2i(16, 4)) == land, "three atoll islands are land")
	check(atolls.domain_at_cell(Vector2i(14, 17)) == shallow and atolls.domain_at_cell(Vector2i(17, 10)) == shallow, "shoals link the atolls")
	var mekong: SMDomainGrid = SMDomainGrid.mekong_delta_layout()
	check(mekong.domain_at_cell(Vector2i(13, 4)) == deep and mekong.domain_at_cell(Vector2i(27, 28)) == deep, "mekong canals are deep water")
	check(mekong.domain_at_cell(Vector2i(13, 15)) == land and mekong.domain_at_cell(Vector2i(27, 16)) == land and mekong.domain_at_cell(Vector2i(4, 16)) == land, "bridges and paddies stay land")
	var chiang: SMDomainGrid = SMDomainGrid.chiang_rai_layout()
	check(chiang.cols > burma.cols and chiang.rows > mekong.rows, "chiang rai is the larger map")
	check(chiang.domain_at_cell(Vector2i(27, 2)) == deep and chiang.domain_at_cell(Vector2i(8, 7)) == cliff, "chiang rai has a river and a siege wall")
	check(chiang.domain_at_cell(Vector2i(27, 10)) == land and chiang.domain_at_cell(Vector2i(27, 30)) == land and chiang.domain_at_cell(Vector2i(8, 34)) == land and chiang.domain_at_cell(Vector2i(46, 8)) == land, "fords and both camps on chiang rai are land")
	await _play_map("res://game/burma_road.tscn", "HighlandWest", "Road", Vector2i(4, 14), Vector2i(34, 14), Vector2i(10, 20))
	await _play_map("res://game/ten_degree_atolls.tscn", "WestIsle", "Sea", Vector2i(4, 17), Vector2i(28, 17), Vector2i(6, 18))
	await _play_map("res://game/mekong_delta.tscn", "CanalWest", "BridgeWest", Vector2i(4, 16), Vector2i(34, 16), Vector2i(6, 20))
	await _play_map("res://game/chiang_rai.tscn", "SiegeRiver", "WallWest", Vector2i(8, 34), Vector2i(46, 8), Vector2i(10, 34))
	var boot: Node = (load("res://game/boot.tscn") as PackedScene).instantiate()
	root.add_child(boot)
	await process_frame
	check(_card_line(boot, "CardBurma", "Burma Road", "Land"), "boot names Burma Road")
	check(_card_line(boot, "CardAtolls", "Ten Degree Atolls", "Water"), "boot names Ten Degree Atolls")
	check(_card_line(boot, "CardMekong", "Mekong Delta", "River"), "boot names the Mekong Delta")
	check(_card_line(boot, "CardChiang", "Siege of Chiang Rai", "River"), "boot names the Siege of Chiang Rai")
	boot.free()
	await process_frame

func test_sm_factions() -> void:
	var nmrf: Node = (load("res://game/nmrf_yard.tscn") as PackedScene).instantiate()
	root.add_child(nmrf)
	await process_frame
	check(nmrf.get_node_or_null("OliveGround") is MeshInstance3D and nmrf.get_node_or_null("PackerCore") is MeshInstance3D, "nmrf shows the mobile core")
	var nfield: SMPointer = nmrf.get("field") as SMPointer
	check(_has_names(nfield, PackedStringArray(["River Rifle", "Sampan", "Emerald Gunboat", "Mangrove Tube", "Packer", "Jade Skiff"])), "nmrf labels its six units")
	check(nfield.name_of(nfield.units_of(1)[0]) == "Enemy", "nmrf labels the enemy")
	check(_orders(nmrf, nfield), "nmrf select, move, attack, and F")
	var nyard: SMBuildYard = nmrf.get("yard") as SMBuildYard
	check(nyard.style == SMBuildYard.Style.MOBILE, "nmrf uses the mobile packer")
	check(bool(nmrf.call("move_packer")), "the packer sails")
	check(nyard.grid.unit_domain(nyard.packer_id) == SMDomainGrid.Domain.SHALLOW, "the packer enters shallow water")
	check(bool(nmrf.call("unpack_core")) and nyard.factory_level(&"gun_wharf") == 1, "the wharf unpacks")
	check(bool(nmrf.call("upgrade_wharf")) and nyard.factory_level(&"gun_wharf") == 2, "the wharf upgrades")
	var nfriends: Array[RTSUnit] = nfield.units_of(0)
	check(_albedo(nfriends[0]) == Color.html("#5A6824") and _albedo(nfriends[1]) == Color.html("#1F9E66"), "nmrf is olive and emerald")
	nmrf.free()
	var mvd: Node = (load("res://game/mvd_yard.tscn") as PackedScene).instantiate()
	root.add_child(mvd)
	await process_frame
	check(mvd.get_node_or_null("CharcoalPad") is MeshInstance3D and mvd.get_node_or_null("HubShell") is MeshInstance3D, "mvd shows the internal pad")
	var mfield: SMPointer = mvd.get("field") as SMPointer
	check(_has_names(mfield, PackedStringArray(["Clearance Trooper", "Hub Drone", "Charcoal APC", "Cyan IFV", "Relay Van", "River Drone"])), "mvd labels its six units")
	check(mfield.name_of(mfield.units_of(1)[0]) == "Enemy", "mvd labels the enemy")
	check(_orders(mvd, mfield), "mvd select, move, attack, and F")
	var myard: SMBuildYard = mvd.get("yard") as SMBuildYard
	check(myard.style == SMBuildYard.Style.INTERNAL, "mvd uses the internal queue")
	var before_radius: float = myard.radius
	check(not myard.queue_internal(&"drone_bay"), "tier 2 waits on clearance")
	check(bool(mvd.call("buy_clearance")) and myard.clearance == 2 and myard.radius == before_radius + 6.0, "clearance 2 widens the pad")
	check(bool(mvd.call("queue_hub")), "the hub finishes inside the queue")
	check(bool(mvd.call("place_hub")) and myard.finished.has(&"command_hub"), "the hub places inside the radius")
	check(bool(mvd.call("buy_clearance")) and myard.clearance == 3, "clearance 3 follows clearance 2")
	var mfriends: Array[RTSUnit] = mfield.units_of(0)
	check(_albedo(mfriends[0]) == Color.html("#2A2E32") and _albedo(mfriends[1]) == Color.html("#26BFD1"), "mvd is charcoal and cyan")
	check(mfield.teams.color_of(1) != Color.html("#26BFD1"), "the mvd enemy is not painted cyan")
	mvd.free()
	var boot: Node = (load("res://game/boot.tscn") as PackedScene).instantiate()
	root.add_child(boot)
	await process_frame
	check(_faction_line(boot, "FactionNmrf", "NMRF", "Mobile core", "#5A6824") and boot.find_child("NmrfYardButton", true, false) != null, "boot offers NMRF")
	check(_faction_line(boot, "FactionMvd", "MVD", "Internal queue", "#2A2E32") and boot.find_child("MvdYardButton", true, false) != null, "boot offers MVD")
	boot.free()
	await process_frame

func test_sm_raider() -> void:
	var paths: PackedStringArray = PackedStringArray([
		"res://game/phillips_channel.tscn",
		"res://game/sop_ruak.tscn",
		"res://game/burma_road.tscn",
		"res://game/ten_degree_atolls.tscn",
		"res://game/mekong_delta.tscn",
		"res://game/chiang_rai.tscn",
		"res://game/nmrf_yard.tscn",
		"res://game/mvd_yard.tscn",
	])
	for path: String in paths:
		await _enemy_fights(path)

func test_sm_roster() -> void:
	var failed: PackedStringArray = PackedStringArray()
	var total: int = 0
	for faction_id: String in ["gtfc", "mvd", "nmrf", "black_market"]:
		var roster: SMRoster = SMRoster.new()
		roster.setup(faction_id)
		for unit: Dictionary in SMCatalog.units_of(SMCatalog.faction(faction_id)):
			total += 1
			var id: StringName = StringName(str(unit.get("id", "")))
			if roster.train_and_finish(id) != id:
				failed.append("%s:%s" % [faction_id, str(id)])
	check(total == 52 and failed.is_empty(), "all 52 catalog units train through production %s" % [failed])
	check(_spawned("gtfc", &"crimson_sapper", "Crimson Sapper", "rifle", "smart_cast", 9.0), "gtfc sapper spawns with a weapon and a secondary")
	check(_spawned("mvd", &"cyan_sentry", "Cyan Sentry", "carbine", "group_toggle", 9.0), "mvd sentry spawns with a weapon and a secondary")
	check(_spawned("nmrf", &"olive_ranger", "Olive Ranger", "rifle", "group_toggle", 8.0), "nmrf ranger spawns with a weapon and a secondary")
	check(_spawned("black_market", &"ch4", "CH-4", "autocannon", "smart_cast", 14.0), "CH-4 spawns from production")
	check(_spawned("black_market", &"su30", "Su-30", "cannon", "group_toggle", 26.0), "Su-30 spawns from production")
	check(_spawned("black_market", &"orlan10", "Orlan-10", "camera", "channeled_beam", 4.0), "Orlan-10 spawns from production")
	var phillips_name: String = await _trained("res://game/phillips_channel.tscn")
	check(phillips_name == "Crimson Sapper", "phillips trains a catalog unit onto the field")
	var burma_name: String = await _trained("res://game/burma_road.tscn")
	check(burma_name == "Crimson Sapper", "burma road trains a catalog unit onto the field")
	var nmrf_name: String = await _trained("res://game/nmrf_yard.tscn")
	check(nmrf_name == "Olive Ranger", "nmrf trains a catalog unit onto the field")
	var mvd_name: String = await _trained("res://game/mvd_yard.tscn")
	check(mvd_name == "Cyan Sentry", "mvd trains a catalog unit onto the field")

func test_sm_campaign() -> void:
	var ids: PackedStringArray = SMCampaign.ids()
	check(ids.size() == 14, "fourteen campaign missions follow Kokang")
	var camp: SMCampaign = SMCampaign.new()
	for id: String in ids:
		var brief: String = SMCampaign.briefing_of(id)
		var lower: String = brief.to_lower()
		check(brief != "" and not lower.contains("fmv") and not lower.contains("video"), "%s is a text briefing" % id)
		check(camp.play(id), "%s can be finished" % id)
	SMCampaign.selected = "mae_sai"
	var scene: Node = (load("res://game/campaign_mission.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	check(str(scene.get("briefing_text")).contains("Mae Sai"), "the mission scene shows the Mae Sai briefing")
	check(bool(scene.call("scripted_playthrough")), "the mission scene can be finished")
	check(scene.find_child("SelectionBox", true, false) != null, "the mission scene has select controls")
	var friends: Array[RTSUnit] = (scene.get("field") as SMPointer).units_of(0)
	var picked: RTSUnit = (scene.get("field") as SMPointer).select_click(_proj(friends[0].global_position), Callable(self, "_proj"))
	check(picked == friends[0], "left click selects on a campaign mission")
	(scene.get("hud") as SMHud).refresh()
	check(_hud_text(scene, "HudSelection") == "Militia    HP 80/80    F group toggle", "the mission selection shows name, health, and its F ability")
	check(_click_east(scene), "clicking the mission minimap moves the camera")
	var mission_build: Button = scene.find_child("Build_scaffold_yard", true, false) as Button
	mission_build.pressed.emit()
	var mission_yard: SMBuildYard = (scene.get("side") as SMSide).yard
	var mission_purse: SMRoster = scene.get("roster") as SMRoster
	check(mission_yard.finished.has(&"scaffold_yard") and mission_yard.style == SMBuildYard.Style.SCAFFOLD and mission_purse.economy.credits(0) == 49980, "a mission building click raises a scaffold yard")
	scene.free()
	for id: String in ids:
		SMCampaign.selected = id
		var mission_scene: Node = (load("res://game/campaign_mission.tscn") as PackedScene).instantiate()
		root.add_child(mission_scene)
		await process_frame
		check(_campaign_hud(mission_scene, id), "%s shows the in-match hud" % id)
		mission_scene.free()
		await process_frame
	var boot: Node = (load("res://game/boot.tscn") as PackedScene).instantiate()
	root.add_child(boot)
	await process_frame
	for id: String in ids:
		var button: Button = boot.find_child("Mission_%s" % id, true, false) as Button
		check(button != null and button.text == SMCampaign.title_of(id), "boot lists %s" % id)
	boot.free()
	await process_frame

func test_sm_hud() -> void:
	SMFront.faction_id = "gtfc"
	var scene: Node = (load("res://game/phillips_channel.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	check(_hud_text(scene, "HudFaction") == "GTFC", "phillips names the faction")
	check(_hud_text(scene, "HudCredits") == "Credits 50000", "phillips shows credits")
	check(_hud_text(scene, "HudPower") == "Power 90", "phillips shows army power")
	check(_hud_text(scene, "HudMap") == "Phillips Channel", "phillips names the map")
	check(_hud_text(scene, "HudSelection") == "Nothing selected", "phillips says when nothing is selected")
	var built: Button = scene.find_child("Build_scaffold_yard", true, false) as Button
	var trained: Button = scene.find_child("Train_militia", true, false) as Button
	var ability: Button = scene.find_child("AbilityButton", true, false) as Button
	check(built != null and trained != null and ability != null and ability.text == "Ability (F)", "phillips can build, train, and use F")
	var field: SMPointer = scene.get("field") as SMPointer
	var mm: SMMinimap = scene.find_child("Minimap", true, false) as SMMinimap
	check(scene.find_child("CompanyList", true, false) == null and mm != null, "phillips uses a minimap instead of a name list")
	mm.sample()
	check(mm.terrain_kind(Vector2i(2, 8)) == "land" and mm.terrain_kind(Vector2i(18, 12)) == "water" and mm.saw_land and mm.saw_water, "the minimap draws land and water")
	check(mm.player_dots == field.count_team(0) and mm.enemy_dots == field.count_team(1) and mm.player_dots >= 6 and mm.enemy_dots >= 1, "the minimap marks your units and enemy units")
	check(mm.camera_rect.size.x > 1.0 and mm.covers_focus(), "the minimap draws the camera rectangle")
	check(_click_east(scene), "clicking the minimap moves the camera")
	var friends: Array[RTSUnit] = field.units_of(0)
	var picked: RTSUnit = field.select_click(_proj(friends[0].global_position), Callable(self, "_proj"))
	(scene.get("hud") as SMHud).refresh()
	check(picked == friends[0] and _hud_text(scene, "HudSelection") == "Militia    HP 80/80    F group toggle", "the selection shows name, health, and its F ability")
	var purse: SMRoster = scene.get("roster") as SMRoster
	built.pressed.emit()
	var yard: SMBuildYard = (scene.get("side") as SMSide).yard
	check(yard.finished.has(&"scaffold_yard") and yard.style == SMBuildYard.Style.SCAFFOLD and purse.economy.credits(0) == 49980 and scene.get_node_or_null("Built_scaffold_yard") is MeshInstance3D, "a building click raises a scaffold yard")
	var before: int = field.count_team(0)
	trained.pressed.emit()
	check(field.count_team(0) == before + 1 and purse.economy.credits(0) == 49900 and _hud_text(scene, "HudPower") == "Power 98", "a unit click trains it and spends credits")
	scene.free()
	await _hud_map("res://game/sop_ruak.tscn", "Sop Ruak")
	await _hud_map("res://game/burma_road.tscn", "Burma Road")
	await _hud_map("res://game/ten_degree_atolls.tscn", "Ten Degree Atolls")
	await _hud_map("res://game/mekong_delta.tscn", "Mekong Delta")
	await _hud_map("res://game/chiang_rai.tscn", "Siege of Chiang Rai")
	SMFront.faction_id = "nmrf"
	var burma: Node = (load("res://game/burma_road.tscn") as PackedScene).instantiate()
	root.add_child(burma)
	await process_frame
	check(_hud_text(burma, "HudFaction") == "NMRF", "the hud follows the selected faction")
	var packer: Button = burma.find_child("MovePacker", true, false) as Button
	var nmrf_side: SMSide = burma.get("side") as SMSide
	var origin: Vector3 = nmrf_side.yard.packer_pos
	packer.pressed.emit()
	check(packer != null and nmrf_side.yard.packer_pos != origin and nmrf_side.yard.style == SMBuildYard.Style.MOBILE, "the packer button uses the mobile build")
	var wharf: Button = burma.find_child("Build_gun_wharf", true, false) as Button
	wharf.pressed.emit()
	check(nmrf_side.yard.finished.has(&"gun_wharf"), "a wharf click unpacks the mobile core")
	burma.free()
	SMFront.faction_id = "mvd"
	var atoll: Node = (load("res://game/ten_degree_atolls.tscn") as PackedScene).instantiate()
	root.add_child(atoll)
	await process_frame
	var hub: Button = atoll.find_child("Build_command_hub", true, false) as Button
	hub.pressed.emit()
	var mvd_side: SMSide = atoll.get("side") as SMSide
	check(_hud_text(atoll, "HudFaction") == "MVD" and mvd_side.yard.style == SMBuildYard.Style.INTERNAL and mvd_side.yard.finished.has(&"command_hub"), "a hub click uses the internal queue")
	atoll.free()
	SMFront.faction_id = "gtfc"
	check(SMFront.current() == "gtfc", "the hud test restores GTFC")
	await process_frame

func _click_east(scene: Node) -> bool:
	var mm: SMMinimap = scene.find_child("Minimap", true, false) as SMMinimap
	var cam: RTSCamera = scene.get_node_or_null("Camera") as RTSCamera
	if mm == null or cam == null:
		return false
	var before_x: float = cam.focus.x
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(mm.map_size().x - 2.0, mm.map_size().y * 0.5)
	mm._gui_input(click)
	return cam.focus.x > before_x + 8.0

func _campaign_hud(scene: Node, id: String) -> bool:
	var mm: SMMinimap = scene.find_child("Minimap", true, false) as SMMinimap
	if mm == null or scene.find_child("CompanyList", true, false) != null:
		return false
	mm.sample()
	var field: SMPointer = scene.get("field") as SMPointer
	var cam: RTSCamera = scene.get_node_or_null("Camera") as RTSCamera
	var built: Button = scene.find_child("Build_scaffold_yard", true, false) as Button
	var trained: Button = scene.find_child("Train_militia", true, false) as Button
	var ability: Button = scene.find_child("AbilityButton", true, false) as Button
	if field == null or cam == null or built == null or trained == null or ability == null or ability.text != "Ability (F)":
		return false
	if scene.find_child("GroupBuildings", true, false) == null or scene.find_child("GroupUnits", true, false) == null or scene.find_child("GroupAbility", true, false) == null:
		return false
	if _hud_text(scene, "HudFaction") != "GTFC" or _hud_text(scene, "HudCredits") != "Credits 50000":
		return false
	if not _hud_text(scene, "HudPower").begins_with("Power ") or _hud_text(scene, "HudMap") != SMCampaign.title_of(id):
		return false
	if _hud_text(scene, "HudSelection") != "Nothing selected":
		return false
	if not mm.saw_land or mm.saw_water:
		return false
	if mm.player_dots != field.count_team(0) or mm.enemy_dots != field.count_team(1):
		return false
	if mm.camera_rect.size.x <= 1.0 or not mm.covers_focus():
		return false
	return true

func _hud_text(scene: Node, node_name: String) -> String:
	var label: Label = scene.find_child(node_name, true, false) as Label
	if label == null:
		return ""
	return label.text

func _hud_map(path: String, map_name: String) -> void:
	var scene: Node = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	check(_hud_text(scene, "HudMap") == map_name, "%s names the map on the hud" % map_name)
	var mm: SMMinimap = scene.find_child("Minimap", true, false) as SMMinimap
	if mm != null:
		mm.sample()
	var terrain_ok: bool = mm != null and mm.saw_land and (map_name == "Burma Road" or mm.saw_water)
	check(_hud_text(scene, "HudFaction") == "GTFC" and _hud_text(scene, "HudPower").begins_with("Power ") and _hud_text(scene, "HudSelection") == "Nothing selected" and scene.find_child("CompanyList", true, false) == null and terrain_ok and mm.covers_focus(), "%s shows faction, power, an empty selection, and the minimap" % map_name)
	scene.free()
	await process_frame

func test_sm_boot() -> void:
	SMFront.faction_id = "gtfc"
	var boot: Node = (load("res://game/boot.tscn") as PackedScene).instantiate()
	root.add_child(boot)
	await process_frame
	check(boot.find_child("TabSkirmish", true, false) != null and boot.find_child("TabCampaign", true, false) != null and boot.find_child("TabFaction", true, false) != null, "boot has three tabs")
	check(_bar_ok(boot), "the control bar lists select, move, ability, pan, and zoom")
	var play: Button = boot.find_child("PlayButton", true, false) as Button
	check(play != null and play.disabled, "play waits for a map")
	check(_card_line(boot, "CardPhillips", "Phillips Channel", "Water"), "phillips is a water card")
	check(_card_line(boot, "CardSopRuak", "Sop Ruak", "River"), "sop ruak is a river card")
	check(_card_line(boot, "CardBurma", "Burma Road", "Land"), "burma road is a land card")
	check(_card_line(boot, "CardAtolls", "Ten Degree Atolls", "Water"), "the atolls are a water card")
	check(_card_line(boot, "CardMekong", "Mekong Delta", "River"), "the mekong is a river card")
	check(_card_line(boot, "CardChiang", "Siege of Chiang Rai", "River"), "chiang rai is a river card")
	var burma_card: Button = boot.find_child("CardBurma", true, false) as Button
	burma_card.pressed.emit()
	check(str(boot.get("selected_map")).contains("burma_road") and not play.disabled, "a card arms play")
	check(boot.find_child("GreyboxButton", true, false) != null, "greybox stays on the skirmish tab")
	var campaign: Button = boot.find_child("TabCampaign", true, false) as Button
	campaign.pressed.emit()
	var act1: Control = boot.find_child("ActIMissions", true, false) as Control
	var act2: Control = boot.find_child("ActIIMissions", true, false) as Control
	var act3: Control = boot.find_child("ActIIIMissions", true, false) as Control
	check(act1 != null and act1.is_visible_in_tree() and act2 != null and not act2.is_visible_in_tree() and act3 != null and not act3.is_visible_in_tree(), "only the selected act is listed")
	check(_bar_ok(boot), "the control bar stays up on campaign")
	var act2_button: Button = boot.find_child("ActII", true, false) as Button
	act2_button.pressed.emit()
	check(act2.is_visible_in_tree() and not act1.is_visible_in_tree(), "act two replaces act one")
	var crossing: Button = boot.find_child("Mission_channel_crossing", true, false) as Button
	var crossing_brief: Label = boot.find_child("Brief_channel_crossing", true, false) as Label
	check(crossing != null and crossing.text == SMCampaign.title_of("channel_crossing") and crossing_brief != null and crossing_brief.text == SMCampaign.briefing_of("channel_crossing") and crossing.is_visible_in_tree(), "act two shows the crossing briefing")
	var faction_tab: Button = boot.find_child("TabFaction", true, false) as Button
	faction_tab.pressed.emit()
	check(_faction_line(boot, "FactionGtfc", "GTFC", "Scaffold yard", "#B81E2D"), "gtfc shows its color and build style")
	check(_faction_line(boot, "FactionNmrf", "NMRF", "Mobile core", "#5A6824"), "nmrf shows its color and build style")
	check(_faction_line(boot, "FactionMvd", "MVD", "Internal queue", "#2A2E32"), "mvd shows its color and build style")
	var pick: Button = boot.find_child("FactionNmrf", true, false) as Button
	pick.pressed.emit()
	check(SMFront.faction_id == "nmrf", "the next skirmish uses the selected faction")
	check(_bar_ok(boot), "the control bar stays up on faction")
	boot.free()
	var scene: Node = (load("res://game/burma_road.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var field: SMPointer = scene.get("field") as SMPointer
	check(_has_names(field, PackedStringArray(["River Rifle", "Sampan", "Emerald Gunboat", "Mangrove Tube", "Packer", "Jade Skiff"])), "burma plays the selected nmrf side")
	check(scene.find_child("MovePacker", true, false) != null, "nmrf skirmish can move the packer")
	check(str(scene.call("train_unit")) == "Olive Ranger", "nmrf skirmish trains an nmrf unit")
	scene.free()
	SMFront.faction_id = "gtfc"
	check(SMFront.current() == "gtfc", "faction selection resets")
	await process_frame

func _spawned(faction: String, id: StringName, display: String, weapon: String, secondary: String, damage: float) -> bool:
	var host: Node3D = Node3D.new()
	root.add_child(host)
	var cam: RTSCamera = RTSCamera.new()
	host.add_child(cam)
	var field: SMPointer = SMPointer.new()
	field.bind_faction(host, cam, faction)
	field.use_open(8, 8, 2.0, Vector3.ZERO)
	var roster: SMRoster = SMRoster.new()
	roster.setup(faction)
	var made: StringName = roster.train_and_finish(id)
	var u: RTSUnit = field.spawn(SMPointer.PLAYER, Vector3.ZERO, id)
	var ok: bool = made == id and field.name_of(u) == display and str(u.get_meta("weapon")) == weapon and str(u.get_meta("secondary")) == secondary and is_equal_approx(u.attack_damage, damage)
	host.free()
	return ok

func _trained(path: String) -> String:
	var scene: Node = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var field: SMPointer = scene.get("field") as SMPointer
	var before: int = field.count_team(0)
	var label: String = str(scene.call("train_unit"))
	var grew: bool = field.count_team(0) == before + 1
	scene.free()
	await process_frame
	if not grew:
		return ""
	return label

func _enemy_fights(path: String) -> void:
	var scene: Node = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var raider: SMRaider = scene.get("raider") as SMRaider
	var field: SMPointer = scene.get("field") as SMPointer
	var foe: RTSUnit = field.units_of(1)[0]
	var label: String = path.get_file()
	check(raider != null and raider.built and raider.yard.finished.has(&"enemy_yard") and scene.get_node_or_null("EnemyYard") is MeshInstance3D, "%s enemy builds a yard" % label)
	check(raider.expanded and raider.goods.has_collector(raider.node_id) and scene.get_node_or_null("EnemyClaim") is MeshInstance3D, "%s enemy expands onto a ruby node" % label)
	check(raider.attacked and foe.attack_target != null and foe.attack_target.team == 0 and (foe.is_moving() or foe.attack_target.hp < foe.attack_target.max_hp), "%s enemy attacks the player" % label)
	scene.free()
	await process_frame

func _orders(scene: Node, field: SMPointer) -> bool:
	if scene.find_child("SelectionBox", true, false) == null:
		return false
	var friends: Array[RTSUnit] = field.units_of(0)
	var picked: RTSUnit = field.select_click(_proj(friends[0].global_position), Callable(self, "_proj"))
	if picked != friends[0] or field.selection.count() != 1:
		return false
	var grid: SMDomainGrid = scene.get("grid") as SMDomainGrid
	var step: Vector3 = grid.cell_center(Vector2i(2, 6))
	if field.command_at(step, _proj(step), Callable(self, "_proj")) != &"move" or not friends[0].is_moving():
		return false
	var foes: Array[RTSUnit] = field.units_of(1)
	if field.command_at(foes[0].global_position, _proj(foes[0].global_position), Callable(self, "_proj")) != &"attack":
		return false
	if friends[0].attack_target != foes[0]:
		return false
	return bool(scene.call("fire_ability"))

func _has_names(field: SMPointer, need: PackedStringArray) -> bool:
	var names: PackedStringArray = PackedStringArray()
	for u: RTSUnit in field.units_of(0):
		names.append(field.name_of(u))
	for item: String in need:
		if not names.has(item):
			return false
	return true

func _albedo(u: RTSUnit) -> Color:
	var body: MeshInstance3D = u.get_child(0) as MeshInstance3D
	var mat: StandardMaterial3D = body.material_override as StandardMaterial3D
	return mat.albedo_color

func _card_line(boot: Node, node_name: String, map_name: String, terrain: String) -> bool:
	var card: Button = boot.find_child(node_name, true, false) as Button
	if card == null:
		return false
	var title: Label = card.find_child("Title", true, false) as Label
	var line: Label = card.find_child("Terrain", true, false) as Label
	if title == null or line == null:
		return false
	return title.text == map_name and line.text == terrain

func _faction_line(boot: Node, node_name: String, faction_name: String, style: String, hex: String) -> bool:
	var card: Button = boot.find_child(node_name, true, false) as Button
	if card == null:
		return false
	var title: Label = card.find_child("Title", true, false) as Label
	var style_label: Label = card.find_child("Style", true, false) as Label
	var swatch: ColorRect = card.find_child("Primary", true, false) as ColorRect
	if title == null or style_label == null or swatch == null:
		return false
	return title.text == faction_name and style_label.text == style and swatch.color == Color.html(hex)

func _bar_ok(boot: Node) -> bool:
	var bar: Label = boot.find_child("ControlBar", true, false) as Label
	if bar == null or not bar.is_visible_in_tree():
		return false
	var text: String = bar.text
	return text.contains("Left click selects") and text.contains("Right click moves or attacks") and text.contains("F ability") and text.contains("Edge pan") and text.contains("Wheel zoom")

func _play_map(path: String, mesh_a: String, mesh_b: String, from_cell: Vector2i, to_cell: Vector2i, move_cell: Vector2i) -> void:
	var scene: Node = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	check(scene.get_node_or_null(mesh_a) is MeshInstance3D and scene.get_node_or_null(mesh_b) is MeshInstance3D, "%s shows its terrain" % path.get_file())
	var field: SMPointer = scene.get("field") as SMPointer
	var grid: SMDomainGrid = scene.get("grid") as SMDomainGrid
	var route: PackedVector3Array = field.nav.find_path(grid.cell_center(from_cell), grid.cell_center(to_cell))
	check(route.size() > 0, "%s path reaches the enemy shore" % path.get_file())
	check(_gtfc_names(field), "%s labels the six GTFC placeholders" % path.get_file())
	check(field.name_of(field.units_of(1)[0]) == "Enemy", "%s labels the enemy" % path.get_file())
	check(scene.find_child("SelectionBox", true, false) != null, "%s shows a selection box" % path.get_file())
	var friends: Array[RTSUnit] = field.units_of(0)
	var picked: RTSUnit = field.select_click(_proj(friends[0].global_position), Callable(self, "_proj"))
	check(picked == friends[0] and field.selection.count() == 1, "%s left click selects" % path.get_file())
	var step: Vector3 = grid.cell_center(move_cell)
	var moved: StringName = field.command_at(step, _proj(step), Callable(self, "_proj"))
	check(moved == &"move" and friends[0].is_moving(), "%s right click moves" % path.get_file())
	var foes: Array[RTSUnit] = field.units_of(1)
	var attacked: StringName = field.command_at(foes[0].global_position, _proj(foes[0].global_position), Callable(self, "_proj"))
	check(attacked == &"attack" and friends[0].attack_target == foes[0], "%s right click attacks" % path.get_file())
	check(bool(scene.call("fire_ability")), "%s F fires the ability" % path.get_file())
	check(field.count_team(1) >= 1 and str(scene.get("map_id")) != "", "%s is GTFC versus one enemy" % path.get_file())
	scene.free()
	await process_frame

func _gtfc_names(field: SMPointer) -> bool:
	var names: PackedStringArray = PackedStringArray()
	for u: RTSUnit in field.units_of(0):
		names.append(field.name_of(u))
	for need: String in ["Militia", "Slag Hauler", "Ruby Lancer", "Amber Tank", "Monsoon Tube", "Channel Skiff"]:
		if not names.has(need):
			return false
	return true
