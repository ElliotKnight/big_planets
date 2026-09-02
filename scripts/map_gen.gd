class_name MapGen
extends RefCounted
## Procedural square map: an island-ish landmass with forests, mountains,
## shallow and deep water, plus capitals, villages and resources.


static func generate(size: int, num_players: int, seed_val: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var tiles: Array = []
	var capitals: Array = []
	for _attempt in 30:
		tiles = _gen_terrain(size, rng)
		var land := 0
		for row in tiles:
			for t in row:
				if t.is_land():
					land += 1
		if land < int(size * size * 0.5):
			continue
		capitals = _place_capitals(tiles, size, num_players, rng)
		if capitals.size() == num_players:
			break
	var villages := _place_villages(tiles, size, capitals, rng)
	_place_resources(tiles, size, capitals + villages, rng)
	return {"tiles": tiles, "capitals": capitals, "villages": villages}


static func _gen_terrain(size: int, rng: RandomNumberGenerator) -> Array:
	var height := FastNoiseLite.new()
	height.seed = rng.randi()
	height.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	height.frequency = 1.4 / float(size)
	height.fractal_octaves = 3
	var forest := FastNoiseLite.new()
	forest.seed = rng.randi()
	forest.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	forest.frequency = 2.6 / float(size)
	forest.fractal_octaves = 2
	var mountain := FastNoiseLite.new()
	mountain.seed = rng.randi()
	mountain.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	mountain.frequency = 2.2 / float(size)
	mountain.fractal_octaves = 2

	var tiles: Array = []
	var half := float(size) / 2.0
	for y in size:
		var row: Array = []
		for x in size:
			var t := Tile.new(x, y)
			var nx := (float(x) + 0.5 - half) / half
			var ny := (float(y) + 0.5 - half) / half
			var d := sqrt(nx * nx + ny * ny)
			var h := (height.get_noise_2d(float(x), float(y)) + 1.0) * 0.5
			h = h * 0.8 + 0.42 - d * 0.5
			if h < 0.30:
				t.terrain = Defs.Terrain.DEEP
			elif h < 0.42:
				t.terrain = Defs.Terrain.SHALLOW
			else:
				var f := (forest.get_noise_2d(float(x), float(y)) + 1.0) * 0.5
				var m := (mountain.get_noise_2d(float(x), float(y)) + 1.0) * 0.5
				if m > 0.70:
					t.terrain = Defs.Terrain.MOUNTAIN
				elif f > 0.53:
					t.terrain = Defs.Terrain.FOREST
				else:
					t.terrain = Defs.Terrain.FIELD
			row.append(t)
		tiles.append(row)
	# Deep water never touches land directly.
	for y in size:
		for x in size:
			var t: Tile = tiles[y][x]
			if t.terrain != Defs.Terrain.DEEP:
				continue
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var xx := x + dx
					var yy := y + dy
					if xx < 0 or yy < 0 or xx >= size or yy >= size:
						continue
					if tiles[yy][xx].is_land():
						t.terrain = Defs.Terrain.SHALLOW
	return tiles


static func _cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


static func _place_capitals(tiles: Array, size: int, n: int, rng: RandomNumberGenerator) -> Array:
	var candidates: Array = []
	for y in range(2, size - 2):
		for x in range(2, size - 2):
			var t: Tile = tiles[y][x]
			if t.is_land() and t.terrain != Defs.Terrain.MOUNTAIN:
				candidates.append(Vector2i(x, y))
	if candidates.size() < n:
		return []
	var chosen: Array = []
	var centre := Vector2(float(size) / 2.0, float(size) / 2.0)
	# First capital: somewhere away from the centre so rivals can spread out.
	var far: Array = candidates.filter(func(p): return Vector2(p).distance_to(centre) >= float(size) * 0.25)
	if far.is_empty():
		far = candidates
	chosen.append(far[rng.randi_range(0, far.size() - 1)])
	while chosen.size() < n:
		var best := Vector2i(-1, -1)
		var best_d := -1.0
		for p in candidates:
			var md := 1e9
			for c in chosen:
				md = minf(md, Vector2(p).distance_to(Vector2(c)))
			if md > best_d:
				best_d = md
				best = p
		if best_d < 3.0:
			return []
		chosen.append(best)
	# Make sure each capital sits on a field with usable land around it.
	for c in chosen:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var t: Tile = tiles[c.y + dy][c.x + dx]
				if dx == 0 and dy == 0:
					t.terrain = Defs.Terrain.FIELD
				elif t.is_water():
					t.terrain = Defs.Terrain.FIELD if rng.randf() < 0.7 else Defs.Terrain.FOREST
				elif t.terrain == Defs.Terrain.MOUNTAIN and rng.randf() < 0.5:
					t.terrain = Defs.Terrain.FOREST
	return chosen


static func _place_villages(tiles: Array, size: int, capitals: Array, rng: RandomNumberGenerator) -> Array:
	var target := maxi(3, int(size * size / 16))
	var candidates: Array = []
	for y in range(1, size - 1):
		for x in range(1, size - 1):
			var t: Tile = tiles[y][x]
			if not t.is_land() or t.terrain == Defs.Terrain.MOUNTAIN:
				continue
			var ok := true
			for c in capitals:
				if _cheb(Vector2i(x, y), c) < 3:
					ok = false
			if ok:
				candidates.append(Vector2i(x, y))
	var villages: Array = []
	while candidates.size() > 0 and villages.size() < target:
		var idx := rng.randi_range(0, candidates.size() - 1)
		var p: Vector2i = candidates[idx]
		candidates.remove_at(idx)
		var ok := true
		for v in villages:
			if _cheb(p, v) < 3:
				ok = false
		if ok:
			villages.append(p)
			tiles[p.y][p.x].terrain = Defs.Terrain.FIELD
	return villages


static func _place_resources(tiles: Array, size: int, city_spots: Array, rng: RandomNumberGenerator) -> void:
	for y in size:
		for x in size:
			var t: Tile = tiles[y][x]
			var p := Vector2i(x, y)
			if city_spots.has(p):
				continue
			var near := 1.0
			for c in city_spots:
				if _cheb(p, c) <= 2:
					near = 1.7
			var r := rng.randf()
			match t.terrain:
				Defs.Terrain.FIELD:
					if r < 0.22 * near:
						t.resource = Defs.Res.FRUIT
					elif r < (0.22 + 0.13) * near:
						t.resource = Defs.Res.CROP
				Defs.Terrain.FOREST:
					if r < 0.38 * near:
						t.resource = Defs.Res.ANIMAL
				Defs.Terrain.MOUNTAIN:
					if r < 0.45 * near:
						t.resource = Defs.Res.METAL
				Defs.Terrain.SHALLOW:
					if r < 0.32 * near:
						t.resource = Defs.Res.FISH
