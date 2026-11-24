shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform sampler2D mask : filter_linear_mipmap, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float opacity = 1.0;
uniform vec4 edge_color : source_color = vec4(1.0);
uniform float age = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float angle = atan(p.y, p.x);
	float radius = length(p * vec2(1.0, 0.88));
	float lop = 0.09 * cos(angle * 4.0 + age * 2.6) + 0.05 * sin(angle * 7.0 + age * 3.0);
	float body = 1.0 - smoothstep(0.34, 0.75, radius + lop);
	float heat = 1.0 - smoothstep(0.01, 0.46, radius + lop);
	vec4 mark = texture(mask, UV);
	float skin = mark.a * 0.38 * (1.0 - smoothstep(0.57, 0.98, radius));
	ALBEDO = mix(tint.rgb, edge_color.rgb, heat * (1.0 - age) * 0.76);
	ALPHA = clamp((body * 0.83 + skin) * opacity, 0.0, 1.0);
}
