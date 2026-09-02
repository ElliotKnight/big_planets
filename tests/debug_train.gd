extends SceneTree

func _init() -> void:
	var g := Game.new()
	g.ai = AI.new()
	g.setup(16, Defs.Mode.DOMINATION, 3, 4242 + 16)
	var played := 0
	while not g.over and played < 80:
		g.ai.take_turn(g, g.players[0])
		while g.pending_levelups.size() > 0:
			g.choose_reward(g.pending_levelups[0]["options"][0]["id"])
		g.end_turn()
		played += 1
	for p in g.players:
		print(p.tribe_name, " stars=", p.stars)
		for c in g.player_cities(p.id):
			var t: Tile = g.tile_at(c.x, c.y)
			var occupant := "none" if t.unit == null else t.unit.type + " moved=" + str(t.unit.moved)
			print("  %s L%d cap=%d homed=%d occupant=%s warrior:'%s' knight:'%s'" % [c.city_name, c.level, c.unit_cap(), g.homed_count(c), occupant, g.can_train(c, "warrior"), g.can_train(c, "knight")])
		for u in g.player_units(p.id):
			print("    unit %s at %d,%d hp=%d home=%s" % [u.type, u.x, u.y, u.hp, u.home_city.city_name if u.home_city else "none"])
	quit()
