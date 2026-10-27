shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
#include "res://assets/vfx/enemies/wind_slam/shaders/wind_common.gdshaderinc"
uniform bool warning = false;
uniform bool soft_plume = false;
uniform float seed_value = 0.0;
void vertex() {
	float t = max(age - burst_time, 0.0);
	float angle = age * (2.6 + seed_value * 0.1);
	mat2 spin = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle)));
	VERTEX.xz = spin * VERTEX.xz;
	if (!warning) {
		VERTEX.y *= smoothstep(0.0, 0.18, t);
		VERTEX.xz *= 1.0 + min(t, 1.6) * 0.16;
		VERTEX.y += max(t - 0.5, 0.0) * UV.y * 0.7;
	}
}
void fragment() {
	float t = age - burst_time;
	float n = fbm(vec2(UV.x * 4.5 + seed_value * 19.0, UV.y * 28.0 - age * 8.0));
	float edge = pow(max(sin(UV.x * PI), 0.0), soft_plume ? 1.2 : 3.0);
	float length_fade = smoothstep(0.0, 0.09, UV.y) * (1.0 - smoothstep(0.82, 1.0, UV.y));
	float strands = 0.45 + 0.55 * smoothstep(0.3, 0.7, n);
	float envelope = burst_envelope(t);
	if (warning) envelope = smoothstep(warning_start, warning_start + 0.12, age) * (1.0 - step(burst_time, age));
	ALBEDO = mix(wind_color.rgb, vec3(1), 0.65) * (soft_plume ? 0.85 : 1.5);
	ALPHA = edge * length_fade * envelope * (soft_plume ? smoothstep(0.23, 0.75, n) * 0.42 : strands * (0.4 + n * 0.6));
}
