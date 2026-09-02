extends SceneTree
## Renders a contact sheet of Castle Kit models (and the 7 palette variations
## applied to a flag) and prints each model's AABB. Run windowed:
##   Godot --path . --script tests/kit_preview.gd --windowed --resolution 1440x900

const MODELS := ["tree-large", "tree-small", "tree-trunk", "tree-log", "rocks-large", "rocks-small", "ground", "ground-hills",
	"tower-square", "tower-square-base", "tower-square-mid", "tower-square-top-roof", "tower-square-top-roof-high", "tower-slant-roof",
	"tower-hexagon-base", "tower-hexagon-mid", "tower-hexagon-roof", "tower-hexagon-top",
	"wall", "wall-corner", "wall-doorway", "wall-half", "gate", "door", "stairs-stone",
	"flag", "flag-banner-long", "flag-wide", "flag-pennant", "siege-catapult", "siege-ballista", "siege-trebuchet", "siege-tower", "siege-ram", "bridge-straight"]


func _aabb(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = mi.mesh.get_aabb()
		a = mi.global_transform * a
		if first:
			box = a
			first = false
		else:
			box = box.merge(a)
	return box


func _retex(n: Node3D, tex: Texture2D) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var m: Material = mi.get_active_material(i)
			if m is StandardMaterial3D:
				var d: StandardMaterial3D = m.duplicate()
				d.albedo_texture = tex
				mi.set_surface_override_material(i, d)


func _init() -> void:
	await process_frame
	var world := Node3D.new()
	root.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.1, 0.14)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.75, 0.9)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	world.add_child(sun)
	sun.look_at_from_position(Vector3(6, 9, 4), Vector3.ZERO)
	var cols := 8
	var i := 0
	var font := ThemeDB.fallback_font
	for name in MODELS:
		var ps: PackedScene = load("res://assets/kit/%s.glb" % name)
		if ps == null:
			print("MISSING ", name)
			continue
		var n: Node3D = ps.instantiate()
		n.position = Vector3((i % cols) * 2.2, 0, (i / cols) * 2.4)
		world.add_child(n)
		if i == 0:
			for mi in n.find_children("*", "MeshInstance3D", true, false):
				var m0: Material = mi.get_active_material(0)
				print("material: ", m0, " tex=", m0.albedo_texture if m0 is StandardMaterial3D else "n/a")
		_retex(n, load("res://assets/kit/Textures/colormap.png"))
		var a := _aabb(n)
		print("%-28s size=(%.2f, %.2f, %.2f) min=(%.2f, %.2f, %.2f)" % [name, a.size.x, a.size.y, a.size.z, a.position.x - n.position.x, a.position.y, a.position.z - n.position.z])
		var l := Label3D.new()
		l.text = name
		l.font_size = 40
		l.pixel_size = 0.006
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.position = n.position + Vector3(0, -0.15, 0.9)
		world.add_child(l)
		i += 1
	# Palette variations on a flag and a tower roof.
	var row := (i / cols) + 1
	for v in 7:
		var letter := char(97 + v)
		var tex: Texture2D = load("res://assets/kit/Textures/variation-%s.png" % letter)
		for j in 2:
			var ps: PackedScene = load("res://assets/kit/%s.glb" % ["flag-wide", "tower-square-top-roof"][j])
			var n: Node3D = ps.instantiate()
			n.position = Vector3(v * 2.2, 0, (row + j) * 2.4)
			_retex(n, tex)
			world.add_child(n)
			var l := Label3D.new()
			l.text = "var-" + letter
			l.font_size = 40
			l.pixel_size = 0.006
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.position = n.position + Vector3(0, -0.15, 0.9)
			world.add_child(l)
	var cam := Camera3D.new()
	cam.fov = 40
	world.add_child(cam)
	var centre := Vector3(cols * 1.1 - 1.1, 0, (row + 1) * 1.2)
	cam.look_at_from_position(centre + Vector3(0, 17, 12), centre)
	cam.current = true
	for k in 10:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(OS.get_environment("BP_OUT"))
	quit()
