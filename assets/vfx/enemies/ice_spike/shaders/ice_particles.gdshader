shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
#include "res://assets/vfx/enemies/ice_spike/shaders/ice_common.gdshaderinc"
uniform bool shatter = false;
varying float particle_alpha;
varying vec3 bary;
void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	bary = COLOR.rgb;
	float birth = shatter ? shatter_time + c.b * 0.12 : c.b * growth_time;
	float p = max(age - birth, 0.0);
	float life = shatter ? 1.0 + c.a * 0.45 : 2.5;
	vec3 scale_value = max(vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz)), vec3(0.01));
	vec3 velocity = vec3((c.g - 0.5) * 4.0, 2.0 + c.a * 3.0, (c.r - 0.5) * 4.0);
	vec3 offset = shatter ? velocity * p + vec3(0, -3.5 * p * p, 0) : vec3(sin(c.g * 20.0 + p) * 0.15, p * 0.4, cos(c.a * 17.0 + p) * 0.15);
	VERTEX += offset / scale_value;
	particle_alpha = step(birth, age) * (1.0 - smoothstep(life * 0.35, life, p));
	if (!shatter) { particle_alpha *= 1.0 - smoothstep(shatter_time, duration, age); }
}
void fragment() {
	float edge = 1.0 - min(bary.x, min(bary.y, bary.z));
	ALBEDO = mix(core_color.rgb, edge_color.rgb * 2.0, edge) * intensity;
	ALPHA = particle_alpha;
}
