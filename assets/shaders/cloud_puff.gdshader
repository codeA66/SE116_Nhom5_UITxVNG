shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float edge = length(p * vec2(1.0, 1.1));
	float wisps = sin(p.x * 11.0 + sin(p.y * 8.0)) * 0.045;
	ALBEDO = vec3(0.75, 0.79, 0.82);
	ALPHA = (1.0 - smoothstep(0.25, 0.98, edge + wisps)) * 0.38;
}
