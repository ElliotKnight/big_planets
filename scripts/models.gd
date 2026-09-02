class_name Models
extends RefCounted
## Low-poly mesh factory in the goodlife style: flat-shaded primitives,
## warm natural palette and neon emissive accents. Meshes and materials
## are cached so hundreds of tiles share resources.

static var _meshes: Dictionary = {}
static var _mats: Dictionary = {}
static var _bar_shader: Shader = null

const SKIN := [0xffd9b3, 0xf1c27d, 0xc68642, 0x8d5524]


static func hex(v: int, a: float = 1.0) -> Color:
	var c := Color.hex((v << 8) | 0xFF)
	c.a = a
	return c


# ---------------------------------------------------------------- geometry

static func _flat(m: Mesh) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.create_from(m, 0)
	st.deindex()
	st.generate_normals()
	return st.commit()


static func box(w: float, h: float, d: float) -> Mesh:
	var key := "box|%.3f|%.3f|%.3f" % [w, h, d]
	if not _meshes.has(key):
		var b := BoxMesh.new()
		b.size = Vector3(w, h, d)
		_meshes[key] = b
	return _meshes[key]


static func cyl(rt: float, rb: float, h: float, s: int = 8) -> Mesh:
	var key := "cyl|%.3f|%.3f|%.3f|%d" % [rt, rb, h, s]
	if not _meshes.has(key):
		var c := CylinderMesh.new()
		c.top_radius = rt
		c.bottom_radius = rb
		c.height = h
		c.radial_segments = s
		c.rings = 1
		_meshes[key] = _flat(c)
	return _meshes[key]


static func cone(r: float, h: float, s: int = 4) -> Mesh:
	return cyl(0.0, r, h, s)


static func sphere(r: float, w: int = 8, h: int = 6) -> Mesh:
	var key := "sph|%.3f|%d|%d" % [r, w, h]
	if not _meshes.has(key):
		var sm := SphereMesh.new()
		sm.radius = r
		sm.height = r * 2.0
		sm.radial_segments = w
		sm.rings = h
		_meshes[key] = _flat(sm)
	return _meshes[key]


static func smooth_sphere(r: float, w: int = 24, h: int = 18) -> Mesh:
	var key := "ssph|%.3f|%d|%d" % [r, w, h]
	if not _meshes.has(key):
		var sm := SphereMesh.new()
		sm.radius = r
		sm.height = r * 2.0
		sm.radial_segments = w
		sm.rings = h
		_meshes[key] = sm
	return _meshes[key]


static func quad(w: float, h: float) -> Mesh:
	var key := "quad|%.3f|%.3f" % [w, h]
	if not _meshes.has(key):
		var q := QuadMesh.new()
		q.size = Vector2(w, h)
		_meshes[key] = q
	return _meshes[key]


static func torus(inner: float, outer: float) -> Mesh:
	var key := "tor|%.3f|%.3f" % [inner, outer]
	if not _meshes.has(key):
		var t := TorusMesh.new()
		t.inner_radius = inner
		t.outer_radius = outer
		t.rings = 48
		t.ring_segments = 6
		_meshes[key] = t
	return _meshes[key]


# ---------------------------------------------------------------- materials

static func mat(color: Color, rough: float = 0.85, metal: float = 0.05) -> StandardMaterial3D:
	var key := "mat|%s|%.2f|%.2f" % [color.to_html(), rough, metal]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = rough
		m.metallic = metal
		_mats[key] = m
	return _mats[key]


static func glow(color: Color, intensity: float = 1.4) -> StandardMaterial3D:
	var key := "glow|%s|%.2f" % [color.to_html(), intensity]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = hex(0x111111)
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = intensity
		m.roughness = 0.6
		_mats[key] = m
	return _mats[key]


## Unshaded translucent material; additive when add is true.
static func glass(color: Color, add: bool = false, billboard: bool = false, tex: Texture2D = null) -> StandardMaterial3D:
	var key := "glass|%s|%s|%s|%s" % [color.to_html(), add, billboard, tex.get_instance_id() if tex != null else 0]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		if add:
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		if billboard:
			m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		if tex != null:
			m.albedo_texture = tex
		m.no_depth_test = false
		_mats[key] = m
	return _mats[key]


static func water_mat(deep: bool) -> StandardMaterial3D:
	var key := "water|%s" % deep
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = hex(0x1d4f9c) if deep else hex(0x2e7fd9)
		m.roughness = 0.2
		m.metallic = 0.15
		m.emission_enabled = true
		m.emission = hex(0x0d2c52) if deep else hex(0x14406e)
		m.emission_energy_multiplier = 0.5
		_mats[key] = m
	return _mats[key]


static func bar_material(fill: Color) -> ShaderMaterial:
	if _bar_shader == null:
		_bar_shader = load("res://shaders/bar.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _bar_shader
	m.set_shader_parameter("fill", fill)
	m.set_shader_parameter("frac", 1.0)
	return m


static func radial_texture(color: Color, size: int = 128) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, color)
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = size
	t.height = size
	return t


# ---------------------------------------------------------------- helpers

static func mesh(geo: Mesh, material: Material, x: float = 0.0, y: float = 0.0, z: float = 0.0, shadow: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = geo
	mi.material_override = material
	mi.position = Vector3(x, y, z)
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func group(x: float = 0.0, y: float = 0.0, z: float = 0.0) -> Node3D:
	var n := Node3D.new()
	n.position = Vector3(x, y, z)
	return n


# ---------------------------------------------------------------- nature

## Oak (0), pine (1) or cherry (2). Stage 1-7 grows it, like goodlife.
static func tree(variant: int, stage: int, accent: Color) -> Node3D:
	var g := Node3D.new()
	if variant == 1:
		var bark := mat(hex(0x5c3f28))
		var h := 0.18 + stage * 0.05
		g.add_child(mesh(cyl(0.035, 0.055, h, 7), bark, 0, h / 2.0, 0))
		var tiers := 2 + mini(stage, 4)
		for i in tiers:
			var f := float(i) / float(tiers)
			g.add_child(mesh(cone(0.2 * (1.0 - f * 0.72), 0.18, 7), mat(hex(0x2f7a4b) if i % 2 == 1 else hex(0x35895a)), 0, h + i * 0.11, 0))
		if stage >= 6:
			for i in 5:
				var a := i * 1.26
				g.add_child(mesh(sphere(0.024, 5, 4), glow(accent, 1.6), cos(a) * 0.13, h + 0.08 + i * 0.09, sin(a) * 0.13))
		return g
	var cherry := variant == 2
	var bark := mat(hex(0x5a3a30) if cherry else hex(0x6b4a2f))
	var leaf := mat(hex(0xf298c8) if cherry else hex(0x3d9e57))
	var leaf2 := mat(hex(0xe87fb8) if cherry else hex(0x349150))
	var h := 0.22 + stage * 0.07
	g.add_child(mesh(cyl(0.04, 0.065, h, 7), bark, 0, h / 2.0, 0))
	var r := 0.13 + stage * 0.028
	g.add_child(mesh(sphere(r), leaf, 0, h + r * 0.55, 0))
	if stage >= 2:
		g.add_child(mesh(sphere(r * 0.7, 7, 5), leaf2, r * 0.6, h + r * 0.3, r * 0.35))
	if stage >= 3:
		g.add_child(mesh(sphere(r * 0.65, 7, 5), leaf2, -r * 0.55, h + r * 0.45, -r * 0.4))
	if stage >= 4:
		g.add_child(mesh(sphere(r * 0.5, 7, 5), leaf, 0, h + r * 1.15, 0))
	if stage >= 6:
		for i in 5:
			var a := i * 1.26
			g.add_child(mesh(sphere(0.028, 5, 4), glow(accent, 1.6), cos(a) * r * 0.85, h + r * 0.55 + sin(a * 1.7) * r * 0.5, sin(a) * r * 0.85))
	return g


## Fruit: a squat bush with glowing berries.
static func fruit_bush() -> Node3D:
	var g := Node3D.new()
	var leaf := mat(hex(0x3d9e57))
	var leaf2 := mat(hex(0x349150))
	for i in 3:
		var a := i * 2.1
		g.add_child(mesh(sphere(0.11, 7, 5), leaf if i == 0 else leaf2, cos(a) * 0.12, 0.1, sin(a) * 0.12))
	var berry := [hex(0xff4d5a), hex(0xff8a3a), hex(0xff3e8e)]
	for i in 6:
		var a := i * 1.05 + 0.3
		g.add_child(mesh(sphere(0.028, 5, 4), glow(berry[i % 3], 1.5), cos(a) * 0.17, 0.12 + (i % 2) * 0.07, sin(a) * 0.17))
	return g


## Crops: rows of golden stalks.
static func crops(rng: RandomNumberGenerator) -> Node3D:
	var g := Node3D.new()
	var stalk := mat(hex(0xc9a341))
	var head := mat(hex(0xf2d06b))
	for i in 3:
		for j in 4:
			var x := -0.27 + i * 0.27 + rng.randf_range(-0.03, 0.03)
			var z := -0.3 + j * 0.2 + rng.randf_range(-0.03, 0.03)
			var h := 0.14 + rng.randf() * 0.06
			g.add_child(mesh(cyl(0.008, 0.012, h, 5), stalk, x, h / 2.0, z, false))
			g.add_child(mesh(sphere(0.02, 5, 4), head, x, h + 0.015, z, false))
	return g


static func farm() -> Node3D:
	var g := Node3D.new()
	var soil := mat(hex(0x6b4a2f))
	var ridge := mat(hex(0x7d5b3a))
	g.add_child(mesh(box(0.8, 0.03, 0.8), soil, 0, 0.015, 0))
	for i in 4:
		g.add_child(mesh(box(0.72, 0.05, 0.08), ridge, 0, 0.04, -0.3 + i * 0.2))
		for j in 5:
			g.add_child(mesh(sphere(0.03, 5, 4), mat(hex(0x8fd34a)), -0.28 + j * 0.14, 0.085, -0.3 + i * 0.2, false))
	return g


static func mountain(rng: RandomNumberGenerator, with_ore: bool) -> Node3D:
	var g := Node3D.new()
	var rock := mat(hex(0x6e6a66))
	var rock2 := mat(hex(0x5a5652))
	var snow := mat(hex(0xf2f2f6))
	var main := mesh(cone(0.42, 0.78, 5), rock, 0.02, 0.39, -0.02)
	main.rotation.y = rng.randf() * TAU
	g.add_child(main)
	var cap := mesh(cone(0.16, 0.3, 5), snow, 0.02, 0.63, -0.02)
	cap.rotation.y = main.rotation.y
	g.add_child(cap)
	var side := mesh(cone(0.24, 0.42, 5), rock2, 0.26, 0.21, 0.22)
	side.rotation.y = rng.randf() * TAU
	g.add_child(side)
	if with_ore:
		var crystal := glow(hex(0xd9e4ff), 1.3)
		for i in 3:
			var a := 1.0 + i * 2.0
			var cx := cos(a) * 0.3
			var cz := sin(a) * 0.3
			var c := mesh(cone(0.045, 0.16, 4), crystal, cx, 0.1, cz)
			c.rotation.z = rng.randf_range(-0.4, 0.4)
			g.add_child(c)
			var c2 := mesh(cone(0.045, 0.16, 4), crystal, cx, 0.02, cz)
			c2.rotation.x = PI
			c2.rotation.z = c.rotation.z
			g.add_child(c2)
	return g


static func sheep(scale_v: float, x: float, z: float, ry: float) -> Node3D:
	var g := Node3D.new()
	var wool := mat(hex(0xece7dc))
	var dark := mat(hex(0x3a3630))
	var body := mesh(sphere(0.15, 9, 7), wool, 0, 0.2, 0)
	body.scale = Vector3(1.3, 1.0, 1.05)
	g.add_child(body)
	g.add_child(mesh(sphere(0.08, 10, 8), dark, 0.19, 0.27, 0))
	g.add_child(mesh(sphere(0.05, 8, 6), wool, 0.16, 0.32, 0))
	for sz in [-0.035, 0.035]:
		g.add_child(mesh(sphere(0.014, 6, 5), mat(hex(0xf7f7fb), 0.5), 0.25, 0.29, sz))
		g.add_child(mesh(sphere(0.007, 5, 4), mat(hex(0x111111), 0.5), 0.262, 0.29, sz))
		g.add_child(mesh(box(0.03, 0.02, 0.012), dark, 0.16, 0.34, sz * 2.2))
	for lp in [[0.1, 0.07], [0.1, -0.07], [-0.1, 0.07], [-0.1, -0.07]]:
		g.add_child(mesh(cyl(0.022, 0.022, 0.12, 5), dark, lp[0], 0.06, lp[1]))
	g.position = Vector3(x, 0, z)
	g.rotation.y = ry
	g.scale = Vector3.ONE * scale_v
	return g


## Wooden fence around a paddock: posts and two rails along the given sides.
static func fence(w: float, d: float) -> Node3D:
	var g := Node3D.new()
	var wood := mat(hex(0x8a6540))
	var corners := [Vector3(-w / 2.0, 0, -d / 2.0), Vector3(w / 2.0, 0, -d / 2.0), Vector3(w / 2.0, 0, d / 2.0), Vector3(-w / 2.0, 0, d / 2.0)]
	for i in 4:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		var n := 3
		for k in n + 1:
			var p := a.lerp(b, float(k) / n)
			g.add_child(mesh(box(0.022, 0.13, 0.022), wood, p.x, 0.065, p.z))
		for hh in [0.05, 0.1]:
			g.add_child(segment(a + Vector3(0, hh, 0), b + Vector3(0, hh, 0), 0.007, wood))
	return g


static func fish(x: float, z: float, ry: float) -> Node3D:
	var g := Node3D.new()
	var silver := glow(hex(0xcfe6ff), 0.5)
	var body := mesh(sphere(0.06, 7, 5), silver, 0, 0, 0, false)
	body.scale = Vector3(1.6, 0.7, 0.8)
	g.add_child(body)
	var tail := mesh(cone(0.045, 0.07, 3), silver, -0.11, 0, 0, false)
	tail.rotation.z = PI / 2.0
	g.add_child(tail)
	g.position = Vector3(x, 0, z)
	g.rotation.y = ry
	return g


static func mine() -> Node3D:
	var g := Node3D.new()
	var wood := mat(hex(0x7d5b3a))
	var dark := mat(hex(0x1c1a1f))
	g.add_child(mesh(box(0.26, 0.22, 0.2), dark, 0, 0.11, 0.15))
	g.add_child(mesh(box(0.04, 0.26, 0.05), wood, -0.14, 0.13, 0.26))
	g.add_child(mesh(box(0.04, 0.26, 0.05), wood, 0.14, 0.13, 0.26))
	g.add_child(mesh(box(0.34, 0.05, 0.05), wood, 0, 0.27, 0.26))
	for i in 3:
		g.add_child(mesh(cone(0.05, 0.12, 4), glow(hex(0xd9e4ff), 1.2), -0.25 + i * 0.1, 0.06, -0.15))
	return g


static func lumber_hut() -> Node3D:
	var g := Node3D.new()
	var wood := mat(hex(0x8a6540))
	var log_m := mat(hex(0x6b4a2f))
	g.add_child(mesh(box(0.3, 0.2, 0.26), wood, -0.12, 0.1, 0.05))
	var roof := mesh(cone(0.24, 0.14), mat(hex(0x4a3628)), -0.12, 0.27, 0.05)
	roof.rotation.y = PI / 4.0
	g.add_child(roof)
	for i in 3:
		var l := mesh(cyl(0.035, 0.035, 0.3, 6), log_m, 0.24, 0.035 + (i / 2) * 0.06, -0.1 + (i % 2) * 0.08)
		l.rotation.z = PI / 2.0
		g.add_child(l)
	return g


# ---------------------------------------------------------------- buildings

## City building. Level drives the goodlife house stages; villages are huts.
static func city_building(level: int, accent: Color, village: bool, capital: bool) -> Node3D:
	var g := Node3D.new()
	if village:
		var wall := mat(hex(0xc7b48c))
		var straw := mat(hex(0xb8934a))
		g.add_child(mesh(box(0.36, 0.22, 0.32), wall, 0, 0.11, 0))
		var roof := mesh(cone(0.29, 0.2), straw, 0, 0.32, 0)
		roof.rotation.y = PI / 4.0
		g.add_child(roof)
		g.add_child(mesh(box(0.09, 0.14, 0.02), mat(hex(0x5d4a3a)), 0, 0.07, 0.165))
		return g
	var stage := clampi(level + 1, 2, 7)
	var wall := mat(hex(0xd9c8a4))
	var roof_m := mat(hex(0xb2523d))
	var wood := mat(hex(0x7d5b3a))
	var w := 0.5
	var d := 0.42
	var floors := 2 if stage >= 6 else 1
	var bh := 0.26 * floors
	g.add_child(mesh(box(w, bh, d), wall, 0, bh / 2.0, 0))
	var roof := mesh(cone(w * 0.72, 0.2), roof_m, 0, bh + 0.1, 0)
	roof.rotation.y = PI / 4.0
	roof.scale.z = d / w
	g.add_child(roof)
	if stage >= 3:
		g.add_child(mesh(box(0.07, 0.2, 0.07), mat(hex(0x8c5a4a)), w * 0.24, bh + 0.14, -d * 0.18))
	g.add_child(mesh(box(0.1, 0.16, 0.02), wood, 0, 0.08, d / 2.0))
	for sx in [-1.0, 1.0]:
		g.add_child(mesh(box(0.08, 0.08, 0.02), glow(accent, 1.2), sx * w * 0.28, 0.16, d / 2.0))
		if floors == 2:
			g.add_child(mesh(box(0.08, 0.08, 0.02), glow(accent, 1.2), sx * w * 0.28, 0.42, d / 2.0))
	if stage >= 5:
		var ew := w * 0.55
		var eh := 0.18
		var ex := -(w / 2.0 + ew / 2.0 - 0.02)
		g.add_child(mesh(box(ew, eh, d * 0.7), wall, ex, eh / 2.0, 0))
		var er := mesh(cone(ew * 0.72, 0.12), roof_m, ex, eh + 0.06, 0)
		er.rotation.y = PI / 4.0
		er.scale.z = (d * 0.7) / ew
		g.add_child(er)
	if stage >= 7:
		for sx in [1.0, -1.0]:
			g.add_child(mesh(cyl(0.012, 0.012, 0.1, 5), mat(hex(0x3d9e57)), sx * 0.3, 0.05, 0.3))
			g.add_child(mesh(sphere(0.035, 6, 5), glow(accent, 1.5), sx * 0.3, 0.12, 0.3))
	if capital:
		# A church-style tower marks the capital.
		var stone := mat(hex(0xcfc6b8))
		var slate := mat(hex(0x5a6274))
		g.add_child(mesh(box(0.15, 0.5, 0.15), stone, 0.34, 0.25, -0.1))
		var spire := mesh(cone(0.11, 0.2), slate, 0.34, 0.6, -0.1)
		spire.rotation.y = PI / 4.0
		g.add_child(spire)
		g.add_child(mesh(sphere(0.03, 6, 5), glow(hex(0xfff6d8), 1.5), 0.34, 0.73, -0.1))
	return g


static func walls(accent: Color) -> Node3D:
	var g := Node3D.new()
	var stone := mat(hex(0xb9b3a8))
	var stone2 := mat(hex(0x9e978c))
	for side in 4:
		var seg := mesh(box(0.9, 0.12, 0.06), stone, 0, 0.06, 0)
		var pivot := Node3D.new()
		pivot.rotation.y = side * PI / 2.0
		seg.position = Vector3(0, 0.06, 0.44)
		pivot.add_child(seg)
		g.add_child(pivot)
		g.add_child(mesh(box(0.1, 0.2, 0.1), stone2, 0.44 if side < 2 else -0.44, 0.1, 0.44 if side % 2 == 0 else -0.44))
	var _c := accent
	return g


static func banner(color: Color) -> Node3D:
	var g := Node3D.new()
	g.add_child(mesh(cyl(0.012, 0.012, 0.5, 5), mat(hex(0x5d4a3a)), 0, 0.25, 0))
	g.add_child(mesh(box(0.16, 0.1, 0.01), glow(color, 1.2), 0.08, 0.44, 0))
	return g


static func border_edge(color: Color, side: int) -> MeshInstance3D:
	# side: 0 north (z-), 1 east (x+), 2 south (z+), 3 west (x-)
	var m := mesh(box(0.98, 0.035, 0.06) if side % 2 == 0 else box(0.06, 0.035, 0.98), glow(color, 1.1), 0, 0.02, 0, false)
	match side:
		0: m.position.z = -0.47
		1: m.position.x = 0.47
		2: m.position.z = 0.47
		3: m.position.x = -0.47
	return m


# ---------------------------------------------------------------- units

const HAIR := [0x3b2a20, 0x6b4a2f, 0xd9b26b, 0x1f1a1a, 0xa8552f]


## Cylinder between two points (for bows, rails, straps).
static func segment(a: Vector3, b: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var d := b - a
	var m := mesh(cyl(radius, radius, d.length(), 6), material)
	m.transform = Transform3D(Basis(Quaternion(Vector3.UP, d.normalized())), (a + b) * 0.5)
	return m


## A rigged little person: hips, torso, shoulders and neck are pivots so the
## view can walk, swing and draw. Returns the root; the rig dictionary is stored
## on the root as meta "rig" (leg_l, leg_r, arm_l, arm_r, hand_l, hand_r, head, torso).
static func figure(shirt: Color, skin: Color, scale_v: float = 1.0, seed_v: int = 0) -> Node3D:
	var root := Node3D.new()
	var rig := {}
	var pants := mat(shirt.darkened(0.5))
	var cloth := mat(shirt)
	var flesh := mat(skin, 0.7)
	var shoe := mat(hex(0x3a2a20))
	var dark := mat(hex(0x1a1414), 0.5)
	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.034, 0.1, 0)
		hip.add_child(mesh(cyl(0.022, 0.026, 0.1, 8), pants, 0, -0.05, 0))
		hip.add_child(mesh(box(0.046, 0.022, 0.07), shoe, 0, -0.089, 0.014))
		root.add_child(hip)
		rig["leg_l" if side < 0 else "leg_r"] = hip
	var torso := Node3D.new()
	torso.position = Vector3(0, 0.1, 0)
	torso.add_child(mesh(cyl(0.058, 0.07, 0.15, 12), cloth, 0, 0.075, 0))
	torso.add_child(mesh(cyl(0.062, 0.066, 0.025, 12), mat(hex(0x5d4a3a)), 0, 0.012, 0))
	torso.add_child(mesh(box(0.02, 0.014, 0.01), mat(hex(0xd8a93c), 0.4, 0.6), 0, 0.012, 0.064))
	root.add_child(torso)
	rig["torso"] = torso
	for side in [-1.0, 1.0]:
		var sh := Node3D.new()
		sh.position = Vector3(side * 0.077, 0.135, 0)
		sh.rotation.z = -side * 0.12
		sh.add_child(mesh(sphere(0.026, 8, 6), cloth, 0, 0, 0))
		sh.add_child(mesh(cyl(0.02, 0.022, 0.11, 8), cloth, 0, -0.055, 0))
		var hand := Node3D.new()
		hand.position = Vector3(0, -0.118, 0)
		hand.add_child(mesh(sphere(0.024, 8, 6), flesh, 0, 0, 0))
		sh.add_child(hand)
		torso.add_child(sh)
		rig["arm_l" if side < 0 else "arm_r"] = sh
		rig["hand_l" if side < 0 else "hand_r"] = hand
	var neck := Node3D.new()
	neck.position = Vector3(0, 0.152, 0)
	neck.add_child(mesh(cyl(0.022, 0.026, 0.03, 8), flesh, 0, 0.01, 0))
	var head := mesh(smooth_sphere(0.064, 18, 14), flesh, 0, 0.078, 0)
	neck.add_child(head)
	# Face: eyes with pupils, brows, nose, mouth, ears.
	var white := mat(hex(0xf7f7fb), 0.5)
	for sx in [-0.024, 0.024]:
		neck.add_child(mesh(smooth_sphere(0.013, 10, 8), white, sx, 0.084, 0.056))
		neck.add_child(mesh(smooth_sphere(0.0065, 8, 6), dark, sx, 0.084, 0.067))
		var brow := mesh(box(0.026, 0.006, 0.008), mat(hex(HAIR[seed_v % HAIR.size()])), sx, 0.104, 0.058)
		brow.rotation.z = -0.15 * signf(sx)
		neck.add_child(brow)
		neck.add_child(mesh(sphere(0.012, 6, 5), flesh, sx * 2.7, 0.078, 0.0))
	var nose := mesh(cone(0.009, 0.022, 6), flesh, 0, 0.07, 0.066)
	nose.rotation.x = PI / 2.0
	neck.add_child(nose)
	neck.add_child(mesh(box(0.024, 0.006, 0.008), mat(hex(0x8f3b3b)), 0, 0.052, 0.058))
	var hair := mesh(smooth_sphere(0.067, 18, 14), mat(hex(HAIR[seed_v % HAIR.size()]), 0.9), 0, 0.094, -0.012)
	hair.scale = Vector3(1.0, 0.62, 1.0)
	neck.add_child(hair)
	torso.add_child(neck)
	rig["head"] = neck
	root.set_meta("rig", rig)
	root.scale = Vector3.ONE * scale_v
	return root


static func person(shirt: Color, skin: Color, scale_v: float = 1.0) -> Node3D:
	return figure(shirt, skin, scale_v)


## Bow held in a hand node. Forward (arrow direction) is the hand's -y axis,
## up is +z, so a raised arm points the bow at the target. Adds "bow" to rig.
static func attach_bow(hand: Node3D, rig: Dictionary) -> void:
	var wood := mat(hex(0x6b4a2f), 0.7)
	var r := 0.17
	var c := Vector3(0, 0.1, 0)
	var pts: Array = []
	for i in 9:
		var a := deg_to_rad(-70.0 + 140.0 * i / 8.0)
		pts.append(c + Vector3(0, -r * cos(a), r * sin(a)))
	var bow := Node3D.new()
	for i in pts.size() - 1:
		bow.add_child(segment(pts[i], pts[i + 1], 0.0075 if absf(i - 4) < 2 else 0.006, wood))
	bow.add_child(mesh(cyl(0.011, 0.011, 0.05, 8), mat(hex(0x8a2f2f)), 0, -0.07, 0))  # grip wrap
	var tip_y: float = pts[0].y
	var tip_z: float = absf(pts[0].z)
	var string := mat(hex(0xf4f1e8), 0.4)
	var top := Node3D.new()
	top.position = Vector3(0, tip_y, tip_z)
	top.add_child(mesh(box(0.004, 0.004, tip_z), string, 0, 0, -tip_z * 0.5))
	var bot := Node3D.new()
	bot.position = Vector3(0, tip_y, -tip_z)
	bot.add_child(mesh(box(0.004, 0.004, tip_z), string, 0, 0, tip_z * 0.5))
	bow.add_child(top)
	bow.add_child(bot)
	var arrow := arrow_model()
	arrow.position = Vector3(0, tip_y, 0)
	bow.add_child(arrow)
	hand.add_child(bow)
	rig["bow"] = {"node": bow, "top": top, "bot": bot, "arrow": arrow, "tip_y": tip_y, "tip_z": tip_z}
	set_draw(rig, 0.0)


## Pulls the string and arrow back by d in [0, 1].
static func set_draw(rig: Dictionary, d: float) -> void:
	if not rig.has("bow"):
		return
	var b: Dictionary = rig["bow"]
	var pull := d * 0.13
	var tz: float = b["tip_z"]
	var len := sqrt(tz * tz + pull * pull)
	var ang := atan2(pull, tz)
	var top: Node3D = b["top"]
	var bot: Node3D = b["bot"]
	top.rotation.x = ang
	top.scale = Vector3(1, 1, len / tz)
	bot.rotation.x = -ang
	bot.scale = Vector3(1, 1, len / tz)
	var arrow: Node3D = b["arrow"]
	arrow.position = Vector3(0, b["tip_y"] + pull, 0)


## Arrow pointing along -y with its nock at the origin.
static func arrow_model() -> Node3D:
	var g := Node3D.new()
	g.add_child(mesh(cyl(0.005, 0.005, 0.3, 6), mat(hex(0x8a6a3d)), 0, -0.15, 0))
	var head := mesh(cone(0.012, 0.035, 4), mat(hex(0xd7dfee), 0.35, 0.7), 0, -0.315, 0)
	head.rotation.x = PI
	g.add_child(head)
	for i in 3:
		var f := mesh(box(0.003, 0.045, 0.018), mat(hex(0xff5c5c)), 0, -0.03, 0.012)
		f.rotation.y = i * TAU / 3.0
		g.add_child(f)
	return g


static func horse(coat_col: Color, saddle: Color) -> Node3D:
	var g := Node3D.new()
	var coat := mat(coat_col)
	var dark := mat(coat_col.darkened(0.5))
	var body := mesh(sphere(0.135, 12, 8), coat, 0, 0.22, 0)
	body.scale = Vector3(1.75, 1.0, 0.85)
	g.add_child(body)
	var neck := mesh(cyl(0.05, 0.065, 0.2, 8), coat, 0.2, 0.32, 0)
	neck.rotation.z = -0.7
	g.add_child(neck)
	var head := mesh(box(0.15, 0.085, 0.075), coat, 0.31, 0.39, 0)
	head.rotation.z = -0.25
	g.add_child(head)
	g.add_child(mesh(box(0.05, 0.05, 0.075), dark, 0.375, 0.375, 0))
	for sz in [-0.03, 0.03]:
		g.add_child(mesh(sphere(0.011, 6, 5), mat(hex(0x1a1414), 0.4), 0.33, 0.415, sz + signf(sz) * 0.012))
		g.add_child(mesh(cone(0.018, 0.045, 4), coat, 0.28, 0.45, sz))
	var mane := mesh(box(0.16, 0.05, 0.03), dark, 0.16, 0.37, 0)
	mane.rotation.z = -0.6
	g.add_child(mane)
	var tail := mesh(cone(0.035, 0.2, 5), dark, -0.24, 0.16, 0)
	tail.rotation.z = 2.4
	g.add_child(tail)
	for lp in [[0.13, 0.06], [0.13, -0.06], [-0.13, 0.06], [-0.13, -0.06]]:
		g.add_child(mesh(cyl(0.024, 0.024, 0.2, 6), dark, lp[0], 0.1, lp[1]))
		g.add_child(mesh(cyl(0.026, 0.026, 0.03, 6), mat(hex(0x2a2622)), lp[0], 0.015, lp[1]))
	g.add_child(mesh(box(0.14, 0.04, 0.14), mat(saddle), -0.02, 0.33, 0))
	g.add_child(segment(Vector3(0.27, 0.36, 0.04), Vector3(0.0, 0.33, 0.07), 0.004, mat(hex(0x3a2a20))))  # rein
	return g


static func _helmet(neck: Node3D, plume: Color, with_plume: bool, hair_hidden: bool = true) -> void:
	var steel := mat(hex(0xd7dfee), 0.35, 0.7)
	var h := mesh(smooth_sphere(0.071, 18, 14), steel, 0, 0.082, 0)
	neck.add_child(h)
	neck.add_child(mesh(box(0.018, 0.05, 0.02), steel, 0, 0.076, 0.066))  # nose guard
	for sx in [-1.0, 1.0]:
		neck.add_child(mesh(box(0.03, 0.04, 0.02), steel, sx * 0.05, 0.062, 0.045))  # cheek guards
	if with_plume:
		var pl := mesh(cone(0.03, 0.14, 7), mat(plume), 0, 0.19, -0.02)
		pl.rotation.x = -0.4
		neck.add_child(pl)


static func _rig_of(n: Node3D) -> Dictionary:
	return n.get_meta("rig", {})


## A unit figure: little person in the tribe colour with a type-specific
## silhouette (cap, helmet, shield, bow, lance, horse...). The rig dictionary
## is stored as meta "rig" on the returned group.
static func unit_figure(type: String, color: Color, seed_v: int, embarked: bool, vessel: String) -> Node3D:
	var g := Node3D.new()
	var skin := hex(SKIN[seed_v % SKIN.size()])
	var steel := mat(hex(0xd7dfee), 0.35, 0.7)
	var wood := mat(hex(0x7d5b3a))
	var leather := mat(hex(0x8a5a3a))
	var s := 1.2
	if embarked:
		var hull_w := 0.6 if vessel == "ship" else 0.46
		g.add_child(mesh(box(hull_w, 0.13, 0.26), mat(hex(0x8a5a3a)), 0, 0.02, 0))
		g.add_child(mesh(box(hull_w + 0.04, 0.03, 0.3), mat(hex(0x6b4a2f)), 0, 0.085, 0))
		g.add_child(mesh(cyl(0.013, 0.013, 0.46, 5), wood, 0, 0.3, 0))
		g.add_child(mesh(box(0.012, 0.26, 0.22), mat(hex(0xf4f1e8)), 0, 0.34, 0.11))
		g.add_child(mesh(box(0.014, 0.08, 0.2), mat(color), 0, 0.5, 0.1))
		if vessel == "ship":
			g.add_child(mesh(cyl(0.013, 0.013, 0.4, 5), wood, 0.22, 0.27, 0))
			g.add_child(mesh(box(0.012, 0.22, 0.18), mat(hex(0xf4f1e8)), 0.22, 0.3, 0.09))
		var p := figure(color, skin, 0.85, seed_v)
		p.position = Vector3(-0.12, 0.09, 0)
		g.add_child(p)
		g.set_meta("rig", _rig_of(p))
		return g
	match type:
		"giant":
			var fn := figure(color.darkened(0.25), hex(0x9aa4b8), 2.2, seed_v)
			var rig := _rig_of(fn)
			var club := mesh(cyl(0.028, 0.06, 0.34, 7), wood, 0, 0.12, 0.02)
			rig["hand_r"].add_child(club)
			rig["torso"].add_child(mesh(box(0.15, 0.03, 0.15), leather, 0, 0.14, 0))
			g.add_child(fn)
			g.set_meta("rig", rig)
		"rider", "knight":
			var knight := type == "knight"
			var h := horse(hex(0x8a5a3a) if not knight else hex(0xe8e2d6), color)
			g.add_child(h)
			if knight:
				g.add_child(mesh(box(0.34, 0.18, 0.22), mat(color), -0.02, 0.2, 0))  # caparison
			var fn := figure(color, skin, 0.95, seed_v)
			fn.position = Vector3(-0.02, 0.33, 0)
			fn.rotation.y = PI / 2.0  # horse faces +x
			var rig := _rig_of(fn)
			rig["leg_l"].rotation.x = -1.25
			rig["leg_r"].rotation.x = -1.25
			rig["leg_l"].rotation.z = 0.35
			rig["leg_r"].rotation.z = -0.35
			g.add_child(fn)
			g.set_meta("rig", rig)
			g.set_meta("mounted", true)
			if knight:
				_helmet(rig["head"], color, true)
				var lance := mesh(cyl(0.011, 0.011, 0.62, 6), steel, 0, 0.08, 0)
				lance.rotation.x = 0.55
				rig["hand_r"].add_child(lance)
				rig["hand_r"].add_child(mesh(cone(0.02, 0.06, 4), steel, 0, 0.36, -0.17))
				var sh := mesh(box(0.022, 0.16, 0.13), mat(color), -0.03, 0.05, 0.02)
				rig["arm_l"].add_child(sh)
				rig["arm_l"].add_child(mesh(box(0.026, 0.18, 0.15), steel, -0.035, 0.05, 0.02))
			else:
				var cap := mesh(smooth_sphere(0.068, 16, 12), leather, 0, 0.09, 0)
				cap.scale = Vector3(1, 0.7, 1)
				rig["head"].add_child(cap)
				rig["hand_r"].add_child(mesh(cyl(0.01, 0.01, 0.5, 5), wood, 0, 0.14, 0))
				rig["hand_r"].add_child(mesh(cone(0.022, 0.08, 4), steel, 0, 0.43, 0))
		"catapult":
			g.add_child(mesh(box(0.4, 0.07, 0.26), wood, 0, 0.1, 0))
			g.add_child(mesh(box(0.05, 0.22, 0.05), wood, 0.1, 0.24, 0.09))
			g.add_child(mesh(box(0.05, 0.22, 0.05), wood, 0.1, 0.24, -0.09))
			g.add_child(mesh(box(0.05, 0.04, 0.24), wood, 0.1, 0.36, 0))
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					var wheel := mesh(cyl(0.075, 0.075, 0.035, 10), mat(hex(0x4a3628)), sx * 0.16, 0.075, sz * 0.15)
					wheel.rotation.x = PI / 2.0
					g.add_child(wheel)
			var pivot := Node3D.new()
			pivot.position = Vector3(0.1, 0.36, 0)
			var arm := mesh(box(0.035, 0.42, 0.035), wood, -0.12, 0.08, 0)
			arm.rotation.z = 0.75
			pivot.add_child(arm)
			pivot.add_child(mesh(sphere(0.055, 7, 5), mat(hex(0x6e6a66)), -0.3, 0.07, 0))
			g.add_child(pivot)
			var crew := figure(color, skin, 0.7, seed_v)
			crew.position = Vector3(0.24, 0.0, 0.18)
			g.add_child(crew)
			g.set_meta("rig", _rig_of(crew))
			g.set_meta("catapult_arm", pivot)
		_:
			var fn := figure(color, skin, s, seed_v)
			var rig := _rig_of(fn)
			g.add_child(fn)
			g.set_meta("rig", rig)
			var hr: Node3D = rig["hand_r"]
			var hl: Node3D = rig["hand_l"]
			var neck: Node3D = rig["head"]
			match type:
				"warrior":
					neck.add_child(mesh(torus(0.012, 0.064), mat(color), 0, 0.09, 0))  # headband
					hr.add_child(mesh(box(0.02, 0.26, 0.012), steel, 0, 0.14, 0.012))
					hr.add_child(mesh(box(0.07, 0.016, 0.02), wood, 0, 0.02, 0.012))
					hr.add_child(mesh(sphere(0.012, 6, 5), mat(hex(0xd8a93c), 0.4, 0.6), 0, -0.02, 0.012))
					var shield := mesh(cyl(0.085, 0.085, 0.018, 16), mat(color), -0.035, -0.06, 0.02)
					shield.rotation.z = PI / 2.0
					rig["arm_l"].add_child(shield)
					var rim := mesh(cyl(0.095, 0.095, 0.01, 16), steel, -0.04, -0.06, 0.02)
					rim.rotation.z = PI / 2.0
					rig["arm_l"].add_child(rim)
					var boss := mesh(sphere(0.02, 8, 6), steel, -0.048, -0.06, 0.02)
					rig["arm_l"].add_child(boss)
				"archer":
					var green := mat(hex(0x2f7a4b))
					var cap := mesh(cone(0.075, 0.12, 10), green, 0, 0.13, -0.01)
					cap.rotation.x = 0.35
					neck.add_child(cap)
					neck.add_child(mesh(cyl(0.082, 0.078, 0.02, 12), green, 0, 0.1, 0))  # brim
					var feather := mesh(box(0.006, 0.09, 0.02), mat(hex(0xff5c5c)), 0.06, 0.17, -0.02)
					feather.rotation.z = -0.5
					neck.add_child(feather)
					rig["torso"].add_child(mesh(box(0.15, 0.05, 0.03), green, 0, 0.12, 0.055))  # collar
					var quiver := mesh(cyl(0.03, 0.03, 0.17, 8), leather, 0.03, 0.08, -0.075)
					quiver.rotation.x = 0.35
					rig["torso"].add_child(quiver)
					for i in 3:
						rig["torso"].add_child(mesh(cyl(0.005, 0.005, 0.1, 4), wood, 0.03 + (i - 1) * 0.015, 0.2, -0.1))
						rig["torso"].add_child(mesh(sphere(0.012, 5, 4), mat(hex(0xff5c5c)), 0.03 + (i - 1) * 0.015, 0.25, -0.1))
					attach_bow(hl, rig)
					rig["arm_l_rest"] = -0.45
					rig["arm_l"].rotation.x = -0.45
				"defender":
					_helmet(neck, color, false)
					rig["torso"].add_child(mesh(box(0.15, 0.13, 0.11), steel, 0, 0.09, 0))
					rig["arm_l"].add_child(mesh(box(0.012, 0.3, 0.2), steel, -0.04, -0.06, 0.02))
					rig["arm_l"].add_child(mesh(box(0.014, 0.27, 0.17), mat(color), -0.045, -0.06, 0.02))
					rig["arm_l"].add_child(mesh(box(0.02, 0.2, 0.03), mat(hex(0xffe14d)), -0.055, -0.06, 0.02))
					hr.add_child(mesh(cyl(0.012, 0.012, 0.3, 6), wood, 0, 0.08, 0))
					hr.add_child(mesh(cone(0.025, 0.07, 4), steel, 0, 0.26, 0))
				"swordsman":
					_helmet(neck, color, true)
					rig["torso"].add_child(mesh(box(0.14, 0.14, 0.1), steel, 0, 0.09, 0))
					rig["torso"].add_child(mesh(box(0.14, 0.03, 0.11), mat(color), 0, 0.155, 0))
					for hand in [hr, hl]:
						hand.add_child(mesh(box(0.022, 0.28, 0.012), steel, 0, 0.15, 0.012))
						hand.add_child(mesh(box(0.075, 0.016, 0.02), wood, 0, 0.02, 0.012))
	return g
