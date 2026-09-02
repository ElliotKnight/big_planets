// Frosted "glass" panel: blurred backdrop + dark tint + thin border, rounded corners.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float blur_lod = 2.6;
uniform vec2 rect_size = vec2(100.0, 100.0);
uniform float radius = 14.0;
uniform vec4 tint : source_color = vec4(0.051, 0.051, 0.102, 0.66);
uniform vec4 border_col : source_color = vec4(1.0, 1.0, 1.0, 0.10);

float rounded_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = UV * rect_size - rect_size * 0.5;
	float d = rounded_box(p, rect_size * 0.5, radius);
	float mask = 1.0 - smoothstep(-1.0, 0.5, d);
	vec3 blurred = textureLod(screen_tex, SCREEN_UV, blur_lod).rgb;
	vec3 col = mix(blurred, tint.rgb, tint.a);
	float edge = 1.0 - smoothstep(0.0, 1.6, abs(d + 1.2));
	col = mix(col, border_col.rgb, edge * border_col.a * 3.0);
	COLOR = vec4(col, mask);
}
