shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
#include "res://assets/vfx/enemies/ice_spike/shaders/ice_common.gdshaderinc"
varying vec3 bary;
varying vec4 instance_data;
void vertex() {
	instance_data = INSTANCE_CUSTOM;
	bary = COLOR.rgb;
	float grow = grow_at(INSTANCE_CUSTOM.b);
	VERTEX *= vec3(pow(max(grow, 0.001), 0.6), grow, pow(max(grow, 0.001), 0.6)) * 1.04;
}
void fragment() {
	float envelope = grow_at(instance_data.b) * (1.0 - smoothstep(shatter_time, shatter_time + 0.3, age));
	vec3 w = max(fwidth(bary), vec3(0.0001));
	vec3 inside = smoothstep(vec3(0.0), w * 3.0, bary);
	float edge = 1.0 - min(inside.x, min(inside.y, inside.z));
	ALBEDO = core_color.rgb * intensity * 1.2;
	ALPHA = envelope * (0.035 + edge * 0.16);
}
