class_name AI
extends RefCounted
## Simple greedy opponent: research, harvest, train, then move every unit
## toward the nearest known enemy or neutral city, attacking whatever it can.

const UNIT_PREFS: Array = ["knight", "swordsman", "catapult", "rider", "archer", "defender", "warrior"]


func take_turn(g, p) -> void:
	_research(g, p)
	_train(g, p, true)
	_harvest(g, p)
	_train(g, p, false)
	for u in g.player_units(p.id):
		if g.over:
			return
		_act_unit(g, p, u)
	_train(g, p, false)
	_harvest(g, p)


# ---------------------------------------------------------------- economy

func _research(g, p) -> void:
	var avail: Array = g.available_techs(p.id)
	if avail.is_empty():
		return
	var best := ""
	var best_ratio := 0.0
	for tid in avail:
		var cost: int = g.tech_cost(p.id, tid)
		var ratio := _tech_value(g, p, tid) / float(cost)
		if ratio > best_ratio:
			best_ratio = ratio
			best = tid
	if best == "":
		return
	var c: int = g.tech_cost(p.id, best)
	if p.stars >= c and (p.stars - c >= 2 or g.rng.randf() < 0.4):
		g.research(p.id, best)


func _tech_value(g, p, tid: String) -> float:
	var counts := {Defs.Res.FRUIT: 0, Defs.Res.ANIMAL: 0, Defs.Res.FISH: 0, Defs.Res.METAL: 0, Defs.Res.CROP: 0}
	var forests := 0
	var mountains := 0
	var water := 0
	for row in g.tiles:
		for t in row:
			if t.owner_id() != p.id:
				continue
			if t.resource != Defs.Res.NONE:
				counts[t.resource] += 1
			if t.terrain == Defs.Terrain.FOREST:
				forests += 1
			elif t.terrain == Defs.Terrain.MOUNTAIN:
				mountains += 1
			elif t.is_water():
				water += 1
	match tid:
		"organization": return 1.0 + counts[Defs.Res.FRUIT] * 2.0
		"hunting": return 1.0 + counts[Defs.Res.ANIMAL] * 2.0
		"fishing": return 0.8 + counts[Defs.Res.FISH] * 2.0
		"farming": return 0.5 + counts[Defs.Res.CROP] * 2.5
		"mining": return 0.5 + counts[Defs.Res.METAL] * 2.5
		"climbing": return 1.0 + mountains * 0.8
		"forestry": return 0.5 + forests * 0.8
		"sailing": return 0.6 + water * 0.2
		"navigation": return 0.4 + water * 0.1
		"riding": return 2.5
		"archery": return 2.5
		"shields": return 1.5
		"smithery": return 3.0
		"chivalry": return 3.0
		"construction": return 2.5
	return 1.0


func _harvest(g, p) -> void:
	var progress := true
	while progress and p.stars > 0:
		progress = false
		var best_tile = null
		var best_act: Dictionary = {}
		var best_ratio := 0.0
		for row in g.tiles:
			for t in row:
				if t.owner_id() != p.id:
					continue
				for a in g.tile_actions(t, p.id):
					if a["pop"] <= 0 or a["cost"] > p.stars:
						continue
					var ratio := float(a["pop"]) / float(maxi(a["cost"], 1))
					if ratio > best_ratio:
						best_ratio = ratio
						best_tile = t
						best_act = a
		if best_tile != null:
			g.do_tile_action(best_tile, p.id, best_act["id"])
			progress = true


func _train(g, p, only_empty_cities: bool) -> void:
	var army: int = g.player_units(p.id).size()
	for c in g.player_cities(p.id):
		var garrison_empty: bool = g.tile_at(c.x, c.y).unit == null
		if only_empty_cities and (not garrison_empty or army >= 2 * g.num_cities(p.id)):
			continue
		if not only_empty_cities and army >= 8 and p.stars < 15:
			continue
		for type in UNIT_PREFS:
			var cost: int = Defs.UNITS[type]["cost"]
			if type != "warrior" and p.stars - cost < 2:
				continue
			if g.can_train(c, type) == "":
				g.train(c, type)
				army += 1
				break


# ---------------------------------------------------------------- units

func _act_unit(g, p, u) -> void:
	if not g.units.has(u):
		return
	if g.can_capture(u):
		g.capture(u)
		return
	var tg = _pick_target(g, u)
	if tg != null and g.preview_damage(u, tg)["kills"]:
		g.attack(u, tg)
		return
	if _should_hold(g, p, u):
		if tg != null:
			g.attack(u, tg)
		return
	var goal := _goal_for(g, p, u)
	var reach: Dictionary = g.reachable(u)
	if reach.size() > 0:
		var best: Vector2i = u.pos()
		var best_score := _move_score(g, p, u, best, goal)
		for pos in reach:
			var s := _move_score(g, p, u, pos, goal)
			if s > best_score:
				best_score = s
				best = pos
		if best != u.pos():
			g.move_unit(u, best.x, best.y)
	if not g.units.has(u):
		return
	tg = _pick_target(g, u)
	if tg != null:
		g.attack(u, tg)


func _pick_target(g, u):
	var best = null
	var best_score := -1.0
	for t in g.attack_targets(u):
		var pv: Dictionary = g.preview_damage(u, t)
		var s := float(pv["to_def"]) - float(pv["to_att"]) * 0.5
		if pv["kills"]:
			s += 20.0
		if s > best_score:
			best_score = s
			best = t
	return best


func _should_hold(g, p, u) -> bool:
	var t = g.tile_at(u.x, u.y)
	var enemy_near := false
	for other in g.units:
		if other.owner_id != p.id and Game.dist(other.pos(), u.pos()) <= 2:
			enemy_near = true
			break
	var on_own_city: bool = t.city != null and t.city.owner_id == p.id
	if u.type == "defender":
		if enemy_near:
			if not on_own_city:
				# Step back into the city if we can.
				for pos in g.reachable(u):
					var nt = g.tile_at(pos.x, pos.y)
					if nt.city != null and nt.city.owner_id == p.id:
						g.move_unit(u, pos.x, pos.y)
						break
			return true
		if on_own_city:
			# Free the city tile so the city can keep training.
			for pos in g.reachable(u):
				var nt = g.tile_at(pos.x, pos.y)
				if nt.owner_id() == p.id and nt.city == null and nt.is_land():
					g.move_unit(u, pos.x, pos.y)
					break
		return true
	return on_own_city and enemy_near


func _goal_for(g, p, u) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	for c in g.cities:
		if c.owner_id == p.id or not g.is_explored(p.id, c.x, c.y):
			continue
		var d: int = Game.dist(u.pos(), c.pos()) * 4 + (u.id + c.x * 3 + c.y) % 4
		if d < best_d:
			best_d = d
			best = c.pos()
	if best == Vector2i(-1, -1):
		for other in g.units:
			if other.owner_id != p.id and g.is_explored(p.id, other.x, other.y):
				var d2: int = Game.dist(u.pos(), other.pos())
				if d2 < best_d:
					best_d = d2
					best = other.pos()
	return best


func _move_score(g, p, u, pos: Vector2i, goal: Vector2i) -> float:
	var s := 0.0
	var t = g.tile_at(pos.x, pos.y)
	if goal != Vector2i(-1, -1):
		s -= float(Game.dist(pos, goal)) * 10.0
	else:
		for nb in g.neighbors(pos.x, pos.y, 2):
			if not nb.explored[p.id]:
				s += 3.0
	if t.city != null and t.city.owner_id != p.id:
		s += 60.0
	if t.terrain == Defs.Terrain.FOREST or t.terrain == Defs.Terrain.MOUNTAIN:
		s += 1.5
	if u.attack_range() > 1:
		# Ranged units like to stay out of melee reach.
		for other in g.units:
			if other.owner_id != p.id and Game.dist(other.pos(), pos) <= 1:
				s -= 6.0
	s += g.rng.randf() * 0.5
	return s
