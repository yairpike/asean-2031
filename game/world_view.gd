extends RefCounted
## Match presentation: props, fog sheet, sites, and decks. Sim scripts call this.

const Forms = preload("res://game/unit_meshes.gd")
const Ground = preload("res://game/ground_view.gd")
const Settings = preload("res://game/match_settings.gd")

static func sync(host: Node3D, sight: SMSight, cam: RTSCamera) -> void:
	paint_fog(sight, host)
	Ground.apply_sky(host, sight)
	Ground.cull_props(host, cam)
	quiet_crowd(host)

static func quiet_crowd(host: Node3D) -> void:
	if host == null:
		return
	var low: bool = Settings.low()
	var field: SMPointer = host.get("field") as SMPointer
	if field == null:
		return
	for u: RTSUnit in field.units:
		if not is_instance_valid(u):
			continue
		var body: MeshInstance3D = u.get_node_or_null("Body") as MeshInstance3D
		if body != null:
			var shadow: MeshInstance3D = body.get_node_or_null("ContactShadow") as MeshInstance3D
			if shadow != null:
				shadow.visible = not low
			body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if low else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var bar: MeshInstance3D = u.get_node_or_null("HealthBar") as MeshInstance3D
		if bar == null:
			continue
		if not low or u.selected or u.hp < u.max_hp - 0.4:
			bar.visible = true
		else:
			bar.visible = false

static func paint_fog(sight: SMSight, host: Node3D) -> void:
	if host == null or sight == null or sight.grid == null:
		return
	var grid: SMDomainGrid = sight.grid
	var hash: int = grid.cols * 1000 + grid.rows
	for row: int in grid.rows:
		for col: int in grid.cols:
			hash = hash * 33 + sight.cell_state(Vector2i(col, row))
	var veil: MeshInstance3D = host.get_node_or_null("FogVeil") as MeshInstance3D
	if veil == null:
		veil = MeshInstance3D.new()
		veil.name = "FogVeil"
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.vertex_color_use_as_albedo = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_color = Color.WHITE
		veil.material_override = mat
		veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		host.add_child(veil)
	if int(veil.get_meta("hash", -1)) == hash and veil.mesh != null:
		return
	veil.set_meta("hash", hash)
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hidden: Color = Color(0.03, 0.04, 0.05, 0.92)
	var dim: Color = Color(0.04, 0.05, 0.07, 0.42)
	var y: float = 0.42
	var half: float = grid.cell_size * 0.5
	for row: int in grid.rows:
		for col: int in grid.cols:
			var state: int = sight.cell_state(Vector2i(col, row))
			if state == SMSight.CLEAR:
				continue
			var ink: Color = hidden if state == SMSight.HIDDEN else dim
			var center: Vector3 = grid.cell_center(Vector2i(col, row))
			_quad(tool, center, half, y, ink)
	veil.mesh = tool.commit()

static func _quad(tool: SurfaceTool, center: Vector3, half: float, y: float, ink: Color) -> void:
	var a: Vector3 = Vector3(center.x - half, y, center.z - half)
	var b: Vector3 = Vector3(center.x + half, y, center.z - half)
	var c: Vector3 = Vector3(center.x + half, y, center.z + half)
	var d: Vector3 = Vector3(center.x - half, y, center.z + half)
	tool.set_color(ink)
	tool.add_vertex(a)
	tool.add_vertex(b)
	tool.add_vertex(c)
	tool.set_color(ink)
	tool.add_vertex(a)
	tool.add_vertex(c)
	tool.add_vertex(d)

static func place_site(host: Node3D, node_name: String, pos: Vector3, size: Vector3, color: Color, form: String) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	mi.position = pos
	if form != "":
		Ground.dress_site(mi, form, color)
	else:
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = size
		mi.mesh = mesh
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = color
		mi.material_override = mat
	host.add_child(mi)

static func sink_named(host: Node3D, node_name: String) -> void:
	if host == null:
		return
	var plate: MeshInstance3D = host.get_node_or_null(node_name) as MeshInstance3D
	if plate == null:
		return
	plate.position.y = -0.55
	var sunk: StandardMaterial3D = StandardMaterial3D.new()
	sunk.albedo_color = Color(0.08, 0.07, 0.06)
	plate.material_override = sunk

static func fit_deck(host: Node3D, deck_name: String, north_up: bool, south_up: bool) -> void:
	if host == null:
		return
	var deck: MeshInstance3D = host.get_node_or_null(deck_name) as MeshInstance3D
	if deck == null:
		return
	var box: BoxMesh = deck.mesh as BoxMesh
	if not north_up and not south_up:
		deck.visible = false
		return
	deck.visible = true
	if box == null:
		return
	var x: float = deck.position.x
	if north_up and south_up:
		deck.position = Vector3(x, 0.15, 0.0)
		box.size = Vector3(14.0, 0.28, 16.0)
	elif north_up:
		deck.position = Vector3(x, 0.15, -4.0)
		box.size = Vector3(14.0, 0.28, 8.0)
	else:
		deck.position = Vector3(x, 0.15, 4.0)
		box.size = Vector3(14.0, 0.28, 8.0)

static func slab(host: Node3D, node_name: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	mi.position = pos
	if not Forms.dress_structure(mi, size, color):
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = size
		mi.mesh = mesh
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = color
		mi.material_override = mat
	if host != null:
		host.add_child(mi)
	return mi

static func plain_slab(host: Node3D, node_name: String, at: Vector3, size: Vector3, color: Color) -> void:
	if host == null or host.get_node_or_null(node_name) != null:
		return
	var body: MeshInstance3D = MeshInstance3D.new()
	body.name = node_name
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	body.mesh = mesh
	body.position = at
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	body.material_override = mat
	host.add_child(body)

static func billboard(parent: Node3D, node_name: String, text: String, size: int, pixel: float, at: Vector3) -> void:
	if parent == null or parent.get_node_or_null(node_name) != null:
		return
	var tag: Label3D = Label3D.new()
	tag.name = node_name
	tag.text = text
	tag.font_size = size
	tag.pixel_size = pixel
	tag.position = at
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = Color(0.97, 0.94, 0.84)
	parent.add_child(tag)

static func dress_spawn(u: RTSUnit, team: int, label: String) -> void:
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.name = "Ring"
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.82
	torus.outer_radius = 1.05
	ring.mesh = torus
	ring.position = Vector3(0, 0.08, 0)
	var ring_mat: StandardMaterial3D = StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.95, 0.85, 0.35)
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = ring_mat
	ring.visible = false
	u.add_child(ring)
	var tag: Label3D = Label3D.new()
	tag.name = "NameTag"
	tag.text = label
	tag.font_size = 32
	tag.pixel_size = 0.008
	tag.outline_size = 8
	tag.outline_modulate = Color(0.02, 0.02, 0.03)
	tag.position = Vector3(0, 3.35, 0)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = Color(0.97, 0.94, 0.84)
	tag.visible = false
	u.add_child(tag)
	var bar: MeshInstance3D = MeshInstance3D.new()
	bar.name = "HealthBar"
	var slab_mesh: BoxMesh = BoxMesh.new()
	slab_mesh.size = Vector3(2.0, 0.16, 0.1)
	bar.mesh = slab_mesh
	bar.position = Vector3(0.0, 2.9, 0.0)
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ink: StandardMaterial3D = StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.albedo_color = Color(0.35, 0.82, 0.38) if team == 0 else Color(0.86, 0.24, 0.2)
	bar.material_override = ink
	u.add_child(bar)
	var muzzle: MeshInstance3D = MeshInstance3D.new()
	muzzle.name = "Muzzle"
	var flash: BoxMesh = BoxMesh.new()
	flash.size = Vector3(0.22, 0.22, 0.5)
	muzzle.mesh = flash
	muzzle.position = Forms.muzzle_pos(str(u.get_node("Body").get_meta("form", "truck")))
	muzzle.visible = false
	muzzle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var glow: StandardMaterial3D = StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.82, 0.35)
	muzzle.material_override = glow
	u.add_child(muzzle)
	var reach: MeshInstance3D = MeshInstance3D.new()
	reach.name = "RangeRing"
	var band: TorusMesh = TorusMesh.new()
	band.inner_radius = 0.92
	band.outer_radius = 1.0
	reach.mesh = band
	reach.position = Vector3(0.0, 0.06, 0.0)
	reach.visible = false
	reach.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var reach_ink: StandardMaterial3D = StandardMaterial3D.new()
	reach_ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	reach_ink.albedo_color = Color(0.95, 0.55, 0.22, 0.85)
	reach_ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	reach.material_override = reach_ink
	u.add_child(reach)

static func place_beacon(host: Node3D, at: Vector3) -> void:
	if host == null:
		return
	var pole: MeshInstance3D = host.get_node_or_null("GoalBeacon") as MeshInstance3D
	if at == Vector3.INF:
		if pole != null:
			pole.visible = false
		return
	if pole == null:
		pole = MeshInstance3D.new()
		pole.name = "GoalBeacon"
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(0.45, 7.0, 0.45)
		pole.mesh = box
		pole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var ink: StandardMaterial3D = StandardMaterial3D.new()
		ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ink.albedo_color = Color(0.98, 0.82, 0.28)
		pole.material_override = ink
		host.add_child(pole)
	var pulse: float = 1.0 + 0.12 * sin(float(Time.get_ticks_msec()) * 0.005)
	var y_scale: float = 1.0
	var cam: Camera3D = host.get_node_or_null("Camera") as Camera3D
	if cam != null and cam.get_viewport() != null:
		var view: Vector2 = cam.get_viewport().get_visible_rect().size
		var dist: float = cam.global_position.distance_to(Vector3(at.x, 3.6, at.z))
		var cap: float = view.y * 0.28
		y_scale = preload("res://game/camera_fit.gd").span(view, cam.fov, dist, 7.0, cap)
	pole.scale = Vector3(pulse, y_scale, pulse)
	if y_scale < 0.999:
		pole.position = Vector3(at.x, 0.1 + 3.5 * y_scale, at.z)
	else:
		pole.position = Vector3(at.x, 3.6, at.z)
	pole.visible = true

static func place_rally(host: Node3D, at: Vector3) -> void:
	if host == null or at == Vector3.INF:
		return
	var flag: MeshInstance3D = host.get_node_or_null("RallyFlag") as MeshInstance3D
	if flag == null:
		flag = MeshInstance3D.new()
		flag.name = "RallyFlag"
		var pole: BoxMesh = BoxMesh.new()
		pole.size = Vector3(0.08, 1.5, 0.08)
		flag.mesh = pole
		flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var ink: StandardMaterial3D = StandardMaterial3D.new()
		ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ink.albedo_color = Color(0.25, 0.85, 0.45)
		flag.material_override = ink
		var cloth: MeshInstance3D = MeshInstance3D.new()
		cloth.name = "RallyCloth"
		var sheet: BoxMesh = BoxMesh.new()
		sheet.size = Vector3(0.7, 0.38, 0.06)
		cloth.mesh = sheet
		cloth.position = Vector3(0.35, 0.5, 0.0)
		cloth.material_override = ink
		cloth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flag.add_child(cloth)
		host.add_child(flag)
	flag.position = Vector3(at.x, 0.8, at.z)
	flag.visible = true

static func path_mark(host: Node3D, show: bool, step: Vector3) -> void:
	if host == null:
		return
	var mark: MeshInstance3D = host.get_node_or_null("PathMark") as MeshInstance3D
	if not show:
		if mark != null:
			mark.visible = false
		return
	if mark == null:
		mark = MeshInstance3D.new()
		mark.name = "PathMark"
		var gem: BoxMesh = BoxMesh.new()
		gem.size = Vector3(0.55, 0.14, 0.55)
		mark.mesh = gem
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var ink: StandardMaterial3D = StandardMaterial3D.new()
		ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ink.albedo_color = Color(0.95, 0.82, 0.28)
		mark.material_override = ink
		host.add_child(mark)
	mark.position = Vector3(step.x, 0.22, step.z)
	mark.visible = true

static func wreck(host: Node3D, at: Vector3) -> MeshInstance3D:
	var body: MeshInstance3D = MeshInstance3D.new()
	body.name = "Wreck"
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = 0.7
	disc.bottom_radius = 0.7
	disc.height = 0.08
	body.mesh = disc
	body.position = Vector3(at.x, 0.08, at.z)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ink: StandardMaterial3D = StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.albedo_color = Color(0.15, 0.05, 0.04)
	body.material_override = ink
	if host != null:
		host.add_child(body)
	return body

static func order_ping(host: Node3D, at: Vector3, order: String) -> MeshInstance3D:
	var ping: MeshInstance3D = MeshInstance3D.new()
	ping.name = "OrderPing"
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = 0.55
	ring.outer_radius = 0.82
	ping.mesh = ring
	ping.position = Vector3(at.x, 0.15, at.z)
	ping.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ink: StandardMaterial3D = StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.albedo_color = Color(0.95, 0.28, 0.22) if order == "attack" else Color(0.95, 0.78, 0.28)
	ping.material_override = ink
	if host != null:
		host.add_child(ping)
	return ping

static func damage_pop(u: RTSUnit, amount: float) -> void:
	var pop: Label3D = u.get_node_or_null("DamagePop") as Label3D
	if pop == null:
		pop = Label3D.new()
		pop.name = "DamagePop"
		pop.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		pop.font_size = 64
		pop.pixel_size = 0.005
		pop.outline_size = 10
		pop.no_depth_test = true
		pop.position = Vector3(0.0, 2.4, 0.0)
		u.add_child(pop)
	pop.text = "-%d" % maxi(1, int(round(amount)))
	pop.modulate = Color(1.0, 0.45, 0.32, 1.0) if u.team == 0 else Color(1.0, 0.86, 0.35, 1.0)
	pop.position = Vector3(0.0, 2.4, 0.0)
	pop.visible = true
