shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, shadows_disabled;
#include "res://assets/vfx/enemies/wind_slam/shaders/wind_common.gdshaderinc"
uniform bool debris = false;
varying vec4 instance_data;
void vertex() {
	instance_data = INSTANCE_CUSTOM;
	float t = max(age - burst_time, 0.0);
	float a = t * (debris ? 3.2 : 5.0) + INSTANCE_CUSTOM.r * 6.283185;
	mat2 spin = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a)));
	VERTEX.xy = spin * VERTEX.xy;
	vec3 offset = vec3(cos(a), 0.0, sin(a)) * t * (debris ? 0.6 : 0.9);
	offset.y = max((3.5 + INSTANCE_CUSTOM.g * 3.5) * t - (debris ? 4.5 : 1.7) * t * t, 0.0);
	MODELVIEW_MATRIX = VIEW_MATRIX * MODEL_MATRIX;
	MODELVIEW_MATRIX[3] += VIEW_MATRIX * vec4(offset, 0.0);
}
void fragment() {
	float t = age - burst_time;
	ALBEDO = debris ? mix(vec3(0.15, 0.20, 0.25), vec3(0.42, 0.48, 0.53), instance_data.b) * (0.65 + abs(NORMAL.y) * 0.6) : vec3(1.0);
	ALPHA = burst_envelope(t) * (debris ? 1.0 : 0.85);
}
