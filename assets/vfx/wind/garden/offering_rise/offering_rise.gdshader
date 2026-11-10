shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.78, 0.15, 1.0);
uniform float strength : hint_range(0.0, 2.0) = 0.0;
void fragment() {
	float height = 1.0 - UV.y;
	float edge_fade = smoothstep(0.0, 0.06, height) * (1.0 - smoothstep(0.72, 1.0, height));
	// Dải sáng chạy từ chân cột lên đỉnh, cùng chiều với các hạt kéo dài.
	float flow = pow(max(0.0, sin(height * 26.0 - TIME * 24.0)), 5.0);
	float strands = pow(max(0.0, sin(UV.x * 75.3982)), 10.0);
	float core = 0.16 + flow * 0.6 + strands * 0.5;
	ALBEDO = mix(tint.rgb, vec3(1.0, 0.98, 0.73), flow * 0.7) * 2.2;
	ALPHA = core * edge_fade * strength;
}
