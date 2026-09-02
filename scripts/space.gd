class_name SpaceBackdrop
extends Node3D
## The island floats in space: additive starfield, nebula glows, three alien
## planets kept below the horizon, and recycled shooting stars.

var _planets: Array = []
var _moon_pivot: Node3D = null
var _shooters: Array = []
var _next_shooter := 0.0
var _time := 0.0
var _scale := 1.0
var _glow_tex: GradientTexture2D


func build(scale_v: float) -> void:
	_scale = scale_v
	_glow_tex = Models.radial_texture(Color.WHITE)
	_build_stars()
	_build_nebulae()
	_planet(5.5, 0x2fa4a0, 0x6ff5ee, Vector3(-30, -16, -32), 0x9fe8ff, false)
	_planet(3.2, 0x8a4fd8, 0xc39bff, Vector3(2, -8, -48), 0, true)
	_planet(2.1, 0xe06a4a, 0xffb08a, Vector3(14, -22, 36), 0, false)
	_next_shooter = 1.0


func _build_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = Models.quad(0.34 * _scale, 0.34 * _scale)
	mm.instance_count = 1400
	for i in mm.instance_count:
		var v := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized() * (50.0 + rng.randf() * 30.0) * _scale
		mm.set_instance_transform(i, Transform3D(Basis(), v))
		var hue := 0.55 + rng.randf() * 0.15 if rng.randf() < 0.75 else rng.randf()
		mm.set_instance_color(i, Color.from_hsv(hue, 0.6, 0.65 + rng.randf() * 0.3))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _glow_tex
	m.albedo_color = Color(1, 1, 1, 0.9)
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _build_nebulae() -> void:
	for n in [
		[Color(0.59, 0.31, 1.0, 0.8), Vector3(-45, -6, -35), 46.0],
		[Color(0.0, 0.86, 1.0, 0.7), Vector3(50, 4, -25), 38.0],
		[Color(1.0, 0.24, 0.75, 0.6), Vector3(8, -26, 50), 42.0],
	]:
		var col: Color = n[0]
		var tex := Models.radial_texture(col)
		var q := Models.mesh(Models.quad(1, 1), Models.glass(Color(1, 1, 1, 0.32), true, true, tex), 0, 0, 0, false)
		q.position = n[1] * _scale
		q.scale = Vector3.ONE * n[2] * _scale
		add_child(q)


func _planet(radius: float, color: int, glow_color: int, pos: Vector3, ring: int, moon: bool) -> void:
	var g := Node3D.new()
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Models.hex(color)
	body_mat.roughness = 0.75
	body_mat.metallic = 0.05
	body_mat.emission_enabled = true
	body_mat.emission = Models.hex(color)
	body_mat.emission_energy_multiplier = 0.35
	g.add_child(Models.mesh(Models.smooth_sphere(radius), body_mat, 0, 0, 0, false))
	var atmo := StandardMaterial3D.new()
	atmo.albedo_color = Models.hex(glow_color, 0.16)
	atmo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	atmo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	atmo.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	atmo.cull_mode = BaseMaterial3D.CULL_FRONT
	g.add_child(Models.mesh(Models.smooth_sphere(radius * 1.18), atmo, 0, 0, 0, false))
	if ring != 0:
		var r := Models.mesh(Models.torus(radius * 1.5, radius * 2.3), Models.glass(Models.hex(ring, 0.55), true), 0, 0, 0, false)
		r.scale = Vector3(1, 0.04, 1)
		r.rotation.x = PI / 2.4 - PI / 2.0
		g.add_child(r)
	if moon:
		var pivot := Node3D.new()
		var mm := StandardMaterial3D.new()
		mm.albedo_color = Models.hex(0xb9c2d4)
		mm.roughness = 1.0
		mm.emission_enabled = true
		mm.emission = Models.hex(0x8890a8)
		mm.emission_energy_multiplier = 0.3
		pivot.add_child(Models.mesh(Models.sphere(radius * 0.22, 10, 8), mm, radius * 2.1, 0, 0, false))
		g.add_child(pivot)
		_moon_pivot = pivot
	g.position = pos * _scale
	add_child(g)
	_planets.append(g)


func _spawn_shooter() -> void:
	var a := randf() * TAU
	var start := Vector3(cos(a) * 42.0, 16.0 + randf() * 18.0, sin(a) * 42.0) * _scale
	var end := Vector3(cos(a + 1.8) * 40.0, -4.0 - randf() * 8.0, sin(a + 1.8) * 40.0) * _scale
	var vel := (end - start).normalized() * 26.0 * _scale
	var head := Models.mesh(Models.quad(1.4 * _scale, 1.4 * _scale), Models.glass(Color(0.87, 0.94, 1.0, 1.0), true, true, _glow_tex), 0, 0, 0, false)
	head.position = start
	add_child(head)
	var trail := Models.mesh(Models.box(0.05 * _scale, 0.05 * _scale, 4.0 * _scale), Models.glass(Color(0.75, 0.88, 1.0, 0.7), true), 0, 0, 0, false)
	trail.transform = Transform3D(Basis.looking_at(vel.normalized()), start - vel.normalized() * 2.0 * _scale)
	add_child(trail)
	_shooters.append({"head": head, "trail": trail, "pos": start, "vel": vel, "life": 0.0})
	_next_shooter = _time + 1.8 + randf() * 5.2


func _process(delta: float) -> void:
	_time += delta
	if _moon_pivot != null:
		_moon_pivot.rotation.y += delta * 0.35
	for i in _planets.size():
		_planets[i].rotation.y += delta * (0.03 + i * 0.015)
	if _time >= _next_shooter:
		_spawn_shooter()
	var keep: Array = []
	for s in _shooters:
		s["life"] += delta
		s["pos"] += s["vel"] * delta
		var head: MeshInstance3D = s["head"]
		var trail: MeshInstance3D = s["trail"]
		head.position = s["pos"]
		var vn: Vector3 = s["vel"].normalized()
		trail.transform = Transform3D(Basis.looking_at(vn), s["pos"] - vn * 2.0 * _scale)
		if s["life"] > 2.6:
			head.queue_free()
			trail.queue_free()
		else:
			keep.append(s)
	_shooters = keep
