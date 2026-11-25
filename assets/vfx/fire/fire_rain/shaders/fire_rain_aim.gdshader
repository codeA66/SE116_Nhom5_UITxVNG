shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, depth_test_disabled, shadows_disabled;

uniform vec2 size = vec2(2.5, 10.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.94, 0.67, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.48, 0.035, 1.0);
uniform vec4 cancel_color : source_color = vec4(0.55, 0.52, 0.5, 1.0);
uniform float opacity = 1.0;
uniform float commit = 0.0;
uniform float cancel = 0.0;
uniform float stroke = 0.036;
uniform float glow_width = 0.10;
uniform float chevron_spacing = 2.8;
uniform float chevron_speed = 2.5;
uniform float fill_opacity = 0.11;

void fragment() {
	float x = abs((UV.x - 0.5) * size.x);
	float a = (1.0 - UV.y) * size.y;
	float half_w = size.x * 0.5;
	float cap = min(a, size.y - a);
	float edge = min(half_w - x, cap);
	float line = min(stroke, half_w * 0.33);
	float glow = min(glow_width, half_w * 0.62);
	float detail = 1.0 - smoothstep(line * 0.45, line, edge);
	float border = 1.0 - smoothstep(0.0, glow, edge);
	float ends = 1.0 - smoothstep(0.0, min(0.12, size.y * 0.2), cap);
	float mark_phase = mod(a - TIME * chevron_speed, max(chevron_spacing, 0.3));
	float mark = (1.0 - smoothstep(line * 0.6, line * 1.8, abs(mark_phase - 0.28 + x * 0.75)))
		* (1.0 - smoothstep(min(0.30, half_w * 0.48), min(0.46, half_w * 0.72), x))
		* smoothstep(0.08, 0.32, cap);
	float alpha = max(detail * (0.68 + ends * 0.26), max(mark * 0.78, border * 0.42));
	float sweep = commit * (0.55 + 0.45 * ends);
	vec3 tint = mix(glow_color.rgb, core_color.rgb, max(detail * 0.53, sweep));
	ALBEDO = mix(tint, cancel_color.rgb, cancel);
	ALPHA = clamp(alpha + fill_opacity * (1.0 + 2.0 * commit), 0.0, 1.0) * opacity;
}
