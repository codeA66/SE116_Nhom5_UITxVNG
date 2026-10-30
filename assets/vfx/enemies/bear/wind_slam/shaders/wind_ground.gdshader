shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
#include "res://assets/vfx/enemies/bear/wind_slam/shaders/wind_common.gdshaderinc"
uniform int layer_kind = 0;
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p), a = atan(p.y, p.x);
	float charge = clamp((age - warning_start) / max(burst_time - warning_start, 0.01), 0.0, 1.0);
	float n = fbm(vec2(a * 3.5 - age * 5.0, r * 14.0 - age * 3.0));
	float rim = exp(-pow((r - 0.86) * 100.0, 2.0));
	float bands = exp(-pow((r - 0.83 - sin(a * 6.0 - age * 10.0) * 0.028) * 48.0, 2.0));
	float spiral = pow(max(sin(a * 5.0 + r * 21.0 - age * 13.0), 0.0), 12.0);
	float mask = rim;
	if (layer_kind == 1) mask = (exp(-pow((r - 0.85) * 23.0, 2.0)) * (0.15 + n * 0.5) + bands * n * 0.9);
	if (layer_kind == 2) mask = (spiral * n * 0.55 + n * 0.12) * smoothstep(0.0, 0.22, r) * (1.0 - smoothstep(0.65, 0.9, r));
	float gate = smoothstep(warning_start, warning_start + 0.08, age) * (1.0 - step(burst_time, age));
	ALBEDO = mix(wind_color.rgb, vec3(1.0), 0.65) * (1.0 + charge * 0.6);
	ALPHA = mask * gate * (0.6 + charge * 0.4);
}
