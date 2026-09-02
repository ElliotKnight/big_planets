class_name GlassPanel
extends PanelContainer
## Translucent frosted panel: a screen-blur shader behind a padded content box.

static var _shader: Shader = null

var content: MarginContainer
var _blur: ColorRect
var _mat: ShaderMaterial


func _init(padding: int = 14, tint: Color = Color(0.051, 0.051, 0.102, 0.66), radius: float = 14.0) -> void:
	if _shader == null:
		_shader = load("res://shaders/glass.gdshader")
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_corner_radius_all(int(radius))
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 18
	sb.shadow_offset = Vector2(0, 10)
	sb.set_content_margin_all(0)
	add_theme_stylebox_override("panel", sb)
	_blur = ColorRect.new()
	_blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = _shader
	_mat.set_shader_parameter("tint", tint)
	_mat.set_shader_parameter("radius", radius)
	_blur.material = _mat
	add_child(_blur)
	content = MarginContainer.new()
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		content.add_theme_constant_override(m, padding)
	add_child(content)
	resized.connect(_on_resized)


func _on_resized() -> void:
	_mat.set_shader_parameter("rect_size", size)


func add(node: Node) -> void:
	content.add_child(node)
