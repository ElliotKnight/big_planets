// Billboarded progress bar (HP / population): dark track with a coloured fill.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform float frac : hint_range(0.0, 1.0) = 1.0;
uniform vec4 fill : source_color = vec4(0.3, 0.9, 0.3, 1.0);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float inside = step(abs(UV.y - 0.5), 0.5) * step(abs(UV.x - 0.5), 0.5);
	float edge = step(0.06, UV.x) * step(UV.x, 0.94) * step(0.15, UV.y) * step(UV.y, 0.85);
	vec3 track = vec3(0.03, 0.03, 0.05);
	vec3 col = mix(track, fill.rgb * 1.6, step(UV.x, 0.06 + 0.88 * frac) * edge);
	ALBEDO = col;
	EMISSION = col * 0.8;
}
