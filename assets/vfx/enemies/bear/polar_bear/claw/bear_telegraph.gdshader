shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
#include "res://assets/vfx/enemies/wolf/dark_claw/shaders/claw_common.gdshaderinc"
uniform float telegraph_age = -1.0;
uniform float telegraph_duration = 1.5;
uniform vec4 tint : source_color = vec4(0.1, 0.85, 1.0, 1.0);
uniform bool soft_layer = false;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float angle = atan(p.y, p.x);
	float n = fbm(p * 4.0 + vec2(telegraph_age * 0.8));
	float curl = angle * 3.0 + r * 12.0 - telegraph_age * 5.0 + n * 3.0;
	float arcs = pow(max(sin(curl), 0.0), 4.0);
	float band = exp(-pow((r - 0.55 - n * 0.12) * 6.0, 2.0));
	float ring = exp(-pow((r - 0.78) * 65.0, 2.0)) * (0.35 + arcs * 0.65);
	float envelope = smoothstep(0.0, 0.14, telegraph_age) * (1.0 - smoothstep(telegraph_duration - 0.05, telegraph_duration + 0.10, telegraph_age));
	float charge = 0.65 + 0.35 * clamp(telegraph_age / telegraph_duration, 0.0, 1.0);
	ALBEDO = mix(tint.rgb * 1.6, vec3(2.4), ring * 0.45);
	ALPHA = (soft_layer ? band * 0.20 : arcs * band * 0.85 + ring * 0.65) * envelope * charge;
}
