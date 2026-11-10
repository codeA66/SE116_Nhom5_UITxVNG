shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.73, 0.12, 1.0);
uniform float strength : hint_range(0.0, 2.0) = 1.0;
void fragment() {
	float radius = length(UV * 2.0 - 1.0);
	float pulse = 0.78 + 0.06 * sin(TIME * 4.5);
	float aa = max(fwidth(radius), 0.004);
	float core = 1.0 - smoothstep(0.016, 0.016 + aa, abs(radius - pulse));
	float soft_glow = exp(-abs(radius - pulse) * 22.0) * 0.55;
	ALBEDO = mix(tint.rgb, vec3(1.0, 0.97, 0.65), core * 0.65) * 1.8;
	ALPHA = (core * 0.8 + soft_glow) * strength * (0.85 + 0.15 * sin(TIME * 4.5));
}
