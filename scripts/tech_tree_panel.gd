class_name TechTreePanel
extends Control
## The technology tree drawn as a branching diagram: a root node on the left
## and five branches of three tiers linked by glowing curves.

const NODE_W := 188.0
const NODE_H := 58.0
const ROOT_W := 150.0
const ROOT_H := 54.0
const ROW_H := 86.0
const COL_W := 226.0
const X0 := 236.0
const Y0 := 12.0

var game: Game
var ctrl
var desc_label: Label
var _states: Dictionary = {}


func _init(g: Game, c, desc: Label) -> void:
	game = g
	ctrl = c
	desc_label = desc
	var branches: int = Defs.BRANCHES.size()
	custom_minimum_size = Vector2(X0 + 2 * COL_W + NODE_W + 8, Y0 * 2 + (branches - 1) * ROW_H + NODE_H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func _node_rect(branch: int, tier: int) -> Rect2:
	return Rect2(X0 + tier * COL_W, Y0 + branch * ROW_H, NODE_W, NODE_H)


func _root_rect() -> Rect2:
	return Rect2(14.0, custom_minimum_size.y * 0.5 - ROOT_H * 0.5, ROOT_W, ROOT_H)


func _state(tid: String) -> String:
	var p: Player = game.players[0]
	if p.techs.has(tid):
		return "owned"
	if p.has_tech(Defs.TECHS[tid]["requires"]):
		return "available"
	return "locked"


func _style(state: String, affordable: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(2)
	sb.anti_aliasing = true
	match state:
		"owned":
			sb.bg_color = Color(UITheme.CYAN, 0.13)
			sb.border_color = Color(UITheme.CYAN, 0.75)
			sb.shadow_color = Color(UITheme.CYAN, 0.25)
			sb.shadow_size = 10
		"available":
			sb.bg_color = Color(UITheme.PURPLE, 0.2 if affordable else 0.08)
			sb.border_color = Color(UITheme.PURPLE, 0.9 if affordable else 0.35)
			if affordable:
				sb.shadow_color = Color(UITheme.PURPLE, 0.35)
				sb.shadow_size = 10
		_:
			sb.bg_color = Color(1, 1, 1, 0.03)
			sb.border_color = Color(1, 1, 1, 0.07)
	return sb


func _build() -> void:
	var p: Player = game.players[0]
	var root := Button.new()
	root.text = "%s tribe\n%d / %d techs" % [p.tribe_name, p.techs.size(), Defs.TECHS.size()]
	root.position = _root_rect().position
	root.size = _root_rect().size
	root.add_theme_stylebox_override("normal", _style("owned", true))
	root.add_theme_stylebox_override("hover", _style("owned", true))
	root.add_theme_stylebox_override("disabled", _style("owned", true))
	root.add_theme_color_override("font_disabled_color", UITheme.TEXT)
	root.add_theme_font_size_override("font_size", 13)
	root.disabled = true
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	for b in Defs.BRANCHES.size():
		for tier in 3:
			var tid: String = Defs.BRANCHES[b][tier]
			var d: Dictionary = Defs.TECHS[tid]
			var state := _state(tid)
			_states[tid] = state
			var cost := game.tech_cost(0, tid)
			var affordable := p.stars >= cost and game.current == 0 and not game.over
			var btn := Button.new()
			var r := _node_rect(b, tier)
			btn.position = r.position
			btn.size = r.size
			btn.add_theme_font_size_override("font_size", 13)
			var sb := _style(state, affordable)
			btn.add_theme_stylebox_override("normal", sb)
			btn.add_theme_stylebox_override("hover", sb)
			btn.add_theme_stylebox_override("pressed", sb)
			btn.add_theme_stylebox_override("disabled", sb)
			match state:
				"owned":
					btn.text = "%s\nresearched" % d["name"]
					btn.disabled = true
					btn.add_theme_color_override("font_disabled_color", Color(UITheme.CYAN, 0.9))
				"available":
					btn.text = "%s\n%d stars" % [d["name"], cost]
					btn.disabled = not affordable
					btn.add_theme_color_override("font_disabled_color", Color(UITheme.TEXT, 0.6))
					btn.pressed.connect(func(): ctrl._on_research(tid))
				_:
					btn.text = "%s\nneeds %s" % [d["name"], Defs.TECHS[d["requires"]]["name"]]
					btn.disabled = true
					btn.add_theme_color_override("font_disabled_color", Color(UITheme.DIM, 0.8))
			btn.mouse_filter = Control.MOUSE_FILTER_STOP
			btn.mouse_entered.connect(func(): desc_label.text = "%s: %s" % [d["name"], d["desc"]])
			add_child(btn)


static func _bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return u * u * u * p0 + 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t * p3


func _link_color(state: String) -> Color:
	match state:
		"owned": return Color(UITheme.CYAN, 0.9)
		"available": return Color(UITheme.PURPLE, 0.85)
	return Color(1, 1, 1, 0.12)


func _curve(a: Vector2, b: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	var c1 := Vector2((a.x + b.x) * 0.5, a.y)
	var c2 := Vector2((a.x + b.x) * 0.5, b.y)
	for i in 21:
		pts.append(_bezier(a, c1, c2, b, i / 20.0))
	draw_polyline(pts, Color(col, col.a * 0.25), 9.0, true)
	draw_polyline(pts, col, 2.5, true)


func _draw() -> void:
	var root := _root_rect()
	var root_out := Vector2(root.end.x, root.get_center().y)
	for b in Defs.BRANCHES.size():
		var first: String = Defs.BRANCHES[b][0]
		var r0 := _node_rect(b, 0)
		_curve(root_out, Vector2(r0.position.x, r0.get_center().y), _link_color(_states[first]))
		for tier in range(1, 3):
			var tid: String = Defs.BRANCHES[b][tier]
			var ra := _node_rect(b, tier - 1)
			var rb := _node_rect(b, tier)
			_curve(Vector2(ra.end.x, ra.get_center().y), Vector2(rb.position.x, rb.get_center().y), _link_color(_states[tid]))
