shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
#include "res://assets/vfx/enemies/wolf/dark_claw/shaders/claw_common.gdshaderinc"

uniform bool streaks = false;
varying float particle_alpha;
varying float variant;

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	float t = claw_time();
	float birth = 0.14 + c.b * 0.16;
	float p = max(t - birth, 0.0);
	float lifetime = 0.38 + c.a * 0.40;
	float alive = step(birth, t) * (1.0 - smoothstep(lifetime * 0.35, lifetime, p));
	float angle = 0.94 + (c.r - 0.5) * (streaks ? 0.5 : 3.1);
	float velocity = (0.6 + c.g * 2.8) * (streaks ? 1.6 : 1.0);
	vec2 travel = vec2(cos(angle), sin(angle)) * p * velocity;
	travel.y -= p * p * 0.85;
	float length_m = streaks ? (0.32 + c.a * 0.9) : (0.025 + c.a * 0.10);
	float width_m = streaks ? (0.007 + c.g * 0.015) : (0.008 + c.g * 0.024);
	vec2 q = spin2(VERTEX.xy * vec2(length_m, width_m) * (1.0 - p * 0.7), angle);
	VERTEX.xy = q + travel;
	VERTEX.z += p * (c.g - 0.5) * 0.5;
	particle_alpha = alive * (streaks ? 0.65 : 1.0);
	variant = c.a;
}

void fragment() {
	vec2 p = abs(UV * 2.0 - 1.0);
	float shape = 1.0 - smoothstep(0.70, 1.0, p.x + p.y);
	float hot = pow(max(1.0 - length(p), 0.0), 4.0) * step(0.66, variant);
	ALBEDO = mix(edge_color.rgb * 1.6, vec3(3.0, 0.9, 0.6), hot) * intensity;
	ALBEDO = palette_color(ALBEDO);
	ALPHA = shape * particle_alpha;
}
