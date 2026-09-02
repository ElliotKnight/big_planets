extends SceneTree
## Headless smoke test: builds a game, prints the map, and lets the AI play
## every side for a number of turns. Run with:
##   Godot --headless --path . --script tests/smoke.gd

const CH := {Defs.Terrain.FIELD: ".", Defs.Terrain.FOREST: "f", Defs.Terrain.MOUNTAIN: "^", Defs.Terrain.SHALLOW: "~", Defs.Terrain.DEEP: "#"}


func _init() -> void:
	_run(Defs.Mode.DOMINATION, 2, 12, 60)
	_run(Defs.Mode.PERFECTION, 1, 10, 60)
	_run(Defs.Mode.DOMINATION, 3, 16, 80)
	quit()


func _print_map(g: Game) -> void:
	for y in g.size:
		var line := ""
		for x in g.size:
			var t: Tile = g.tiles[y][x]
			if t.city != null:
				line += "V" if t.city.is_village() else str(t.city.owner_id)
			elif t.resource != Defs.Res.NONE:
				line += ["", "F", "A", "S", "M", "C"][t.resource].to_lower()
			else:
				line += CH[t.terrain]
		print(line)


func _run(mode: int, num_ai: int, size: int, max_turns: int) -> void:
	print("=== mode=%d ai=%d size=%d" % [mode, num_ai, size])
	var g := Game.new()
	g.ai = AI.new()
	var msgs := 0
	g.message.connect(func(t): msgs += 1)
	g.setup(size, mode, num_ai, 4242 + size)
	_print_map(g)
	var human: Player = g.players[0]
	var t0 := Time.get_ticks_msec()
	var played := 0
	while not g.over and played < max_turns:
		g.ai.take_turn(g, human)
		while g.pending_levelups.size() > 0:
			g.choose_reward(g.pending_levelups[0]["options"][0]["id"])
		g.end_turn()
		played += 1
	print("played %d turns in %d ms, game turn=%d over=%s result=%s messages=%d" % [played, Time.get_ticks_msec() - t0, g.turn, g.over, g.result, msgs])
	for p in g.players:
		print("  %s alive=%s cities=%d units=%d stars=%d score=%d techs=%s" % [p.tribe_name, p.alive, g.num_cities(p.id), g.player_units(p.id).size(), p.stars, g.score(p.id), p.techs])
	# Sanity: every unit sits on the tile that references it, and no tile references a dead unit.
	for u in g.units:
		assert(g.tile_at(u.x, u.y).unit == u, "unit/tile mismatch")
	for row in g.tiles:
		for t in row:
			if t.unit != null:
				assert(g.units.has(t.unit), "tile references dead unit")
	_print_map(g)
