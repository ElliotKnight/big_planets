class_name Kit
extends RefCounted
## Loader for Kenney's Castle Kit (CC0) models in assets/kit. Materials are
## applied at runtime from the shared colormap or one of its palette
## variations, so accents (roofs, flags, siege canvas) can take tribe colours.

## Palette variation per player index: blue, red, green, yellow.
const VARIATION_BY_PLAYER := ["d", "a", "b", "c"]
const NEUTRAL := "e"  # grey stone

static var _scenes: Dictionary = {}
static var _mats: Dictionary = {}


static func material(variation: String = "") -> StandardMaterial3D:
	if not _mats.has(variation):
		var tex_name := "colormap" if variation == "" else "variation-" + variation
		var m := StandardMaterial3D.new()
		m.albedo_texture = load("res://assets/kit/Textures/%s.png" % tex_name)
		m.roughness = 1.0
		m.metallic = 0.0
		_mats[variation] = m
	return _mats[variation]


static func player_variation(pid: int) -> String:
	if pid < 0:
		return NEUTRAL
	return VARIATION_BY_PLAYER[pid % VARIATION_BY_PLAYER.size()]


## Instantiates a kit model with the given palette variation and uniform scale.
static func model(name: String, variation: String = "", scale_v: float = 1.0) -> Node3D:
	if not _scenes.has(name):
		_scenes[name] = load("res://assets/kit/%s.glb" % name)
	var n: Node3D = _scenes[name].instantiate()
	var m := material(variation)
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = m
	n.scale = Vector3.ONE * scale_v
	return n


static func place(name: String, variation: String, scale_v: float, pos: Vector3, rot_y: float = 0.0) -> Node3D:
	var n := model(name, variation, scale_v)
	n.position = pos
	n.rotation.y = rot_y
	return n
