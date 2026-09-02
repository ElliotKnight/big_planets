class_name MapView3D
extends Node3D
## 3D presentation of the map: a floating low-poly island in space in the
## goodlife style. Tiles and units are rebuilt only when their state changes.
## Game events are queued and replayed as animations (so AI turns are visible);
## the full state sync is deferred until the queue drains.

const GRASS := [0x3fb268, 0x349b57]
const GHOST := Color(0.078, 0.078, 0.165, 0.72)

var game: Game = null
var ctrl = null
var hover: Vector2i = Vector2i(-1, -1)
var camera: Camera3D
var off: float = 0.0
var az: float = 0.55
var pol: float = 0.95
var dist: float = 14.0
var min_dist: float = 6.0
var max_dist: float = 40.0

var _dragging := false
var _drag_moved := false
var _down := Vector2.ZERO
var _last := Vector2.ZERO
var _tiles_root: Node3D
var _units_root: Node3D
var _fx_root: Node3D
var _anim_root: Node3D
var _tile_nodes: Dictionary = {}
var _tile_sigs: Dictionary = {}
var _units: Dictionary = {}
var _space: SpaceBackdrop
var _time := 0.0

# Animation replay queue
var animations_enabled := true
var _queue: Array = []
var _playing := false
var _dirty := false


func setup(g: Game, c) -> void:
	game = g
	ctrl = c
	off = (g.size - 1) / 2.0
	dist = g.size * 1.5 + 3.5
	min_dist = g.size * 0.45
	max_dist = g.size * 2.6
	var s := maxf(1.0, g.size / 8.0)
	_build_environment(s)
	_space = SpaceBackdrop.new()
	add_child(_space)
	_space.build(s)
	_tiles_root = Node3D.new()
	_units_root = Node3D.new()
	_fx_root = Node3D.new()
	_anim_root = Node3D.new()
	add_child(_tiles_root)
	add_child(_units_root)
	add_child(_fx_root)
	add_child(_anim_root)
	camera = Camera3D.new()
	camera.fov = 38.0
	camera.near = 0.1
	camera.far = 500.0
	add_child(camera)
	camera.current = true
	_apply_cam()
	game.unit_moved.connect(_on_unit_moved)
	game.unit_attacked.connect(_on_unit_attacked)
	game.unit_spawned.connect(_on_unit_spawned)
	game.city_captured.connect(_on_city_captured)
	game.tile_worked.connect(_on_tile_worked)
	game.city_leveled.connect(_on_city_leveled)
	game.stars_gained.connect(_on_stars_gained)
	refresh()


func world_pos(x: int, y: int) -> Vector3:
	return Vector3(x - off, 0.0, y - off)


func surface_y(t: Tile) -> float:
	if not t.explored[game.viewer]:
		return -0.02
	if t.terrain == Defs.Terrain.DEEP:
		return -0.15
	if t.terrain == Defs.Terrain.SHALLOW:
		return -0.08
	return 0.0


## Where a unit standing on a tile is drawn.
func unit_pos(pos: Vector2i) -> Vector3:
	var t := game.tile_at(pos.x, pos.y)
	var p := world_pos(pos.x, pos.y)
	if t == null:
		return p
	p.y = surface_y(t)
	if t.city != null:
		p += Vector3(0.0, 0.0, 0.36)
	elif t.terrain == Defs.Terrain.MOUNTAIN:
		p += Vector3(0.06, 0.07, 0.2)
	elif t.terrain == Defs.Terrain.FOREST:
		p += Vector3(-0.1, 0.0, 0.1) if t.resource == Defs.Res.ANIMAL else Vector3(0.04, 0.0, 0.06)
	return p


func is_animating() -> bool:
	return _playing or not _queue.is_empty()


func visible_to_viewer(pos: Vector2i) -> bool:
	var t := game.tile_at(pos.x, pos.y)
	return t != null and t.explored[game.viewer]


# ---------------------------------------------------------------- scene setup

func _build_environment(s: float) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = UITheme.BG
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Models.hex(0x9db4ff)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.15
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.0
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = Models.hex(0xfff2dd)
	sun.light_energy = 1.7
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0 * s
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.shadow_bias = 0.02
	add_child(sun)
	sun.look_at_from_position(Vector3(6, 9, 4) * s, Vector3.ZERO)

	var cyan := OmniLight3D.new()
	cyan.light_color = Models.hex(0x00f0ff)
	cyan.light_energy = 3.5
	cyan.omni_range = 22.0 * s
	cyan.omni_attenuation = 1.4
	cyan.position = Vector3(-7, 2.5, -5) * s
	add_child(cyan)
	var pink := OmniLight3D.new()
	pink.light_color = Models.hex(0xff3ec8)
	pink.light_energy = 2.6
	pink.omni_range = 22.0 * s
	pink.omni_attenuation = 1.4
	pink.position = Vector3(7, 2, 5) * s
	add_child(pink)


func _apply_cam() -> void:
	camera.position = Vector3(dist * sin(pol) * sin(az), dist * cos(pol), dist * sin(pol) * cos(az))
	camera.look_at(Vector3(0, 0.3, 0))


# ---------------------------------------------------------------- refresh

func refresh() -> void:
	if game == null:
		return
	if is_animating():
		_dirty = true
		return
	_sync_tiles()
	_sync_units()
	_sync_fx()


func _tile_sig(t: Tile) -> String:
	var c := t.city
	var city_s := "-"
	if c != null:
		city_s = "%d|%d|%d|%s|%s|%d|%s" % [c.owner_id, c.level, c.pop, c.has_walls, c.is_capital, c.parks, c.city_name]
	var nb := ""
	for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		var n := game.tile_at(t.x + d.x, t.y + d.y)
		nb += str(n.owner_id() if n != null else -2) + ","
	return "%s|%d|%d|%d|%d|%s|%s|%s" % [t.explored[game.viewer], t.terrain, t.resource, t.improvement, t.owner_id(), city_s, nb, t.unit != null]


func _sync_tiles() -> void:
	for y in game.size:
		for x in game.size:
			var t: Tile = game.tiles[y][x]
			var key := Vector2i(x, y)
			var sig := _tile_sig(t)
			if _tile_sigs.get(key, "") == sig:
				continue
			if _tile_nodes.has(key):
				_tile_nodes[key].queue_free()
			var n := _build_tile(t)
			n.position = world_pos(x, y)
			_tiles_root.add_child(n)
			_tile_nodes[key] = n
			_tile_sigs[key] = sig


## Registers a node for ambient animation on its tile node.
func _animate(tile_node: Node3D, node: Node3D, kind: String, phase: float) -> void:
	var list: Array = tile_node.get_meta("anims", [])
	list.append({"node": node, "kind": kind, "phase": phase, "base": node.rotation, "y": node.position.y})
	tile_node.set_meta("anims", list)


func _build_tile(t: Tile) -> Node3D:
	var g := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = t.x * 7919 + t.y * 104729 + 17
	if not t.explored[game.viewer]:
		g.add_child(Models.mesh(Models.box(1.0, 0.05, 1.0), Models.glass(GHOST), 0, -0.045, 0, false))
		_add_seams(g, -0.02)
		return g
	var oid := t.owner_id()
	var owner_col: Color = game.players[oid].color if oid >= 0 else Color.WHITE

	if t.is_water():
		var deep := t.terrain == Defs.Terrain.DEEP
		var top := -0.15 if deep else -0.08
		g.add_child(Models.mesh(Models.box(1.0, 0.18, 1.0), Models.mat(Models.hex(0x1a2a4a) if deep else Models.hex(0x4a3628), 1.0), 0, top - 0.17, 0))
		g.add_child(Models.mesh(Models.box(1.0, 0.08, 1.0), Models.water_mat(deep), 0, top - 0.04, 0))
		_add_seams(g, top)
		if t.resource == Defs.Res.FISH:
			var f1 := Models.fish(-0.12, 0.1, rng.randf() * TAU)
			f1.position.y = top + 0.03
			g.add_child(f1)
			_animate(g, f1, "fish", rng.randf() * TAU)
			var f2 := Models.fish(0.18, -0.15, rng.randf() * TAU)
			f2.position.y = top + 0.03
			f2.scale = Vector3.ONE * 0.8
			g.add_child(f2)
			_animate(g, f2, "fish", rng.randf() * TAU)
		_add_borders(g, t, oid, owner_col)
		return g

	# Land: checkerboard grass cap on a dirt base, tinted by the owner.
	var grass := Models.hex(GRASS[(t.x + t.y) % 2])
	if oid >= 0:
		grass = grass.lerp(owner_col, 0.28)
	g.add_child(Models.mesh(Models.box(1.0, 0.09, 1.0), Models.mat(grass, 0.85), 0, -0.045, 0))
	g.add_child(Models.mesh(Models.box(1.0, 0.22, 1.0), Models.mat(Models.hex(0x4a3628), 1.0), 0, -0.2, 0))
	_add_seams(g, 0.0)
	var occupied := t.unit != null

	if t.city != null:
		_build_city(g, t, owner_col)
	elif t.terrain == Defs.Terrain.MOUNTAIN:
		var m := Models.mountain(rng, t.resource == Defs.Res.METAL and t.improvement == Defs.Improvement.NONE)
		m.position = Vector3(-0.08, 0, -0.16)
		m.scale = Vector3(0.88, 0.9, 0.82)
		g.add_child(m)
		# Flat rock ledge at the front where units stand.
		g.add_child(Models.mesh(Models.box(0.56, 0.07, 0.4), Models.mat(Models.hex(0x5a5652)), 0.06, 0.035, 0.22))
		if t.improvement == Defs.Improvement.MINE:
			var mine := Models.mine()
			mine.position = Vector3(-0.3, 0, 0.02)
			mine.scale = Vector3(0.8, 0.8, 0.8)
			mine.rotation.y = 0.5
			g.add_child(mine)
	elif t.terrain == Defs.Terrain.FOREST:
		var spots := [Vector2(-0.32, -0.26), Vector2(0.3, -0.3), Vector2(-0.02, -0.36)]
		var count := 3
		if t.improvement == Defs.Improvement.LUMBER_HUT:
			count = 2
		if t.resource == Defs.Res.ANIMAL:
			count = 0  # open pasture: sheep only, no trees
		for i in count:
			var r := rng.randf()
			var variant := 2 if r < 0.1 else (1 if r < 0.4 else 0)
			var tr := Models.tree(variant, 3 + rng.randi_range(0, 2), owner_col if oid >= 0 else Models.hex(0xffd166))
			var sp: Vector2 = spots[i] + Vector2(rng.randf_range(-0.03, 0.03), rng.randf_range(-0.03, 0.03))
			tr.position = Vector3(sp.x, 0, sp.y)
			tr.rotation.y = rng.randf() * TAU
			tr.scale = Vector3.ONE * rng.randf_range(0.78, 0.92) * (0.72 if occupied else 1.0)
			g.add_child(tr)
			_animate(g, tr, "tree", rng.randf() * TAU)
		if t.resource == Defs.Res.ANIMAL:
			for sp in [[0.7, 0.18, -0.2], [0.6, -0.26, -0.24], [0.55, 0.24, 0.26]]:
				var sh := Models.sheep(sp[0], sp[1], sp[2], rng.randf() * TAU)
				g.add_child(sh)
				_animate(g, sh, "sheep", rng.randf() * TAU)
		if t.improvement == Defs.Improvement.LUMBER_HUT:
			var hut := Models.lumber_hut()
			hut.position = Vector3(0.24, 0, 0.26)
			hut.scale = Vector3(0.8, 0.8, 0.8)
			g.add_child(hut)
	else:
		if t.improvement == Defs.Improvement.FARM:
			g.add_child(Models.farm())
		elif t.resource == Defs.Res.FRUIT:
			var b := Models.fruit_bush()
			b.position = Vector3(-0.26, 0, -0.22)
			b.rotation.y = rng.randf() * TAU
			g.add_child(b)
			_animate(g, b, "bush", rng.randf() * TAU)
			var b2 := Models.fruit_bush()
			b2.position = Vector3(0.28, 0, 0.2)
			b2.scale = Vector3(0.7, 0.7, 0.7)
			b2.rotation.y = rng.randf() * TAU
			g.add_child(b2)
			_animate(g, b2, "bush", rng.randf() * TAU)
		elif t.resource == Defs.Res.CROP:
			var cr := Models.crops(rng)
			g.add_child(cr)
			_animate(g, cr, "crops", rng.randf() * TAU)
	_add_borders(g, t, oid, owner_col)
	return g


func _build_city(g: Node3D, t: Tile, owner_col: Color) -> void:
	var c: City = t.city
	var accent := owner_col if not c.is_village() else Models.hex(0xffd166)
	var b := Models.city_building(c.level, accent, c.is_village(), c.is_capital and not c.is_village())
	g.add_child(b)
	if c.has_walls:
		g.add_child(Models.walls(accent))
	if not c.is_village():
		var bn := Models.banner(owner_col)
		bn.position = Vector3(-0.36, 0, 0.3)
		g.add_child(bn)
		_animate(g, bn, "banner", randf() * TAU)
	var label := Label3D.new()
	label.text = c.city_name if c.is_village() else "%s  %d" % [c.city_name, c.level]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 56
	label.pixel_size = 0.0038
	label.outline_size = 14
	label.modulate = Color.WHITE if not c.is_village() else Color(0.85, 0.85, 0.9)
	label.outline_modulate = Color(owner_col.darkened(0.6), 0.9) if not c.is_village() else Color(0, 0, 0, 0.8)
	label.no_depth_test = true
	label.position = Vector3(0, 1.05, 0)
	g.add_child(label)
	if not c.is_village():
		var bar := Models.mesh(Models.quad(0.6, 0.07), Models.bar_material(Models.hex(0xffd166)), 0, 0.9, 0, false)
		bar.material_override.set_shader_parameter("frac", float(c.pop) / float(c.pop_needed()))
		g.add_child(bar)


## Faint grid lines along the north and west edges (no gaps between tiles).
func _add_seams(g: Node3D, top: float) -> void:
	var m := Models.glass(Color(0.0, 0.0, 0.05, 0.28))
	g.add_child(Models.mesh(Models.box(1.0, 0.004, 0.022), m, 0, top + 0.003, -0.5, false))
	g.add_child(Models.mesh(Models.box(0.022, 0.004, 1.0), m, -0.5, top + 0.003, 0, false))


func _add_borders(g: Node3D, t: Tile, oid: int, owner_col: Color) -> void:
	if oid < 0:
		return
	var dirs := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	for side in 4:
		var d: Vector2i = dirs[side]
		var n := game.tile_at(t.x + d.x, t.y + d.y)
		if n != null and n.owner_id() == oid:
			continue
		var e := Models.border_edge(owner_col, side)
		e.position.y = surface_y(t) + 0.02
		g.add_child(e)


# ---------------------------------------------------------------- units

func _sync_units() -> void:
	var seen: Dictionary = {}
	for u in game.units:
		var t := game.tile_at(u.x, u.y)
		if not t.explored[game.viewer]:
			continue
		seen[u.id] = true
		var entry := _unit_entry(u, u.pos())
		entry["node"].position = unit_pos(u.pos())
		_update_unit_status(u, entry)
	for id in _units.keys():
		if not seen.has(id):
			_units[id]["node"].queue_free()
			_units.erase(id)


func _fig_sig(u: Unit) -> String:
	return "%s|%d|%s|%s|%s" % [u.type, u.owner_id, u.embarked, u.vessel, u.veteran]


## Returns the unit's visual entry, building it at spawn_at if needed.
func _unit_entry(u: Unit, spawn_at: Vector2i) -> Dictionary:
	var sig := _fig_sig(u)
	var entry: Dictionary = _units.get(u.id, {})
	if entry.is_empty() or entry["sig"] != sig:
		var old_pos := Vector3.INF
		if not entry.is_empty():
			old_pos = entry["node"].position
			entry["node"].queue_free()
		entry = _make_unit_node(u, sig)
		entry["node"].position = unit_pos(spawn_at) if old_pos == Vector3.INF else old_pos
		_units[u.id] = entry
	return entry


func _update_unit_status(u: Unit, entry: Dictionary, hp_override: int = -1) -> void:
	var hp := u.hp if hp_override < 0 else hp_override
	var frac := clampf(float(hp) / float(u.max_hp), 0.0, 1.0)
	var bar: MeshInstance3D = entry["bar"]
	bar.material_override.set_shader_parameter("frac", frac)
	var hp_col := Color(0.3, 0.9, 0.3) if frac > 0.5 else (Color(0.95, 0.8, 0.2) if frac > 0.25 else Color(0.95, 0.25, 0.2))
	bar.material_override.set_shader_parameter("fill", hp_col)
	var ring: MeshInstance3D = entry["ring"]
	var col: Color = game.players[u.owner_id].color
	var active: bool = u.owner_id == game.current and u.owner_id == game.viewer and not game.over
	if active and not u.attacked and not u.moved:
		ring.material_override = Models.glow(col, 1.6)
	elif active and not u.attacked:
		ring.material_override = Models.glow(col, 0.6)
	else:
		ring.material_override = Models.mat(col.darkened(0.55), 0.9)
	var label: Label3D = entry["label"]
	label.text = u.letter() + ("*" if u.veteran else "")
	label.modulate = Models.hex(0xffe14d) if (ctrl != null and ctrl.sel_unit == u) else Color.WHITE


func _make_unit_node(u: Unit, sig: String) -> Dictionary:
	var node := Node3D.new()
	var col: Color = game.players[u.owner_id].color
	var fig := Models.unit_figure(u.type, col, u.id, u.embarked, u.vessel)
	fig.rotation.y = (0.6 if u.owner_id == 0 else 2.7) - (PI / 2.0 if fig.get_meta("mounted", false) else 0.0)
	node.add_child(fig)
	var ring := Models.mesh(Models.torus(0.02, 0.24), Models.glow(col, 1.5), 0, 0.02, 0, false)
	ring.scale = Vector3(1, 0.35, 1)
	node.add_child(ring)
	var tall := 1.0 if u.type == "giant" else (0.8 if u.type in ["rider", "knight"] else 0.66)
	var bar := Models.mesh(Models.quad(0.44, 0.06), Models.bar_material(Color(0.3, 0.9, 0.3)), 0, tall, 0, false)
	node.add_child(bar)
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 64
	label.pixel_size = 0.0035
	label.outline_size = 16
	label.outline_modulate = Color(col.darkened(0.5), 0.95)
	label.no_depth_test = true
	label.position = Vector3(0, tall + 0.16, 0)
	node.add_child(label)
	_units_root.add_child(node)
	return {"node": node, "sig": sig, "bar": bar, "ring": ring, "label": label, "fig": fig, "phase": randf() * TAU, "tall": tall}


# ---------------------------------------------------------------- highlights

func _sync_fx() -> void:
	for ch in _fx_root.get_children():
		ch.queue_free()
	if ctrl == null:
		return
	for pos in ctrl.reach:
		_pad(pos, Models.hex(0x3eff9c))
	for tg in ctrl.targets:
		_pad(Vector2i(tg.x, tg.y), Models.hex(0xff5c8a))
	if ctrl.sel_tile != null:
		_frame(Vector2i(ctrl.sel_tile.x, ctrl.sel_tile.y), Models.hex(0xffe14d), 1.8, 0.05)
	if game.in_bounds(hover.x, hover.y) and game.tile_at(hover.x, hover.y).explored[game.viewer]:
		_frame(hover, Color(1, 1, 1, 0.7), 0.5, 0.03)


func _pad(pos: Vector2i, col: Color) -> void:
	var t := game.tile_at(pos.x, pos.y)
	if t == null:
		return
	var y := surface_y(t)
	var fill := Models.mesh(Models.box(0.96, 0.03, 0.96), Models.glass(Color(col.r, col.g, col.b, 0.42)), 0, 0.02, 0, false)
	var n := Node3D.new()
	n.position = world_pos(pos.x, pos.y) + Vector3(0, y, 0)
	n.add_child(fill)
	_frame_into(n, col, 1.4, 0.045)
	_fx_root.add_child(n)


func _frame(pos: Vector2i, col: Color, intensity: float, y_off: float) -> void:
	var t := game.tile_at(pos.x, pos.y)
	if t == null:
		return
	var n := Node3D.new()
	n.position = world_pos(pos.x, pos.y) + Vector3(0, surface_y(t), 0)
	_frame_into(n, col, intensity, y_off)
	_fx_root.add_child(n)


func _frame_into(n: Node3D, col: Color, intensity: float, y_off: float, material: Material = null) -> void:
	var m: Material = material
	if m == null:
		m = Models.glow(col, intensity) if intensity > 0.6 else Models.glass(col)
	for side in 4:
		var e := Models.mesh(Models.box(1.0, 0.035, 0.05) if side % 2 == 0 else Models.box(0.05, 0.035, 1.0), m, 0, y_off, 0, false)
		match side:
			0: e.position.z = -0.475
			1: e.position.x = 0.475
			2: e.position.z = 0.475
			3: e.position.x = -0.475
		n.add_child(e)


# ---------------------------------------------------------------- ambient animation

func _process(delta: float) -> void:
	if game == null:
		return
	_time += delta
	var t := _time
	for tn in _tile_nodes.values():
		if not tn.has_meta("anims"):
			continue
		for a in tn.get_meta("anims"):
			var n: Node3D = a["node"]
			if not is_instance_valid(n):
				continue
			var ph: float = a["phase"]
			var base: Vector3 = a["base"]
			match a["kind"]:
				"tree":
					n.rotation.z = base.z + sin(t * 1.4 + ph) * 0.045 + sin(t * 3.1 + ph * 2.0) * 0.012
					n.rotation.x = base.x + sin(t * 1.1 + ph * 1.3) * 0.03
				"bush", "crops":
					n.rotation.z = base.z + sin(t * 1.8 + ph) * 0.05
				"banner":
					n.rotation.y = base.y + sin(t * 2.4 + ph) * 0.25
				"fish":
					n.position.y = a["y"] + sin(t * 2.0 + ph) * 0.012
					n.rotation.y = base.y + sin(t * 1.3 + ph) * 0.35
				"sheep":
					var cycle := fmod(t * 0.5 + ph, 5.0)
					if cycle < 0.7:
						n.position.y = a["y"] + absf(sin(cycle / 0.7 * PI * 2.0)) * 0.07
					else:
						n.position.y = a["y"]
					n.rotation.y = base.y + sin(t * 0.4 + ph) * 0.4
	for entry in _units.values():
		var fig: Node3D = entry["fig"]
		if not is_instance_valid(fig) or entry.get("busy", false):
			continue
		var rig: Dictionary = fig.get_meta("rig", {})
		if rig.is_empty():
			continue
		var ph: float = entry["phase"]
		rig["torso"].scale = Vector3(1.0, 1.0 + sin(t * 2.0 + ph) * 0.025, 1.0)
		rig["head"].rotation.y = sin(t * 0.7 + ph) * 0.3
		rig["head"].rotation.x = sin(t * 1.1 + ph * 1.7) * 0.06
		if not fig.get_meta("mounted", false):
			rig["arm_l"].rotation.x = rig.get("arm_l_rest", 0.0) + sin(t * 1.3 + ph) * 0.09
			rig["arm_r"].rotation.x = -sin(t * 1.3 + ph) * 0.09


# ---------------------------------------------------------------- event queue

func _enqueue(step: Dictionary) -> void:
	if not animations_enabled:
		return
	_queue.append(step)
	if not _playing:
		_next_step()


func _next_step() -> void:
	if _queue.is_empty():
		_playing = false
		if _dirty:
			_dirty = false
			refresh()
		if ctrl != null:
			ctrl.on_animations_done()
		return
	_playing = true
	var step: Dictionary = _queue.pop_front()
	var speed := 1.0 if _queue.size() < 8 else 0.55
	match step["kind"]:
		"move": _play_move(step, speed)
		"attack": _play_attack(step, speed)
		"spawn": _play_spawn(step, speed)
		"capture": _play_capture(step, speed)
		"worked": _play_worked(step, speed)
		"levelup": _play_levelup(step, speed)
		"stars": _play_stars(step, speed)
		_: _next_step()


func _on_unit_moved(u: Unit, path: Array) -> void:
	if path.is_empty():
		return
	var start: Vector2i = game._reach_prev.get(path[0], path[0])
	if not (visible_to_viewer(start) or visible_to_viewer(u.pos())):
		return
	_enqueue({"kind": "move", "unit": u, "start": start, "path": path.duplicate()})


func _on_unit_attacked(info: Dictionary) -> void:
	if not (visible_to_viewer(info["from"]) or visible_to_viewer(info["target_pos"])):
		return
	_enqueue({"kind": "attack", "info": info})


func _on_unit_spawned(u: Unit) -> void:
	if _units_root == null or not visible_to_viewer(u.pos()):
		return
	_enqueue({"kind": "spawn", "unit": u, "pos": u.pos()})


func _on_city_captured(c: City, prev_owner: int, tiles: Array) -> void:
	if not visible_to_viewer(c.pos()):
		return
	_enqueue({"kind": "capture", "city": c, "prev": prev_owner, "tiles": tiles.duplicate(), "owner": c.owner_id})


func _on_tile_worked(t: Tile, pop: int) -> void:
	if not visible_to_viewer(t.pos()):
		return
	_enqueue({"kind": "worked", "pos": t.pos(), "pop": pop})


func _on_city_leveled(c: City) -> void:
	if not visible_to_viewer(c.pos()):
		return
	_enqueue({"kind": "levelup", "pos": c.pos(), "owner": c.owner_id, "level": c.level})


func _on_stars_gained(pid: int, amount: int, source: Vector2i) -> void:
	if pid != game.viewer or amount <= 0:
		return
	_enqueue({"kind": "stars", "amount": amount, "pos": source})


# ---------------------------------------------------------------- animation steps

func _face(fig: Node3D, dir: Vector3) -> void:
	if dir.length() > 0.001:
		fig.rotation.y = atan2(dir.x, dir.z) - (PI / 2.0 if fig.get_meta("mounted", false) else 0.0)


func _rig(entry: Dictionary) -> Dictionary:
	var fig: Node3D = entry["fig"]
	return fig.get_meta("rig", {}) if is_instance_valid(fig) else {}


## Walk cycle pose for phase k in [0, 1] over one tile.
func _walk_pose(entry: Dictionary, k: float) -> void:
	var rig := _rig(entry)
	if rig.is_empty():
		return
	var fig: Node3D = entry["fig"]
	if fig.get_meta("mounted", false):
		fig.position.y = absf(sin(k * TAU)) * 0.035
		rig["torso"].rotation.x = sin(k * TAU) * 0.08
		return
	var sw := sin(k * TAU)
	rig["leg_l"].rotation.x = sw * 0.8
	rig["leg_r"].rotation.x = -sw * 0.8
	rig["arm_l"].rotation.x = -sw * 0.45
	rig["arm_r"].rotation.x = sw * 0.45
	rig["torso"].rotation.x = 0.12


func _rest_pose(entry: Dictionary) -> void:
	var rig := _rig(entry)
	if rig.is_empty():
		return
	var fig: Node3D = entry["fig"]
	fig.position.y = 0.0
	rig["torso"].rotation = Vector3.ZERO
	rig["torso"].scale = Vector3.ONE
	if not fig.get_meta("mounted", false):
		rig["leg_l"].rotation = Vector3.ZERO
		rig["leg_r"].rotation = Vector3.ZERO
	for a in ["arm_l", "arm_r"]:
		rig[a].rotation = Vector3(0, 0, rig[a].rotation.z)
	rig["arm_l"].rotation.x = rig.get("arm_l_rest", 0.0)
	Models.set_draw(rig, 0.0)
	if rig.has("bow"):
		rig["bow"]["arrow"].visible = true
	entry["busy"] = false


func _play_move(step: Dictionary, speed: float) -> void:
	var u: Unit = step["unit"]
	var entry := _unit_entry(u, step["start"])
	var node: Node3D = entry["node"]
	var fig: Node3D = entry["fig"]
	var tw := create_tween()
	var prev: Vector3 = unit_pos(step["start"])
	node.position = prev
	entry["busy"] = true
	Sfx.play("move", randf_range(0.9, 1.1))
	for pos in step["path"]:
		var to := unit_pos(pos)
		var a := prev
		var b := to
		tw.tween_callback(func(): _face(fig, b - a))
		tw.tween_method(func(k: float):
			node.position = a.lerp(b, k) + Vector3(0, sin(k * PI) * 0.05, 0)
			_walk_pose(entry, k), 0.0, 1.0, 0.3 * speed)
		prev = to
	tw.tween_callback(func():
		_rest_pose(entry)
		node.position = unit_pos(u.pos()) if game.units.has(u) else node.position)
	tw.tween_callback(_next_step)


func _float_text(at: Vector3, text: String, col: Color, size: int = 72) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = size
	l.pixel_size = 0.0038
	l.outline_size = 16
	l.modulate = col
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.no_depth_test = true
	l.position = at
	_anim_root.add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position", at + Vector3(0, 0.6, 0), 0.9).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.tween_callback(l.queue_free)


func _punch(node: Node3D) -> void:
	node.scale = Vector3(1.3, 0.75, 1.3)
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _burst(at: Vector3, col: Color, count: int = 10, radius: float = 0.6) -> void:
	for i in count:
		var s := Models.mesh(Models.sphere(0.035, 5, 4), Models.glow(col, 2.2), 0, 0, 0, false)
		s.position = at
		_anim_root.add_child(s)
		var dir := Vector3(randf_range(-1, 1), randf_range(0.3, 1.2), randf_range(-1, 1)).normalized() * radius * randf_range(0.5, 1.0)
		var tw := create_tween()
		tw.tween_property(s, "position", at + dir, 0.5).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(s, "scale", Vector3.ONE * 0.05, 0.5).set_ease(Tween.EASE_IN)
		tw.tween_callback(s.queue_free)


## Expanding neon ring on the ground, like goodlife's spawn FX.
func _ring_fx(at: Vector3, col: Color, radius: float = 0.9, dur: float = 0.8) -> void:
	var m := Models.glass(Color(col, 0.9), true).duplicate()
	var r := Models.mesh(Models.torus(0.03, 0.5), m, 0, 0.04, 0, false)
	r.position = at
	r.scale = Vector3(0.2, 0.3, 0.2)
	_anim_root.add_child(r)
	var tw := create_tween()
	tw.tween_property(r, "scale", Vector3(radius * 2.0, 0.3, radius * 2.0), dur).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, dur)
	tw.tween_callback(r.queue_free)


func _die(u: Unit, entry: Dictionary) -> void:
	var node: Node3D = entry["node"]
	var col: Color = game.players[u.owner_id].color
	_burst(node.position + Vector3(0, 0.25, 0), col, 12, 0.7)
	Sfx.play("death", randf_range(0.9, 1.1))
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector3(0.02, 0.02, 0.02), 0.3).set_ease(Tween.EASE_IN)
	tw.tween_callback(node.queue_free)
	_units.erase(u.id)


## Flying arrow along an arc; the model points along -y so we orient it to the tangent.
func _fly_arrow(from_w: Vector3, to_w: Vector3, dur: float, on_hit: Callable) -> void:
	var arrow := Models.arrow_model()
	arrow.scale = Vector3.ONE * 1.2
	_anim_root.add_child(arrow)
	var tw := create_tween()
	tw.tween_method(func(k: float):
		var up := Vector3(0, sin(k * PI) * 0.55, 0)
		var pos := from_w.lerp(to_w, k) + up
		var tangent := (to_w - from_w) + Vector3(0, PI * cos(k * PI) * 0.55, 0)
		arrow.transform = Transform3D(Basis(Quaternion(Vector3.DOWN, tangent.normalized())), pos), 0.0, 1.0, dur)
	tw.tween_callback(arrow.queue_free)
	tw.tween_callback(on_hit)


## Appends a shot to tween tw: archers draw and loose, catapults fling, others lob a bolt.
func _ranged_shot(tw: Tween, entry: Dictionary, from_w: Vector3, to_w: Vector3, col: Color, speed: float, on_hit: Callable) -> void:
	var rig := _rig(entry)
	var fig: Node3D = entry["fig"]
	if rig.has("bow"):
		var arm_l: Node3D = rig["arm_l"]
		var arm_r: Node3D = rig["arm_r"]
		tw.tween_property(arm_l, "rotation:x", -1.5, 0.24 * speed).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(arm_r, "rotation:x", -1.45, 0.24 * speed).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(arm_r, "rotation:y", 0.6, 0.24 * speed)
		tw.parallel().tween_property(rig["head"], "rotation:y", -0.35, 0.24 * speed)
		tw.tween_method(func(d: float):
			Models.set_draw(rig, d)
			arm_r.rotation.x = -1.45 + d * 0.5
			arm_r.rotation.y = 0.6 - d * 0.4, 0.0, 1.0, 0.34 * speed).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.14 * speed)
		tw.tween_callback(func():
			Models.set_draw(rig, 0.0)
			rig["bow"]["arrow"].visible = false
			var start: Vector3 = rig["bow"]["arrow"].global_position
			Sfx.play("select", 0.6)
			_fly_arrow(start, to_w + Vector3(0, 0.3, 0), 0.34 * speed, on_hit)
			arm_r.rotation.x = -1.2)
		tw.tween_interval(0.36 * speed)
		tw.tween_property(arm_l, "rotation:x", rig.get("arm_l_rest", 0.0), 0.3 * speed)
		tw.parallel().tween_property(arm_r, "rotation:x", 0.0, 0.3 * speed)
		tw.parallel().tween_property(arm_r, "rotation:y", 0.0, 0.3 * speed)
		tw.parallel().tween_property(rig["head"], "rotation:y", 0.0, 0.3 * speed)
		tw.tween_callback(func(): rig["bow"]["arrow"].visible = true)
		return
	var proj := Models.mesh(Models.sphere(0.06, 6, 5), Models.glow(col, 2.5), 0, 0, 0, false)
	var cat_arm: Node3D = fig.get_meta("catapult_arm", null)
	if cat_arm != null:
		proj = Models.mesh(Models.sphere(0.06, 7, 5), Models.mat(Models.hex(0x6e6a66)), 0, 0, 0, false)
		tw.tween_property(cat_arm, "rotation:z", -1.5, 0.12 * speed).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		proj.position = from_w + Vector3(0, 0.35, 0)
		_anim_root.add_child(proj))
	tw.tween_method(func(k: float): proj.position = from_w.lerp(to_w, k) + Vector3(0, 0.35 + sin(k * PI) * 0.7, 0), 0.0, 1.0, 0.4 * speed)
	tw.tween_callback(proj.queue_free)
	tw.tween_callback(on_hit)
	if cat_arm != null:
		tw.tween_property(cat_arm, "rotation:z", 0.0, 0.4 * speed)


## Appends a melee strike to tw: raise the weapon arm, lunge, chop, recover.
func _melee_strike(tw: Tween, entry: Dictionary, node: Node3D, from_w: Vector3, to_w: Vector3, speed: float, on_hit: Callable) -> void:
	var rig := _rig(entry)
	var arm: Node3D = rig.get("arm_r", null)
	if arm != null:
		tw.tween_property(arm, "rotation:x", -2.4, 0.14 * speed).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(node, "position", from_w.lerp(to_w, 0.42), 0.14 * speed).set_ease(Tween.EASE_IN)
		tw.tween_property(arm, "rotation:x", 0.6, 0.07 * speed).set_ease(Tween.EASE_IN)
	else:
		tw.tween_property(node, "position", from_w.lerp(to_w, 0.42), 0.14 * speed).set_ease(Tween.EASE_IN)
	tw.tween_callback(on_hit)
	tw.tween_property(node, "position", from_w, 0.2 * speed).set_ease(Tween.EASE_OUT)
	if arm != null:
		tw.parallel().tween_property(arm, "rotation:x", 0.0, 0.25 * speed)


func _play_attack(step: Dictionary, speed: float) -> void:
	var info: Dictionary = step["info"]
	var a: Unit = info["attacker"]
	var d: Unit = info["target"]
	var a_entry := _unit_entry(a, info["from"])
	var d_entry := _unit_entry(d, info["target_pos"])
	var a_node: Node3D = a_entry["node"]
	var d_node: Node3D = d_entry["node"]
	var a_fig: Node3D = a_entry["fig"]
	var d_fig: Node3D = d_entry["fig"]
	var from_w := unit_pos(info["from"])
	var to_w := unit_pos(info["target_pos"])
	a_node.position = from_w
	d_node.position = to_w
	_face(a_fig, to_w - from_w)
	_face(d_fig, from_w - to_w)
	a_entry["busy"] = true
	d_entry["busy"] = true
	var a_col: Color = game.players[a.owner_id].color
	var d_col: Color = game.players[d.owner_id].color
	var tw := create_tween()
	var hit := func():
		Sfx.play("hit", randf_range(0.85, 1.15))
		_punch(d_node)
		_float_text(to_w + Vector3(0, 0.9, 0), "-%d" % info["to_def"], Models.hex(0xff5c8a))
		_update_unit_status(d, d_entry, info["target_hp"])
		if info["target_killed"]:
			_die(d, d_entry)
	if info["ranged"]:
		_ranged_shot(tw, a_entry, from_w, to_w, a_col, speed, hit)
	else:
		_melee_strike(tw, a_entry, a_node, from_w, to_w, speed, hit)
	if info["to_att"] > 0:
		var retaliate := func():
			Sfx.play("hit", randf_range(0.8, 1.0))
			_punch(a_node)
			_float_text(from_w + Vector3(0, 0.9, 0), "-%d" % info["to_att"], Models.hex(0xffb340))
			_update_unit_status(a, a_entry, info["attacker_hp"])
			if info["attacker_killed"]:
				_die(a, a_entry)
		tw.tween_interval(0.1 * speed)
		if d.attack_range() > 1:
			_ranged_shot(tw, d_entry, to_w, from_w, d_col, speed, retaliate)
		else:
			_melee_strike(tw, d_entry, d_node, to_w, from_w, speed, retaliate)
	if info["moved_to"] != Vector2i(-1, -1):
		var dest := unit_pos(info["moved_to"])
		tw.tween_interval(0.2 * speed)
		tw.tween_callback(func(): _face(a_fig, dest - from_w))
		tw.tween_method(func(k: float):
			a_node.position = from_w.lerp(dest, k) + Vector3(0, sin(k * PI) * 0.05, 0)
			_walk_pose(a_entry, k), 0.0, 1.0, 0.3 * speed)
	if info["promoted"]:
		tw.tween_callback(func():
			_float_text(a_node.position + Vector3(0, 1.1, 0), "Veteran!", Models.hex(0xffe14d), 60)
			_ring_fx(a_node.position, Models.hex(0xffe14d), 0.7)
			Sfx.play("levelup", 1.2))
	tw.tween_interval(0.15 * speed)
	tw.tween_callback(func():
		if _units.has(a.id):
			_rest_pose(a_entry)
		if _units.has(d.id):
			_rest_pose(d_entry))
	tw.tween_callback(_next_step)


func _play_spawn(step: Dictionary, speed: float) -> void:
	var u: Unit = step["unit"]
	if not game.units.has(u):
		_next_step()
		return
	var entry := _unit_entry(u, step["pos"])
	var node: Node3D = entry["node"]
	node.position = unit_pos(step["pos"])
	_update_unit_status(u, entry)
	node.scale = Vector3(0.02, 0.02, 0.02)
	Sfx.play("spawn", randf_range(0.95, 1.05))
	_ring_fx(node.position, game.players[u.owner_id].color, 0.6, 0.6)
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector3.ONE, 0.6 * speed).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_interval(0.25 * speed)
	tw.tween_callback(_next_step)


func _play_capture(step: Dictionary, speed: float) -> void:
	var c: City = step["city"]
	var col: Color = game.players[step["owner"]].color
	_sync_tiles()
	var center := world_pos(c.x, c.y)
	Sfx.play("capture")
	_ring_fx(center, col, c.border_radius + 1.2, 1.1)
	_burst(center + Vector3(0, 0.4, 0), col, 16, 1.0)
	_float_text(center + Vector3(0, 1.3, 0), "Captured!", col, 64)
	# Every tile of the new territory flares with a glowing frame that fades.
	var m := Models.glow(col, 6.0).duplicate()
	m.emission_energy_multiplier = 6.0
	for pos in step["tiles"]:
		var t := game.tile_at(pos.x, pos.y)
		var n := Node3D.new()
		n.position = world_pos(pos.x, pos.y) + Vector3(0, surface_y(t), 0)
		_frame_into(n, col, 1.0, 0.05, m)
		var fill := Models.mesh(Models.box(0.96, 0.02, 0.96), Models.glass(Color(col, 0.0)).duplicate(), 0, 0.03, 0, false)
		n.add_child(fill)
		_anim_root.add_child(n)
		var delay := Game.dist(pos, c.pos()) * 0.12
		var ftw := create_tween()
		ftw.tween_interval(delay)
		ftw.tween_property(fill.material_override, "albedo_color:a", 0.55, 0.15)
		ftw.tween_property(fill.material_override, "albedo_color:a", 0.0, 1.0)
		ftw.tween_callback(n.queue_free)
	var tw := create_tween()
	tw.tween_property(m, "emission_energy_multiplier", 0.0, 1.6).set_ease(Tween.EASE_IN)
	var tile_node: Node3D = _tile_nodes.get(c.pos(), null)
	if tile_node != null:
		_punch(tile_node)
	var wait := create_tween()
	wait.tween_interval(0.8 * speed)
	wait.tween_callback(_next_step)


func _play_worked(step: Dictionary, speed: float) -> void:
	var pos: Vector2i = step["pos"]
	_sync_tiles()
	var at := world_pos(pos.x, pos.y)
	Sfx.play("pop", randf_range(0.95, 1.1))
	if step["pop"] > 0:
		_float_text(at + Vector3(0, 0.7, 0), "+%d pop" % step["pop"], Models.hex(0xffd166), 60)
	_burst(at + Vector3(0, 0.2, 0), Models.hex(0xffd166), 8, 0.4)
	var tile_node: Node3D = _tile_nodes.get(pos, null)
	if tile_node != null:
		_punch(tile_node)
	var tw := create_tween()
	tw.tween_interval(0.25 * speed)
	tw.tween_callback(_next_step)


func _play_levelup(step: Dictionary, speed: float) -> void:
	var pos: Vector2i = step["pos"]
	_sync_tiles()
	var at := world_pos(pos.x, pos.y)
	var col: Color = game.players[step["owner"]].color if step["owner"] >= 0 else Color.WHITE
	Sfx.play("levelup")
	_ring_fx(at, Models.hex(0xffe14d), 1.0, 0.9)
	_burst(at + Vector3(0, 0.5, 0), Models.hex(0xffe14d), 14, 0.8)
	_float_text(at + Vector3(0, 1.3, 0), "Level %d!" % step["level"], Models.hex(0xffe14d), 64)
	var tile_node: Node3D = _tile_nodes.get(pos, null)
	if tile_node != null:
		_punch(tile_node)
	var tw := create_tween()
	tw.tween_interval(0.5 * speed)
	tw.tween_callback(_next_step)


func _play_stars(step: Dictionary, speed: float) -> void:
	var pos: Vector2i = step["pos"]
	var screen := camera.unproject_position(world_pos(pos.x, pos.y) + Vector3(0, 0.5, 0))
	if ctrl != null:
		ctrl.play_star_flight(screen, step["amount"])
	var tw := create_tween()
	tw.tween_interval(0.12 * speed)
	tw.tween_callback(_next_step)


# ---------------------------------------------------------------- input & picking

func tile_from_screen(pos: Vector2) -> Vector2i:
	var from := camera.project_ray_origin(pos)
	var dir := camera.project_ray_normal(pos)
	if absf(dir.y) < 1e-5:
		return Vector2i(-1, -1)
	var t := -from.y / dir.y
	if t < 0.0:
		return Vector2i(-1, -1)
	var p := from + dir * t
	return Vector2i(roundi(p.x + off), roundi(p.z + off))


func set_hover(h: Vector2i) -> void:
	if h != hover:
		hover = h
		if not is_animating():
			_sync_fx()


func _unhandled_input(event: InputEvent) -> void:
	if game == null or camera == null:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				_drag_moved = false
				_down = event.position
				_last = event.position
			else:
				_dragging = false
				if not _drag_moved and ctrl != null:
					var tp := tile_from_screen(event.position)
					ctrl.on_tile_click(tp.x, tp.y, false)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and ctrl != null:
			var tp := tile_from_screen(event.position)
			ctrl.on_tile_click(tp.x, tp.y, true)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom(0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom(1.1)
	elif event is InputEventMouseMotion:
		if _dragging:
			if event.position.distance_to(_down) > 6.0:
				_drag_moved = true
			if _drag_moved:
				az -= (event.position.x - _last.x) * 0.006
				pol = clampf(pol - (event.position.y - _last.y) * 0.004, 0.35, 1.4)
				_apply_cam()
			_last = event.position
		else:
			set_hover(tile_from_screen(event.position))
	elif event is InputEventPanGesture:
		_zoom(1.0 + event.delta.y * 0.04)
	elif event is InputEventMagnifyGesture:
		_zoom(1.0 / event.factor)
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT:
				az += 0.12
				_apply_cam()
			KEY_RIGHT:
				az -= 0.12
				_apply_cam()
			KEY_UP:
				pol = clampf(pol - 0.08, 0.35, 1.4)
				_apply_cam()
			KEY_DOWN:
				pol = clampf(pol + 0.08, 0.35, 1.4)
				_apply_cam()
			KEY_MINUS:
				_zoom(1.15)
			KEY_EQUAL:
				_zoom(0.87)


func _zoom(factor: float) -> void:
	dist = clampf(dist * factor, min_dist, max_dist)
	_apply_cam()
