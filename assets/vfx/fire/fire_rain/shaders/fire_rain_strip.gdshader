shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;

uniform vec2 size = vec2(2.5, 10.0);
uniform float reveal = 0.0;
uniform float heat : hint_range(0.0, 1.0) = 0.0;
uniform float scorch : hint_range(0.0, 1.0) = 0.0;
uniform vec4 char_color : source_color = vec4(0.085, 0.042, 0.033, 1.0);
uniform vec4 coal_color : source_color = vec4(0.23, 0.105, 0.065, 1.0);
uniform vec4 ember_color : source_color = vec4(0.84, 0.16, 0.035, 1.0);
uniform float ash_spacing = 1.65;
uniform float crack_width = 0.036;
uniform float outline_width = 0.10;
uniform float outline_opacity = 0.2;

float segment(vec2 p, vec2 a, vec2 b) {
	vec2 axis = b - a;
	return length(p - a - axis * clamp(dot(p - a, axis) / dot(axis, axis), 0.0, 1.0));
}

void fragment() {
	float x = (UV.x - 0.5) * size.x;
	float along = (1.0 - UV.y) * size.y;
	float half_w = size.x * 0.5;
	float feather = min(0.27, half_w * 0.72);
	float edge = half_w * (0.88 + 0.039 * sin(along * 1.82 + x * 0.28)
		+ 0.018 * sin(along * 7.1 + x * 1.6) + 0.028 * sin(along * 3.15));
	float ends = min(along, size.y - along);
	float shown = 1.0 - smoothstep(reveal - 0.06, reveal + 0.16, along);
	float soil = (1.0 - smoothstep(edge - feather, edge, abs(x))) * smoothstep(0.0, min(0.48, size.y * 0.4), ends);

	// Các nét ngắn trong từng mảng than để nền tối vẫn đọc được giữa các cụm lửa.
	float block = max(0.3, ash_spacing);
	float cell = floor(along / block);
	float side = mod(cell, 2.0) * 2.0 - 1.0;
	float width = min(half_w * 0.86, 0.85);
	vec2 p = vec2(x * side, mod(along, block) - block * 0.47);
	vec2 first = vec2(-width * 0.83, -block * 0.23);
	vec2 joint = vec2(width * 0.12, -block * 0.08);
	vec2 elbow = vec2(-width * 0.02, block * 0.09);
	vec2 last = vec2(width * 0.56, block * 0.24);
	float distance = min(min(segment(p, first, joint), segment(p, joint, elbow)),
		min(segment(p, elbow, last), segment(p, elbow, vec2(-width * 0.63, block * 0.19))));
	float fissure = 1.0 - smoothstep(crack_width * 0.22, crack_width, distance);
	float coal = 1.0 - smoothstep(0.11, 0.55, distance);
	float ember = fissure * heat * (0.55 + 0.17 * sin(cell * 2.85 + floor(TIME * 8.0) * 0.45));
	float border = min(half_w - abs(x), ends);
	float rim = (1.0 - smoothstep(0.0, min(outline_width, half_w * 0.5), border))
		* outline_opacity * heat * smoothstep(-0.38, 0.6, sin(along * 6.1 + x * 3.0));
	vec3 ground = mix(char_color.rgb, coal_color.rgb, coal * 0.27);
	ground = mix(ground, ember_color.rgb, clamp(max(ember, rim * 0.75), 0.0, 1.0));
	ALBEDO = ground;
	ALPHA = clamp(soil * max(heat * 0.91, scorch * 0.78) + rim, 0.0, 1.0) * shown;
}
