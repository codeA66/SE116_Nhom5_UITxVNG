shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform float age = -1.0;
uniform vec4 tint : source_color = vec4(0.25, 0.75, 1.0, 1.0);
void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float radius = 0.05 + clamp(age / 0.45, 0.0, 1.0) * 0.86;
	float ring = exp(-pow((r - radius) * 55.0, 2.0));
	float inner = exp(-r * 9.0) * exp(-max(age, 0.0) * 18.0);
	ALBEDO = tint.rgb * 2.0;
	ALPHA = (ring + inner) * (1.0 - smoothstep(0.0, 0.55, age)) * step(0.0, age);
}
