class_name UITheme
extends RefCounted
## Neon-dark theme in the goodlife palette: #07070f background, translucent
## panels, purple hover glow, cyan active state, orange brand.

const BG := Color("07070f")
const TEXT := Color("e8e8f5")
const DIM := Color("8f8fae")
const PURPLE := Color("7b5cff")
const CYAN := Color("00f0ff")
const PINK := Color("ff3ec8")
const ORANGE := Color("ffb340")
const GREEN := Color("46dc8c")


static func _flat(bg: Color, border: Color, radius: int, border_w: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	return sb


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 14

	var normal := _flat(Color(1, 1, 1, 0.045), Color(1, 1, 1, 0.10), 10)
	normal.set_content_margin_all(8)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	var hover := _flat(Color(PURPLE.r, PURPLE.g, PURPLE.b, 0.16), Color(PURPLE.r, PURPLE.g, PURPLE.b, 0.6), 10)
	hover.set_content_margin_all(8)
	hover.content_margin_left = 14
	hover.content_margin_right = 14
	hover.shadow_color = Color(PURPLE.r, PURPLE.g, PURPLE.b, 0.35)
	hover.shadow_size = 8
	var pressed := _flat(Color(CYAN.r, CYAN.g, CYAN.b, 0.12), Color(CYAN.r, CYAN.g, CYAN.b, 0.65), 10)
	pressed.set_content_margin_all(8)
	pressed.content_margin_left = 14
	pressed.content_margin_right = 14
	var disabled := _flat(Color(1, 1, 1, 0.02), Color(1, 1, 1, 0.05), 10)
	disabled.set_content_margin_all(8)
	disabled.content_margin_left = 14
	disabled.content_margin_right = 14
	for type in ["Button", "OptionButton"]:
		t.set_stylebox("normal", type, normal)
		t.set_stylebox("hover", type, hover)
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("disabled", type, disabled)
		t.set_stylebox("focus", type, StyleBoxEmpty.new())
		t.set_color("font_color", type, TEXT)
		t.set_color("font_hover_color", type, Color.WHITE)
		t.set_color("font_pressed_color", type, CYAN)
		t.set_color("font_disabled_color", type, Color(DIM.r, DIM.g, DIM.b, 0.7))

	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "LineEdit", TEXT)
	var line := _flat(Color(1, 1, 1, 0.045), Color(1, 1, 1, 0.10), 8)
	line.set_content_margin_all(6)
	t.set_stylebox("normal", "LineEdit", line)
	t.set_stylebox("focus", "LineEdit", _flat(Color(1, 1, 1, 0.06), Color(CYAN.r, CYAN.g, CYAN.b, 0.6), 8))

	var popup := _flat(Color(0.07, 0.07, 0.14, 0.97), Color(1, 1, 1, 0.1), 10)
	popup.set_content_margin_all(6)
	t.set_stylebox("panel", "PopupMenu", popup)
	t.set_stylebox("hover", "PopupMenu", _flat(Color(PURPLE.r, PURPLE.g, PURPLE.b, 0.25), Color(0, 0, 0, 0), 6, 0))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)

	var panel := _flat(Color(0.05, 0.05, 0.10, 0.72), Color(1, 1, 1, 0.1), 14)
	panel.set_content_margin_all(14)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	var tip := _flat(Color(0.05, 0.05, 0.10, 0.95), Color(1, 1, 1, 0.12), 8)
	tip.set_content_margin_all(8)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", TEXT)
	return t
