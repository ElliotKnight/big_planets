extends Node
## Scene controller: builds the neon glass HUD in code, owns selection state,
## and translates clicks into rules-engine calls. Rendering is MapView3D.

var game: Game = null
var ai := AI.new()
var map_view: MapView3D = null

# Selection
var sel_unit: Unit = null
var sel_tile: Tile = null
var reach: Dictionary = {}
var targets: Array = []
var log_lines: Array = []

# UI
var ui: CanvasLayer
var root: Control
var lbl_turn: Label
var lbl_player: Label
var lbl_stars: Label
var lbl_score: Label
var btn_tech: Button
var btn_end: Button
var side: GlassPanel
var side_title: Label
var side_info: Label
var side_actions: VBoxContainer
var log_label: Label
var dim: ColorRect
var modal_root: CenterContainer
var opt_mode: OptionButton
var opt_size: OptionButton
var spin_ai: SpinBox
var modal_kind: String = ""
var sfx: Sfx
var _shown_stars: int = 0
var _star_pending: int = 0
var _star_combo: int = 0
var _stars_in_flight: int = 0


## A little glowing star that flies from a city into the star counter.
class StarSprite extends Control:
	var col: Color = UITheme.ORANGE
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(24, 24)
		pivot_offset = Vector2(12, 12)
	func _draw() -> void:
		var pts := PackedVector2Array()
		for i in 10:
			var r := 11.0 if i % 2 == 0 else 4.8
			var a := -PI / 2.0 + i * PI / 5.0
			pts.append(Vector2(12, 12) + Vector2(cos(a), sin(a)) * r)
		var halo := PackedVector2Array()
		for i in 10:
			var r := 17.0 if i % 2 == 0 else 7.5
			var a := -PI / 2.0 + i * PI / 5.0
			halo.append(Vector2(12, 12) + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(halo, Color(col, 0.28))
		draw_colored_polygon(pts, Color(1.0, 0.88, 0.45))


func _ready() -> void:
	sfx = Sfx.new()
	add_child(sfx)
	_build_ui()
	if OS.get_environment("BP_SCREENSHOT") != "":
		await _debug_screenshots(OS.get_environment("BP_SCREENSHOT"))
		return
	_show_menu()


## Debug aid: plays a few turns automatically, reveals the map, and saves
## screenshots of the main view and the panels. Used from the terminal:
##   BP_SCREENSHOT=/path/prefix Godot --path . --windowed --resolution 1440x900
func _debug_screenshots(prefix: String) -> void:
	_start_game(Defs.Mode.PERFECTION, 12, 2)
	map_view.animations_enabled = false
	for i in 8:
		ai.take_turn(game, game.players[0])
		while not game.pending_levelups.is_empty():
			game.choose_reward(game.pending_levelups[0]["options"][0]["id"])
		_hide_modal()
		game.end_turn()
	map_view.animations_enabled = true
	for row in game.tiles:
		for t in row:
			t.explored[0] = true
	var mine := game.player_units(0)
	if not mine.is_empty():
		_select_unit(mine[0])
	_refresh()
	for i in 8:
		await get_tree().process_frame
	# Picking self-test: unproject a tile centre and pick it back.
	var probe := Vector2i(3, 4)
	var sp := map_view.camera.unproject_position(map_view.world_pos(probe.x, probe.y))
	print("pick test: tile %s -> screen %s -> tile %s" % [probe, sp, map_view.tile_from_screen(sp)])
	get_viewport().get_texture().get_image().save_png(prefix + "_map.png")
	_open_tech()
	for i in 6:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(prefix + "_tech.png")
	_hide_modal()
	game.pending_levelups.append({"city": game.player_cities(0)[0], "options": Defs.level_rewards(3)})
	_show_levelup()
	for i in 6:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(prefix + "_levelup.png")
	_hide_modal()
	map_view.dist *= 0.6
	map_view.pol = 0.8
	map_view._apply_cam()
	_clear_selection()
	sel_tile = game.tile_at(game.player_cities(0)[0].x, game.player_cities(0)[0].y)
	_refresh()
	for i in 6:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(prefix + "_close.png")
	# Unit showcase: one of each type in a row across varied terrain, close up.
	var cap: City = game.player_cities(0)[0]
	var types := ["warrior", "archer", "rider", "defender", "swordsman", "knight", "catapult", "giant"]
	var placed := 0
	map_view.animations_enabled = false
	var y0 := clampi(cap.y + 1, 0, game.size - 1)
	for x in range(clampi(cap.x - 4, 0, game.size - 1), game.size):
		if placed >= types.size():
			break
		var tt := game.tile_at(x, y0)
		if tt == null or tt.is_water() or tt.unit != null or tt.city != null:
			continue
		if tt.terrain == Defs.Terrain.FIELD and placed % 2 == 0 and tt.resource == Defs.Res.NONE:
			tt.terrain = Defs.Terrain.FOREST if placed % 4 == 0 else Defs.Terrain.MOUNTAIN
		game._spawn_unit(types[placed], 0, x, y0, cap)
		placed += 1
	map_view.animations_enabled = false
	_clear_selection()
	_refresh()
	map_view.az = 0.25
	map_view.pol = 1.05
	map_view.dist = 5.2
	map_view.focus_tile(cap.x, y0)
	for i in 8:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(prefix + "_units.png")
	# Forced archery shot so the draw-and-loose choreography can be inspected.
	for u in game.player_units(0):
		if u.type != "archer" or not map_view._units.has(u.id):
			continue
		var entry: Dictionary = map_view._units[u.id]
		var from_w: Vector3 = entry["node"].position
		var to_w := from_w + Vector3(-2.0, 0, 0.6)
		map_view._face(entry["fig"], to_w - from_w)
		entry["busy"] = true
		map_view.camera.position = from_w + Vector3(1.6, 1.1, 1.9)
		map_view.camera.look_at(from_w + Vector3(0, 0.35, 0))
		var tw := create_tween()
		map_view._ranged_shot(tw, entry, from_w, to_w, Color.WHITE, 1.0, func(): pass)
		await get_tree().create_timer(0.62).timeout
		get_viewport().get_texture().get_image().save_png(prefix + "_archer_draw.png")
		await get_tree().create_timer(0.24).timeout
		get_viewport().get_texture().get_image().save_png(prefix + "_archer_loose.png")
		await get_tree().create_timer(0.8).timeout
		map_view._rest_pose(entry)
		break
	map_view.animations_enabled = true
	map_view.dist = game.size * 1.15 + 3.0
	map_view.az = 0.55
	map_view.pol = 0.95
	map_view.set_focus(Vector3.ZERO)
	# Now play one turn with animations on and capture mid-replay.
	_clear_selection()
	map_view.dist *= 1.5
	map_view._apply_cam()
	ai.take_turn(game, game.players[0])
	while not game.pending_levelups.is_empty():
		game.choose_reward(game.pending_levelups[0]["options"][0]["id"])
	_hide_modal()
	game.end_turn()
	print("animation steps queued: ", map_view._queue.size() + 1)
	await get_tree().create_timer(1.2).timeout
	get_viewport().get_texture().get_image().save_png(prefix + "_anim.png")
	var waited := 0.0
	while map_view.is_animating() and waited < 40.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	print("animations finished after %.1f s, star pending=%d shown=%d actual=%d" % [waited, _star_pending, _shown_stars, game.players[0].stars])
	await get_tree().create_timer(1.5).timeout
	get_viewport().get_texture().get_image().save_png(prefix + "_after.png")
	get_tree().quit()


# ---------------------------------------------------------------- UI construction

func _label(text: String, size: int = 14, color: Color = UITheme.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	return b


func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.build()
	ui.add_child(root)

	# Status pill, top-left.
	var status := GlassPanel.new(10)
	root.add_child(status)
	status.position = Vector2(16, 16)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	status.add(hb)
	lbl_turn = _label("", 15)
	lbl_player = _label("", 15)
	lbl_stars = _label("", 15, UITheme.ORANGE)
	lbl_score = _label("", 15, UITheme.CYAN)
	var first := true
	for l in [lbl_turn, lbl_player, lbl_stars, lbl_score]:
		if not first:
			hb.add_child(_label("·", 15, UITheme.DIM))
		first = false
		hb.add_child(l)

	# Action buttons, top-right.
	var actions := GlassPanel.new(8)
	root.add_child(actions)
	actions.anchor_left = 1.0
	actions.anchor_right = 1.0
	actions.offset_left = -16
	actions.offset_right = -16
	actions.offset_top = 16
	actions.offset_bottom = 16
	actions.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	actions.grow_vertical = Control.GROW_DIRECTION_END
	var ab := HBoxContainer.new()
	ab.add_theme_constant_override("separation", 8)
	actions.add(ab)
	btn_tech = _button("Technology  (T)", _open_tech)
	btn_end = _button("End turn  (Space)", _end_turn)
	ab.add_child(btn_tech)
	ab.add_child(btn_end)

	# Selection panel, right.
	side = GlassPanel.new(14)
	root.add_child(side)
	side.anchor_left = 1.0
	side.anchor_right = 1.0
	side.anchor_top = 0.0
	side.anchor_bottom = 1.0
	side.offset_left = -336
	side.offset_right = -16
	side.offset_top = 78
	side.offset_bottom = -132
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 8)
	side.add(sv)
	side_title = _label("", 19, Color.WHITE)
	side_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sv.add_child(side_title)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sv.add_child(scroll)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 8)
	scroll.add_child(inner)
	side_info = _label("", 13)
	side_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side_info.custom_minimum_size.x = 280
	side_actions = VBoxContainer.new()
	side_actions.add_theme_constant_override("separation", 4)
	inner.add_child(side_info)
	inner.add_child(side_actions)

	# Brand, bottom-left.
	var brand := VBoxContainer.new()
	root.add_child(brand)
	brand.anchor_top = 1.0
	brand.anchor_bottom = 1.0
	brand.offset_left = 22
	brand.offset_right = 22
	brand.offset_top = -18
	brand.offset_bottom = -18
	brand.grow_horizontal = Control.GROW_DIRECTION_END
	brand.grow_vertical = Control.GROW_DIRECTION_BEGIN
	brand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := _label("BIG PLANETS", 30, UITheme.ORANGE)
	title.add_theme_color_override("font_outline_color", Color(1.0, 0.62, 0.16, 0.35))
	title.add_theme_constant_override("outline_size", 10)
	brand.add_child(title)
	brand.add_child(_label("turn-based 4X on a floating island", 11, UITheme.DIM))

	# Event log, bottom-centre.
	var log_panel := GlassPanel.new(10)
	root.add_child(log_panel)
	log_panel.anchor_top = 1.0
	log_panel.anchor_bottom = 1.0
	log_panel.anchor_left = 0.0
	log_panel.anchor_right = 1.0
	log_panel.offset_left = 290
	log_panel.offset_right = -352
	log_panel.offset_top = -118
	log_panel.offset_bottom = -16
	log_label = _label("", 12)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_panel.add(log_label)

	# Hint, bottom-right.
	var hint := _label("drag to orbit  ·  shift-drag / WASD to pan  ·  scroll to zoom  ·  C recentres  ·  Tab cycles units  ·  F11 fullscreen", 11, UITheme.DIM)
	root.add_child(hint)
	hint.anchor_left = 1.0
	hint.anchor_right = 1.0
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = -20
	hint.offset_right = -20
	hint.offset_top = -116
	hint.offset_bottom = -116
	hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE

	dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.visible = false

	modal_root = CenterContainer.new()
	root.add_child(modal_root)
	modal_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_root.visible = false


func _show_modal(panel: Control, kind: String) -> void:
	for c in modal_root.get_children():
		c.queue_free()
	modal_root.add_child(panel)
	modal_root.visible = true
	dim.visible = true
	modal_kind = kind


func _hide_modal() -> void:
	for c in modal_root.get_children():
		c.queue_free()
	modal_root.visible = false
	dim.visible = false
	modal_kind = ""


func _modal_panel(title: String) -> Array:
	var panel := GlassPanel.new(22, Color(0.05, 0.05, 0.1, 0.86), 18.0)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add(vb)
	vb.add_child(_label(title, 24, Color.WHITE))
	return [panel, vb]


# ---------------------------------------------------------------- menu / start

func _show_menu() -> void:
	var parts := _modal_panel("BIG PLANETS")
	var vb: VBoxContainer = parts[1]
	vb.add_child(_label("Grow cities, research, expand, conquer. A small fast 4X on a floating island in space.", 13, UITheme.DIM))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 10)
	vb.add_child(grid)

	grid.add_child(_label("Mode"))
	opt_mode = OptionButton.new()
	opt_mode.add_item("Domination - last tribe standing", Defs.Mode.DOMINATION)
	opt_mode.add_item("Perfection - best score after %d turns" % Defs.PERFECTION_TURNS, Defs.Mode.PERFECTION)
	grid.add_child(opt_mode)

	grid.add_child(_label("Map size"))
	opt_size = OptionButton.new()
	for s in [10, 12, 14, 16]:
		opt_size.add_item("%d x %d" % [s, s], s)
	opt_size.select(1)
	grid.add_child(opt_size)

	grid.add_child(_label("Opponents"))
	spin_ai = SpinBox.new()
	spin_ai.min_value = 1
	spin_ai.max_value = 3
	spin_ai.value = 2
	grid.add_child(spin_ai)

	var start := _button("Start game", _on_start_pressed)
	start.custom_minimum_size.y = 40
	vb.add_child(start)
	vb.add_child(_label("Click a unit to select it, click a green tile to move or a red unit to attack.\nClick tiles inside your borders to harvest. Click a city to train units.\nDrag to orbit the island, scroll to zoom. Right-click or Esc clears the selection.", 12, UITheme.DIM))
	_show_modal(parts[0], "menu")


func _on_start_pressed() -> void:
	_start_game(opt_mode.get_selected_id(), opt_size.get_selected_id(), int(spin_ai.value))


func _start_game(mode: int, size: int, num_ai: int) -> void:
	if map_view != null:
		map_view.queue_free()
	log_lines.clear()
	game = Game.new()
	game.ai = ai
	game.changed.connect(_on_changed)
	game.message.connect(_log)
	game.level_up_pending.connect(_on_levelup_pending)
	game.game_over.connect(_on_game_over)
	game.stars_gained.connect(_on_stars_gained)
	game.tech_researched.connect(func(pid: int, _tid: String):
		if pid == 0:
			Sfx.play("research"))
	game.setup(size, mode, num_ai, randi())
	_shown_stars = game.players[0].stars
	_star_pending = 0
	map_view = MapView3D.new()
	add_child(map_view)
	map_view.setup(game, self)
	_hide_modal()
	_clear_selection()
	if mode == Defs.Mode.PERFECTION:
		_log("Perfection: score as high as you can in %d turns." % Defs.PERFECTION_TURNS)
	else:
		_log("Domination: capture every rival capital to win.")
	_log("You are the %s tribe. Your warrior is ready." % game.players[0].tribe_name)
	_refresh()


# ---------------------------------------------------------------- selection & input

func _clear_selection() -> void:
	sel_unit = null
	sel_tile = null
	reach = {}
	targets = []


func _select_unit(u: Unit) -> void:
	sel_unit = u
	sel_tile = game.tile_at(u.x, u.y)
	reach = game.reachable(u)
	targets = game.attack_targets(u)


func on_animations_done() -> void:
	_refresh()


func on_tile_click(tx: int, ty: int, right: bool) -> void:
	if game == null or modal_root.visible or map_view.is_animating():
		return
	if right:
		_clear_selection()
		_refresh()
		return
	var t := game.tile_at(tx, ty)
	if t == null or not t.explored[0]:
		_clear_selection()
		_refresh()
		return
	var human_turn := game.current == 0 and not game.over
	if sel_unit != null and human_turn:
		var pos := Vector2i(tx, ty)
		if reach.has(pos):
			game.move_unit(sel_unit, tx, ty)
			_select_unit(sel_unit)
			_refresh()
			return
		for tg in targets:
			if tg.x == tx and tg.y == ty:
				var u := sel_unit
				game.attack(u, tg)
				if game.units.has(u):
					_select_unit(u)
				else:
					_clear_selection()
				_refresh()
				return
	if t.unit != null and t.unit.owner_id == 0 and human_turn and t.unit != sel_unit:
		_select_unit(t.unit)
		Sfx.play("select")
	else:
		sel_unit = null
		reach = {}
		targets = []
		sel_tile = t
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F11:
		var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	if game == null:
		return
	match event.keycode:
		KEY_ESCAPE:
			if modal_kind == "tech":
				_hide_modal()
			elif modal_kind == "":
				_clear_selection()
				_refresh()
		KEY_SPACE, KEY_ENTER:
			if modal_kind == "" and not map_view.is_animating():
				_end_turn()
		KEY_T:
			if modal_kind == "":
				_open_tech()
			elif modal_kind == "tech":
				_hide_modal()
		KEY_TAB:
			if modal_kind == "":
				_cycle_units()


func _cycle_units() -> void:
	if game.current != 0 or game.over:
		return
	var mine: Array = game.player_units(0).filter(func(u): return not u.attacked and (not u.moved or game.attack_targets(u).size() > 0))
	if mine.is_empty():
		_log("All units have acted.")
		return
	var idx := 0
	if sel_unit != null and mine.has(sel_unit):
		idx = (mine.find(sel_unit) + 1) % mine.size()
	_select_unit(mine[idx])
	map_view.focus_tile(sel_unit.x, sel_unit.y)
	_refresh()


# ---------------------------------------------------------------- actions

func _end_turn() -> void:
	if game == null or game.over or game.current != 0:
		return
	if not game.pending_levelups.is_empty():
		_log("Choose a city reward first.")
		Sfx.play("error")
		_refresh()
		return
	if map_view.is_animating():
		return
	_clear_selection()
	Sfx.play("turn")
	game.end_turn()
	if not game.over:
		_log("--- Turn %d. +%d stars." % [game.turn, game.income(0)])
	_refresh()


func _on_train(c: City, type: String) -> void:
	if not game.train(c, type):
		Sfx.play("error")
	sel_tile = game.tile_at(c.x, c.y)
	_refresh()


func _on_tile_action(t: Tile, action_id: String) -> void:
	if not game.do_tile_action(t, 0, action_id):
		Sfx.play("error")
	_refresh()


func _on_capture() -> void:
	if sel_unit != null:
		var u := sel_unit
		game.capture(u)
		_select_unit(u)
		_refresh()


func _on_research(tid: String) -> void:
	if not game.research(0, tid):
		Sfx.play("error")
	_open_tech()
	_refresh()


# ---------------------------------------------------------------- panels

func _open_tech() -> void:
	if game == null:
		return
	var p: Player = game.players[0]
	var parts := _modal_panel("Technology")
	var vb: VBoxContainer = parts[1]
	vb.add_child(_label("%d stars available. Costs rise with the number of cities you own (%d). Hover a node for details." % [p.stars, game.num_cities(0)], 13, UITheme.DIM))
	var desc := _label("Cyan: researched.  Purple: available now.  Grey: locked behind an earlier tech.", 13)
	desc.custom_minimum_size = Vector2(900, 22)
	var tree := TechTreePanel.new(game, self, desc)
	vb.add_child(tree)
	vb.add_child(desc)
	vb.add_child(_button("Close  (Esc)", _hide_modal))
	_show_modal(parts[0], "tech")


func _on_levelup_pending() -> void:
	if modal_kind != "levelup":
		_show_levelup()


func _show_levelup() -> void:
	if game.pending_levelups.is_empty():
		return
	var entry: Dictionary = game.pending_levelups[0]
	var c: City = entry["city"]
	var parts := _modal_panel("%s reached level %d" % [c.city_name, c.level])
	var vb: VBoxContainer = parts[1]
	vb.add_child(_label("Choose a reward:", 14, UITheme.DIM))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	vb.add_child(hb)
	for o in entry["options"]:
		var b := Button.new()
		b.custom_minimum_size = Vector2(230, 84)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.text = "%s\n%s" % [o["name"], o["desc"]]
		b.pressed.connect(_on_reward_chosen.bind(o["id"]))
		hb.add_child(b)
	_show_modal(parts[0], "levelup")


func _on_reward_chosen(reward_id: String) -> void:
	Sfx.play("select", 1.3)
	game.choose_reward(reward_id)
	_hide_modal()
	if not game.pending_levelups.is_empty():
		_show_levelup()
	_refresh()


func _on_game_over(res: Dictionary) -> void:
	var winner: int = res["winner"]
	var title := "Game over"
	if winner == 0:
		title = "Victory!"
	elif winner >= 0:
		title = "%s wins" % game.players[winner].tribe_name
	var parts := _modal_panel(title)
	var vb: VBoxContainer = parts[1]
	if game.mode == Defs.Mode.PERFECTION and game.turn > game.turn_limit:
		vb.add_child(_label("Turn limit reached. Your score: %d" % res["scores"][0], 16, UITheme.ORANGE))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 28)
	vb.add_child(grid)
	for h in ["Tribe", "Score", "Status"]:
		grid.add_child(_label(h, 13, UITheme.DIM))
	for p in game.players:
		grid.add_child(_label(p.tribe_name + (" (you)" if p.id == 0 else "")))
		grid.add_child(_label(str(res["scores"][p.id])))
		grid.add_child(_label("alive" if p.alive else "eliminated"))
	vb.add_child(_button("Back to menu", _show_menu))
	_show_modal(parts[0], "gameover")


# ---------------------------------------------------------------- refresh

func _log(text: String) -> void:
	log_lines.append(text)
	while log_lines.size() > 5:
		log_lines.pop_front()
	if log_label != null:
		log_label.text = "\n".join(log_lines)


func _on_changed() -> void:
	_refresh()


func _refresh() -> void:
	if game == null:
		return
	var p: Player = game.players[0]
	if game.turn_limit > 0:
		lbl_turn.text = "Turn %d / %d" % [game.turn, game.turn_limit]
	else:
		lbl_turn.text = "Turn %d" % game.turn
	lbl_player.text = "%s tribe" % p.tribe_name
	if _star_pending <= 0 or (_stars_in_flight == 0 and map_view != null and not map_view.is_animating()):
		_star_pending = 0
		_shown_stars = p.stars
	lbl_stars.text = "%d stars  (+%d)" % [_shown_stars, game.income(0)]
	lbl_score.text = "Score %d" % game.score(0)
	btn_end.disabled = game.over or game.current != 0 or (map_view != null and map_view.is_animating())
	_refresh_side()
	if map_view != null:
		map_view.refresh()


func _refresh_side() -> void:
	for c in side_actions.get_children():
		side_actions.remove_child(c)
		c.queue_free()
	var t := sel_tile
	if t == null:
		side_title.text = "Your empire"
		var idle := 0
		if not game.over and game.current == 0:
			for u in game.player_units(0):
				if not u.attacked and not u.moved:
					idle += 1
		side_info.text = "Select a tile, unit or city.\n\nUnits ready to act: %d\nCities: %d   Territory: %d tiles\nTechs: %d / %d" % [idle, game.num_cities(0), game.territory_count(0), game.players[0].techs.size(), Defs.TECHS.size()]
		return
	var lines: Array = []
	if t.city != null:
		var c: City = t.city
		side_title.text = c.city_name + (" (village)" if c.is_village() else "")
		if c.is_village():
			lines.append("Neutral village. Move a unit here and capture it next turn.")
		else:
			var owner: Player = game.players[c.owner_id]
			lines.append("Owner: %s%s" % [owner.tribe_name, " (capital)" if c.is_capital else ""])
			lines.append("Level %d   Population %d / %d" % [c.level, c.pop, c.pop_needed()])
			lines.append("Income: %d stars per turn" % c.income())
			lines.append("Units: %d / %d" % [game.homed_count(c), c.unit_cap()])
			var extras: Array = []
			if c.has_walls:
				extras.append("walls")
			if c.has_workshop:
				extras.append("workshop")
			if c.parks > 0:
				extras.append("%d park(s)" % c.parks)
			if c.border_radius > 1:
				extras.append("expanded borders")
			if not extras.is_empty():
				lines.append("Features: " + ", ".join(extras))
	else:
		side_title.text = t.describe()
		var oid := t.owner_id()
		lines.append("Territory of %s" % (game.players[oid].tribe_name if oid >= 0 else "nobody"))
	lines.append("Tile %d, %d" % [t.x, t.y])
	if t.unit != null:
		var u: Unit = t.unit
		lines.append("")
		lines.append("%s (%s)" % [u.display_name(), game.players[u.owner_id].tribe_name])
		lines.append("HP %d / %d   Attack %.1f   Defense %.1f" % [u.hp, u.max_hp, u.atk(), u.defense()])
		lines.append("Move %d   Range %d   Kills %d" % [u.move_points(), u.attack_range(), u.kills])
		var bonus := game.defense_bonus(u)
		if bonus > 1.0:
			lines.append("Defense bonus here: x%.1f" % bonus)
		if u.owner_id == 0:
			if u.attacked:
				lines.append("Status: done for this turn")
			elif u.moved:
				lines.append("Status: moved, can still attack")
			else:
				lines.append("Status: ready")
	side_info.text = "\n".join(lines)

	if game.over or game.current != 0:
		return
	var p: Player = game.players[0]
	if sel_unit != null and sel_unit == t.unit:
		if game.can_capture(sel_unit):
			side_actions.add_child(_button("Capture %s" % t.city.city_name, _on_capture))
		elif t.city != null and t.city.owner_id != 0 and (sel_unit.moved or sel_unit.attacked):
			side_actions.add_child(_label("Capture becomes available next turn.", 12, UITheme.DIM))
	if t.city != null and t.city.owner_id == 0:
		side_actions.add_child(_label("Train a unit", 14, Color.WHITE))
		for type in Defs.TRAINABLE:
			var d: Dictionary = Defs.UNITS[type]
			if not p.has_tech(d["tech"]):
				continue
			var b := Button.new()
			b.text = "%s - %d stars\nAtk %.1f  Def %.1f  HP %d  Move %d  Range %d" % [d["name"], d["cost"], d["atk"], d["def"], d["hp"], d["move"], d["range"]]
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.add_theme_font_size_override("font_size", 12)
			b.custom_minimum_size.x = 280
			var why := game.can_train(t.city, type)
			b.disabled = why != ""
			b.tooltip_text = why if why != "" else str(d["desc"])
			b.pressed.connect(_on_train.bind(t.city, type))
			side_actions.add_child(b)
	var acts := game.tile_actions(t, 0)
	if not acts.is_empty():
		side_actions.add_child(_label("Tile actions", 14, Color.WHITE))
		for a in acts:
			var label: String = a["label"]
			if int(a["pop"]) > 0:
				label += "  (+%d pop)" % a["pop"]
			label += "  %d stars" % a["cost"]
			var b := _button(label, _on_tile_action.bind(t, a["id"]))
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.add_theme_font_size_override("font_size", 12)
			b.custom_minimum_size.x = 280
			b.disabled = p.stars < int(a["cost"])
			side_actions.add_child(b)


# ---------------------------------------------------------------- star flight

func _on_stars_gained(pid: int, amount: int, _source: Vector2i) -> void:
	if pid != 0 or amount <= 0 or map_view == null or not map_view.animations_enabled:
		return
	if _star_pending <= 0:
		_shown_stars = game.players[0].stars - amount
	else:
		_shown_stars = mini(_shown_stars, game.players[0].stars - _star_pending - amount)
	_star_pending += amount
	lbl_stars.text = "%d stars  (+%d)" % [_shown_stars, game.income(0)]


## Spawns little stars at a screen position that fly into the star counter.
func play_star_flight(from_screen: Vector2, amount: int) -> void:
	var count := mini(amount, 6)
	var target := lbl_stars.get_global_rect().get_center()
	var per := int(ceil(float(amount) / float(count)))
	var remaining := amount
	for i in count:
		var s := StarSprite.new()
		root.add_child(s)
		s.position = from_screen - Vector2(12, 12) + Vector2(randf_range(-18, 18), randf_range(-14, 14))
		s.scale = Vector2(0.4, 0.4)
		var start := s.position
		var ctrl_pt := (start + target) * 0.5 + Vector2(randf_range(-80, 80), -160)
		var end := target - Vector2(12, 12)
		var share := mini(per, remaining)
		remaining -= share
		_stars_in_flight += 1
		var tw := create_tween()
		tw.tween_interval(0.08 * i)
		tw.tween_property(s, "scale", Vector2(1.1, 1.1), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_method(func(k: float):
			var u := 1.0 - k
			s.position = u * u * start + 2.0 * u * k * ctrl_pt + k * k * end
			s.rotation = k * 4.0, 0.0, 1.0, 0.62).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func(): _on_star_landed(s, share))


func _on_star_landed(s: Control, share: int) -> void:
	s.queue_free()
	_stars_in_flight = maxi(0, _stars_in_flight - 1)
	_star_combo = (_star_combo + 1) % 10
	Sfx.play("star", 1.0 + _star_combo * 0.05)
	_shown_stars += share
	_star_pending -= share
	if _star_pending <= 0:
		_star_pending = 0
		_star_combo = 0
		if game != null:
			_shown_stars = game.players[0].stars
	if game != null:
		lbl_stars.text = "%d stars  (+%d)" % [_shown_stars, game.income(0)]
	lbl_stars.pivot_offset = lbl_stars.size * 0.5
	lbl_stars.scale = Vector2(1.35, 1.35)
	var tw := create_tween()
	tw.tween_property(lbl_stars, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
