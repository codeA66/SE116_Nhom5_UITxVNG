shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
#include "res://assets/vfx/enemies/wolf/dark_claw/shaders/claw_common.gdshaderinc"

void fragment() {
	float t = claw_time();
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float angle = atan(p.y, p.x);
	float n = fbm(p * 5.0 + shape_seed + vec2(t * 2.0));
	float curl = angle * 3.0 + r * 11.0 - t * 16.0 + n * 5.0;
	float arc = pow(max(sin(curl), 0.0), 12.0);
	float band = exp(-pow((r - 0.48 - n * 0.14) * 8.0, 2.0));
	float envelope = smoothstep(0.0, 0.055, t) * (1.0 - smoothstep(0.12, 0.28, t));
	ALBEDO = edge_color.rgb * intensity * (0.6 + n);
	ALBEDO = palette_color(ALBEDO);
	ALPHA = arc * band * envelope * 0.75;
}
