shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
#include "res://assets/vfx/enemies/ice_spike/shaders/ice_common.gdshaderinc"
void fragment() {
	vec2 p = UV * vec2(17.0, 7.0);
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float first = 9.0;
	float second = 9.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 offset = vec2(float(x), float(y));
			vec2 point = vec2(hash21(cell + offset), hash21(cell + offset + 61.3));
			float d = length(offset + point - f);
			if (d < first) { second = first; first = d; }
			else if (d < second) { second = d; }
		}
	}
	float edge = second - first;
	float crack = 1.0 - smoothstep(0.015, 0.065, edge);
	float head = clamp(age / max(growth_time, 0.01), 0.0, 1.0);
	float reveal = 1.0 - smoothstep(head - 0.025, head + 0.025, UV.x);
	float width = 0.12 + UV.x * 0.72;
	float path = 1.0 - smoothstep(width * 0.6, width, abs(UV.y * 2.0 - 1.0));
	float fade = 1.0 - smoothstep(shatter_time + 0.2, duration, age);
	ALBEDO = mix(core_color.rgb, edge_color.rgb * 1.7, pow(crack, 3.0)) * intensity;
	ALPHA = (crack * 0.75 + exp(-edge * 9.0) * 0.12) * reveal * path * fade * step(0.0, age);
}
