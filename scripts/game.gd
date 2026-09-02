class_name Game
extends RefCounted
## Rules engine: map state, turns, economy, movement, combat, capture,
## technology, level-ups, and win conditions. No rendering here.

signal changed
signal message(text: String)
signal level_up_pending
signal game_over(result: Dictionary)
# Presentation events (the view animates these; rules never depend on them).
signal unit_moved(u: Unit, path: Array)
signal unit_attacked(info: Dictionary)
signal unit_spawned(u: Unit)
signal city_captured(c: City, prev_owner: int, tiles: Array)
signal stars_gained(pid: int, amount: int, source: Vector2i)
signal tile_worked(t: Tile, pop: int)
signal tech_researched(pid: int, tech_id: String)
signal city_leveled(c: City)

var size: int = 12
var mode: int = Defs.Mode.DOMINATION
var turn_limit: int = 0
var tiles: Array = []      # tiles[y][x] -> Tile
var players: Array = []    # Player
var cities: Array = []     # City (includes neutral villages)
var units: Array = []      # Unit
var turn: int = 1
var current: int = 0
var over: bool = false
var result: Dictionary = {}
var pending_levelups: Array = []   # [{"city": City, "options": Array}] awaiting a human choice
var viewer: int = 0
var ai = null                      # AI controller, set by the scene
var rng := RandomNumberGenerator.new()

var _next_unit_id: int = 1
var _reach_prev: Dictionary = {}
var _city_names: Array = [
	"Lumen", "Kestrel", "Orrin", "Vale", "Tarn", "Solace", "Brindle", "Halcyon",
	"Marrow", "Quill", "Ashby", "Fenwick", "Ridley", "Corvan", "Nyx", "Pellam",
	"Ilsa", "Torvik", "Mabry", "Sorrel", "Wren", "Dunmore", "Elric", "Fallow",
]


# ---------------------------------------------------------------- setup

func setup(p_size: int, p_mode: int, num_ai: int, seed_val: int) -> void:
	size = p_size
	mode = p_mode
	turn_limit = Defs.PERFECTION_TURNS if mode == Defs.Mode.PERFECTION else 0
	rng.seed = seed_val
	var num_players := 1 + num_ai
	for i in num_players:
		var p := Player.new()
		p.id = i
		p.tribe_name = Defs.TRIBE_NAMES[i]
		p.color = Defs.PLAYER_COLORS[i]
		p.is_ai = i > 0
		players.append(p)

	var gen := MapGen.generate(size, num_players, rng.randi())
	tiles = gen["tiles"]
	for row in tiles:
		for t in row:
			t.explored.resize(num_players)
			t.explored.fill(false)

	for i in num_players:
		var cp: Vector2i = gen["capitals"][i]
		var c := _make_city(cp.x, cp.y, i, true)
		c.city_name = players[i].tribe_name
		claim_territory(c)
		reveal(i, cp.x, cp.y, 2)
		var u := _spawn_unit("warrior", i, cp.x, cp.y, c)
		u.moved = false
		u.attacked = false
	for vp in gen["villages"]:
		_make_city(vp.x, vp.y, -1, false)

	current = 0
	_begin_turn(players[0])


func _make_city(x: int, y: int, owner: int, capital: bool) -> City:
	var c := City.new()
	c.x = x
	c.y = y
	c.owner_id = owner
	c.is_capital = capital
	if _city_names.size() > 0:
		c.city_name = _city_names[rng.randi_range(0, _city_names.size() - 1)]
		_city_names.erase(c.city_name)
	var t := tile_at(x, y)
	t.terrain = Defs.Terrain.FIELD
	t.resource = Defs.Res.NONE
	t.improvement = Defs.Improvement.NONE
	t.city = c
	t.owner_city = c
	cities.append(c)
	return c


func _spawn_unit(type: String, owner: int, x: int, y: int, home: City) -> Unit:
	var u := Unit.new()
	u.id = _next_unit_id
	_next_unit_id += 1
	u.type = type
	u.owner_id = owner
	u.max_hp = int(Defs.UNITS[type]["hp"])
	u.hp = u.max_hp
	u.home_city = home
	u.moved = true
	u.attacked = true
	units.append(u)
	_place(u, x, y)
	unit_spawned.emit(u)
	return u


# ---------------------------------------------------------------- queries

func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < size and y < size


func tile_at(x: int, y: int) -> Tile:
	if not in_bounds(x, y):
		return null
	return tiles[y][x]


func neighbors(x: int, y: int, r: int = 1) -> Array:
	var out: Array = []
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx == 0 and dy == 0:
				continue
			var t := tile_at(x + dx, y + dy)
			if t != null:
				out.append(t)
	return out


static func dist(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func player_cities(pid: int) -> Array:
	return cities.filter(func(c): return c.owner_id == pid)


func player_units(pid: int) -> Array:
	return units.filter(func(u): return u.owner_id == pid)


func num_cities(pid: int) -> int:
	return player_cities(pid).size()


func homed_count(c: City) -> int:
	var n := 0
	for u in units:
		if u.home_city == c and u.owner_id == c.owner_id:
			n += 1
	return n


func income(pid: int) -> int:
	var s := 0
	for c in player_cities(pid):
		s += c.income()
	return s


func territory_count(pid: int) -> int:
	var n := 0
	for row in tiles:
		for t in row:
			if t.owner_id() == pid:
				n += 1
	return n


func is_explored(pid: int, x: int, y: int) -> bool:
	var t := tile_at(x, y)
	return t != null and t.explored[pid]


func reveal(pid: int, x: int, y: int, r: int) -> void:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var t := tile_at(x + dx, y + dy)
			if t != null:
				t.explored[pid] = true


func nearest_city(pid: int, pos: Vector2i) -> City:
	var best: City = null
	var best_d := 1 << 30
	for c in player_cities(pid):
		var d := dist(pos, c.pos())
		if d < best_d:
			best_d = d
			best = c
	return best


func current_player() -> Player:
	return players[current]


# ---------------------------------------------------------------- territory & population

func claim_territory(c: City) -> void:
	for dy in range(-c.border_radius, c.border_radius + 1):
		for dx in range(-c.border_radius, c.border_radius + 1):
			var t := tile_at(c.x + dx, c.y + dy)
			if t != null and t.owner_city == null:
				t.owner_city = c


func add_pop(c: City, n: int) -> void:
	c.pop += n
	while c.pop >= c.pop_needed():
		c.pop -= c.pop_needed()
		c.level += 1
		claim_territory(c)
		message.emit("%s grew to level %d!" % [c.city_name, c.level])
		city_leveled.emit(c)
		var options := Defs.level_rewards(c.level)
		if c.owner_id >= 0 and players[c.owner_id].is_ai:
			apply_reward(c, _ai_pick_reward(options))
		else:
			pending_levelups.append({"city": c, "options": options})
			level_up_pending.emit()


func _ai_pick_reward(options: Array) -> String:
	var prefs := ["workshop", "walls", "border_growth", "giant", "park", "pop_growth", "resources", "explorer"]
	for pref in prefs:
		for o in options:
			if o["id"] == pref:
				return pref
	return options[0]["id"]


## Applies the reward at the front of the pending queue (human choice).
func choose_reward(reward_id: String) -> void:
	if pending_levelups.is_empty():
		return
	var entry: Dictionary = pending_levelups.pop_front()
	apply_reward(entry["city"], reward_id)
	changed.emit()


func apply_reward(c: City, reward_id: String) -> void:
	var p: Player = players[c.owner_id]
	match reward_id:
		"workshop":
			c.has_workshop = true
		"explorer":
			reveal(c.owner_id, c.x, c.y, 4)
		"walls":
			c.has_walls = true
		"resources":
			p.stars += 5
			stars_gained.emit(c.owner_id, 5, c.pos())
		"border_growth":
			c.border_radius = maxi(c.border_radius, 2)
			claim_territory(c)
		"pop_growth":
			add_pop(c, 3)
		"park":
			c.parks += 1
		"giant":
			var spot := _free_land_near(c.x, c.y)
			if spot == Vector2i(-1, -1):
				p.stars += 5
				message.emit("No room for a Giant near %s; +5 stars instead." % c.city_name)
			else:
				_spawn_unit("giant", c.owner_id, spot.x, spot.y, c)
	message.emit("%s chose %s." % [c.city_name, reward_id.replace("_", " ")])


func _free_land_near(x: int, y: int) -> Vector2i:
	var here := tile_at(x, y)
	if here.unit == null:
		return Vector2i(x, y)
	for t in neighbors(x, y):
		if t.unit == null and t.is_land() and t.terrain != Defs.Terrain.MOUNTAIN:
			return t.pos()
	return Vector2i(-1, -1)


# ---------------------------------------------------------------- technology

func tech_cost(pid: int, tech_id: String) -> int:
	return Defs.tech_cost(tech_id, num_cities(pid))


func available_techs(pid: int) -> Array:
	var p: Player = players[pid]
	var out: Array = []
	for tid in Defs.TECHS:
		if p.has_tech(tid):
			continue
		if p.has_tech(Defs.TECHS[tid]["requires"]):
			out.append(tid)
	return out


func can_research(pid: int, tech_id: String) -> bool:
	var p: Player = players[pid]
	if p.techs.has(tech_id):
		return false
	if not p.has_tech(Defs.TECHS[tech_id]["requires"]):
		return false
	return p.stars >= tech_cost(pid, tech_id)


func research(pid: int, tech_id: String) -> bool:
	if not can_research(pid, tech_id):
		return false
	var p: Player = players[pid]
	p.stars -= tech_cost(pid, tech_id)
	p.techs.append(tech_id)
	message.emit("%s researched %s." % [p.tribe_name, Defs.TECHS[tech_id]["name"]])
	tech_researched.emit(pid, tech_id)
	changed.emit()
	return true


# ---------------------------------------------------------------- tile actions (harvest / build)

func tile_actions(t: Tile, pid: int) -> Array:
	var acts: Array = []
	if t == null or t.owner_id() != pid or t.city != null:
		return acts
	var p: Player = players[pid]
	var no_imp := t.improvement == Defs.Improvement.NONE
	match t.resource:
		Defs.Res.FRUIT:
			if p.has_tech("organization"):
				acts.append({"id": "harvest", "label": "Harvest fruit", "cost": 2, "pop": 1})
		Defs.Res.ANIMAL:
			if p.has_tech("hunting"):
				acts.append({"id": "harvest", "label": "Hunt animals", "cost": 2, "pop": 1})
		Defs.Res.FISH:
			if p.has_tech("fishing"):
				acts.append({"id": "harvest", "label": "Catch fish", "cost": 2, "pop": 1})
		Defs.Res.METAL:
			if p.has_tech("mining") and no_imp:
				acts.append({"id": "mine", "label": "Build mine", "cost": 5, "pop": 2})
		Defs.Res.CROP:
			if p.has_tech("farming") and no_imp:
				acts.append({"id": "farm", "label": "Build farm", "cost": 5, "pop": 2})
	if t.terrain == Defs.Terrain.FOREST and p.has_tech("forestry") and no_imp:
		if t.resource == Defs.Res.NONE:
			acts.append({"id": "lumber", "label": "Build lumber hut", "cost": 3, "pop": 1})
		acts.append({"id": "clear", "label": "Clear forest (+1 star)", "cost": 0, "pop": 0})
	if t.terrain == Defs.Terrain.FIELD and p.has_tech("forestry") and no_imp and t.resource == Defs.Res.NONE:
		acts.append({"id": "grow", "label": "Grow forest", "cost": 5, "pop": 0})
	return acts


func do_tile_action(t: Tile, pid: int, action_id: String) -> bool:
	var act: Dictionary = {}
	for a in tile_actions(t, pid):
		if a["id"] == action_id:
			act = a
	if act.is_empty():
		return false
	var p: Player = players[pid]
	if p.stars < act["cost"]:
		return false
	p.stars -= act["cost"]
	var c: City = t.owner_city
	match action_id:
		"harvest":
			t.resource = Defs.Res.NONE
		"mine":
			t.improvement = Defs.Improvement.MINE
		"farm":
			t.improvement = Defs.Improvement.FARM
		"lumber":
			t.improvement = Defs.Improvement.LUMBER_HUT
		"clear":
			t.terrain = Defs.Terrain.FIELD
			t.resource = Defs.Res.NONE
			p.stars += 1
			stars_gained.emit(pid, 1, t.pos())
		"grow":
			t.terrain = Defs.Terrain.FOREST
	tile_worked.emit(t, int(act["pop"]))
	if int(act["pop"]) > 0:
		message.emit("%s: +%d population for %s." % [act["label"], act["pop"], c.city_name])
		add_pop(c, int(act["pop"]))
	changed.emit()
	return true


# ---------------------------------------------------------------- training

## Returns "" if the city can train the unit, otherwise the reason it cannot.
func can_train(c: City, type: String) -> String:
	if c.owner_id < 0:
		return "Not your city"
	var p: Player = players[c.owner_id]
	var d: Dictionary = Defs.UNITS[type]
	if not p.has_tech(d["tech"]):
		return "Requires " + str(Defs.TECHS[d["tech"]]["name"])
	if p.stars < int(d["cost"]):
		return "Not enough stars"
	if tile_at(c.x, c.y).unit != null:
		return "City tile is occupied"
	if homed_count(c) >= c.unit_cap():
		return "City at unit capacity (%d)" % c.unit_cap()
	return ""


func train(c: City, type: String) -> bool:
	if can_train(c, type) != "":
		return false
	var p: Player = players[c.owner_id]
	p.stars -= int(Defs.UNITS[type]["cost"])
	_spawn_unit(type, c.owner_id, c.x, c.y, c)
	changed.emit()
	return true


# ---------------------------------------------------------------- movement

func _can_enter(u: Unit, t: Tile) -> bool:
	if t == null or t.unit != null:
		return false
	if not t.explored[u.owner_id]:
		return false
	var p: Player = players[u.owner_id]
	match t.terrain:
		Defs.Terrain.MOUNTAIN:
			return p.has_tech("climbing")
		Defs.Terrain.SHALLOW:
			return p.has_tech("sailing")
		Defs.Terrain.DEEP:
			return p.has_tech("navigation")
	return true


func _stops_movement(u: Unit, t: Tile, from_water: bool) -> bool:
	if t.terrain == Defs.Terrain.FOREST or t.terrain == Defs.Terrain.MOUNTAIN:
		return true
	if t.is_water() != from_water:
		return true  # embarking or landing ends the move
	for nb in neighbors(t.x, t.y):
		if nb.unit != null and nb.unit.owner_id != u.owner_id:
			return true  # zone of control
	return false


## All tiles the unit can move to this turn, mapped to step cost.
func reachable(u: Unit) -> Dictionary:
	var out: Dictionary = {}
	if u.moved or over:
		return out
	var start := u.pos()
	var from_water := tile_at(start.x, start.y).is_water()
	var mp := u.move_points()
	var best: Dictionary = {start: 0}
	var frontier: Array = [start]
	_reach_prev = {}
	while frontier.size() > 0:
		var pos: Vector2i = frontier.pop_front()
		var cost: int = best[pos]
		if cost >= mp:
			continue
		if pos != start and _stops_movement(u, tile_at(pos.x, pos.y), from_water):
			continue
		for nb in neighbors(pos.x, pos.y):
			var np: Vector2i = nb.pos()
			var nc := cost + 1
			if best.has(np) and best[np] <= nc:
				continue
			if not _can_enter(u, nb):
				continue
			best[np] = nc
			out[np] = nc
			_reach_prev[np] = pos
			frontier.append(np)
	return out


## Tile-by-tile path of the most recent reachable() query.
func path_to(u: Unit, dest: Vector2i) -> Array:
	var path: Array = []
	var cur := dest
	var start := u.pos()
	var guard := 0
	while cur != start and _reach_prev.has(cur) and guard < 64:
		path.push_front(cur)
		cur = _reach_prev[cur]
		guard += 1
	return path


func _place(u: Unit, x: int, y: int) -> void:
	var old := tile_at(u.x, u.y)
	if old != null and old.unit == u:
		old.unit = null
	var t := tile_at(x, y)
	u.x = x
	u.y = y
	t.unit = u
	if t.is_water():
		u.embarked = true
		u.vessel = "ship" if players[u.owner_id].has_tech("navigation") else "boat"
	else:
		u.embarked = false
	reveal(u.owner_id, x, y, 2 if t.terrain == Defs.Terrain.MOUNTAIN else 1)


func move_unit(u: Unit, x: int, y: int) -> bool:
	var r := reachable(u)
	if not r.has(Vector2i(x, y)):
		return false
	var path := path_to(u, Vector2i(x, y))
	_place(u, x, y)
	u.moved = true
	unit_moved.emit(u, path)
	changed.emit()
	return true


# ---------------------------------------------------------------- combat

func attack_targets(u: Unit) -> Array:
	var out: Array = []
	if u.attacked or over:
		return out
	for other in units:
		if other.owner_id == u.owner_id:
			continue
		if dist(u.pos(), other.pos()) <= u.attack_range() and is_explored(u.owner_id, other.x, other.y):
			out.append(other)
	return out


func defense_bonus(u: Unit) -> float:
	var t := tile_at(u.x, u.y)
	var p: Player = players[u.owner_id]
	if t.city != null and t.city.owner_id == u.owner_id:
		return 4.0 if t.city.has_walls else 1.5
	if t.terrain == Defs.Terrain.FOREST and p.has_tech("archery"):
		return 1.5
	if t.terrain == Defs.Terrain.MOUNTAIN:
		return 1.5
	return 1.0


## Damage both sides would take. Retaliation only happens if the defender
## survives and can reach the attacker.
func preview_damage(u: Unit, target: Unit) -> Dictionary:
	var a_force := u.atk() * (float(u.hp) / float(u.max_hp))
	var d_force := target.defense() * (float(target.hp) / float(target.max_hp)) * defense_bonus(target)
	var total := a_force + d_force
	var to_def := 0
	var to_att := 0
	if total > 0.0:
		to_def = roundi(a_force / total * u.atk() * 4.5)
		to_att = roundi(d_force / total * target.defense() * 4.5)
	if u.atk() > 0.0:
		to_def = maxi(to_def, 1)
	var kills := to_def >= target.hp
	var d := dist(u.pos(), target.pos())
	if kills or d > target.attack_range():
		to_att = 0
	return {"to_def": to_def, "to_att": to_att, "kills": kills}


func attack(u: Unit, target: Unit) -> bool:
	if not attack_targets(u).has(target):
		return false
	var pv := preview_damage(u, target)
	var d := dist(u.pos(), target.pos())
	var attacker_name := "%s %s" % [players[u.owner_id].tribe_name, u.display_name()]
	var target_name := "%s %s" % [players[target.owner_id].tribe_name, target.display_name()]
	var msg := "%s hits %s for %d" % [attacker_name, target_name, pv["to_def"]]
	var info := {
		"attacker": u, "target": target, "from": u.pos(), "target_pos": target.pos(),
		"to_def": int(pv["to_def"]), "to_att": int(pv["to_att"]), "ranged": u.attack_range() > 1,
		"target_killed": false, "attacker_killed": false, "moved_to": Vector2i(-1, -1),
		"target_hp": 0, "attacker_hp": u.hp, "promoted": false,
	}
	u.attacked = true
	u.moved = true
	target.hp -= int(pv["to_def"])
	info["target_hp"] = maxi(target.hp, 0)
	if target.hp <= 0:
		var tx := target.x
		var ty := target.y
		_kill_unit(target)
		info["target_killed"] = true
		u.kills += 1
		msg += " and destroys it!"
		if not u.veteran and u.kills >= Defs.VETERAN_KILLS:
			u.veteran = true
			u.max_hp += Defs.VETERAN_HP_BONUS
			u.hp = u.max_hp
			info["promoted"] = true
			msg += " Promoted to veteran."
		if u.attack_range() == 1 and d == 1:
			var here := tile_at(u.x, u.y)
			var leaving_own_city := here.city != null and here.city.owner_id == u.owner_id
			if not leaving_own_city and _can_enter(u, tile_at(tx, ty)):
				_place(u, tx, ty)
				info["moved_to"] = Vector2i(tx, ty)
	elif int(pv["to_att"]) > 0:
		u.hp -= int(pv["to_att"])
		msg += "; %s retaliates for %d" % [target_name, pv["to_att"]]
		if u.hp <= 0:
			_kill_unit(u)
			info["attacker_killed"] = true
			msg += " and destroys it!"
	info["attacker_hp"] = maxi(u.hp, 0)
	if not msg.ends_with(".") and not msg.ends_with("!"):
		msg += "."
	unit_attacked.emit(info)
	message.emit(msg)
	changed.emit()
	return true


func _kill_unit(u: Unit) -> void:
	var t := tile_at(u.x, u.y)
	if t != null and t.unit == u:
		t.unit = null
	units.erase(u)


# ---------------------------------------------------------------- capture

func can_capture(u: Unit) -> bool:
	if over or u.moved or u.attacked or u.embarked:
		return false
	var t := tile_at(u.x, u.y)
	return t.city != null and t.city.owner_id != u.owner_id


func capture(u: Unit) -> bool:
	if not can_capture(u):
		return false
	var t := tile_at(u.x, u.y)
	var c: City = t.city
	var prev := c.owner_id
	var p: Player = players[u.owner_id]
	c.owner_id = u.owner_id
	if prev < 0:
		c.level = 1
		c.pop = 0
		c.border_radius = 1
		message.emit("%s captured the village of %s." % [p.tribe_name, c.city_name])
	else:
		message.emit("%s captured %s from %s!" % [p.tribe_name, c.city_name, players[prev].tribe_name])
	claim_territory(c)
	reveal(u.owner_id, c.x, c.y, 2)
	u.moved = true
	u.attacked = true
	var owned: Array = []
	for row in tiles:
		for tt in row:
			if tt.owner_city == c:
				owned.append(tt.pos())
	city_captured.emit(c, prev, owned)
	if prev >= 0:
		for ou in units:
			if ou.owner_id == prev and ou.home_city == c:
				ou.home_city = nearest_city(prev, ou.pos())
		_check_elimination(prev)
	_check_game_over()
	changed.emit()
	return true


func _check_elimination(pid: int) -> void:
	var p: Player = players[pid]
	if p.alive and num_cities(pid) == 0:
		p.alive = false
		for u in player_units(pid):
			_kill_unit(u)
		message.emit("%s has been eliminated!" % p.tribe_name)


# ---------------------------------------------------------------- turns

func _begin_turn(p: Player) -> void:
	p.stars += income(p.id)
	for c in player_cities(p.id):
		stars_gained.emit(p.id, c.income(), c.pos())
	for u in player_units(p.id):
		u.moved = false
		u.attacked = false


func _finish_turn(p: Player) -> void:
	# Units that rested all turn recover HP.
	for u in player_units(p.id):
		if u.moved or u.attacked or u.hp >= u.max_hp:
			continue
		var t := tile_at(u.x, u.y)
		var amount := Defs.HEAL_HOME if t.owner_id() == p.id else Defs.HEAL_AWAY
		u.hp = mini(u.max_hp, u.hp + amount)


func end_turn() -> void:
	if over:
		return
	if not pending_levelups.is_empty():
		message.emit("Choose a city reward before ending the turn.")
		changed.emit()
		return
	_finish_turn(players[current])
	var guard := 0
	while guard < players.size() * 2 + 2:
		guard += 1
		current = (current + 1) % players.size()
		if current == 0:
			turn += 1
			if turn_limit > 0 and turn > turn_limit:
				_finish_game(-1)
				return
		var p: Player = players[current]
		if not p.alive:
			continue
		_begin_turn(p)
		if p.is_ai and ai != null:
			ai.take_turn(self, p)
			if over:
				return
			_finish_turn(p)
			continue
		break
	changed.emit()


# ---------------------------------------------------------------- win conditions & score

func score(pid: int) -> int:
	var p: Player = players[pid]
	var s := 0
	for c in player_cities(pid):
		s += 100 * c.level + 250 * c.parks
		if c.has_walls:
			s += 50
		if c.has_workshop:
			s += 50
	s += 20 * territory_count(pid)
	for t in p.techs:
		s += 100 * int(Defs.TECHS[t]["tier"])
	for u in player_units(pid):
		s += 10 + 5 * int(Defs.UNITS[u.type]["cost"])
	return s


func _check_game_over() -> void:
	if over:
		return
	var alive := players.filter(func(p): return p.alive)
	if not players[0].alive:
		_finish_game(alive[0].id if alive.size() > 0 else -1)
	elif alive.size() == 1:
		_finish_game(alive[0].id)


func _finish_game(winner_id: int) -> void:
	over = true
	var scores: Dictionary = {}
	for p in players:
		scores[p.id] = score(p.id)
	if winner_id < 0 and mode == Defs.Mode.PERFECTION:
		# Turn limit reached: highest score wins.
		var best := -1
		for p in players:
			if p.alive and scores[p.id] > best:
				best = scores[p.id]
				winner_id = p.id
	result = {"winner": winner_id, "scores": scores, "turn": turn}
	game_over.emit(result)
	changed.emit()
