shader_type spatial;
// Nền dải cháy của Mưa Hỏa Tiễn: vết cháy xém nâu sẫm mép rách (không phải khối đen đặc), lốm đốm tro,
// dưới mỗi cụm lửa có quầng sáng cam ấm loang ra như ánh lửa hắt xuống đất (chập chờn). Không vẽ vệt nứt sáng:
// nứt sáng trên nền đen đọc thành dung nham chứ không phải lửa. Hiện dần theo các quả đã rơi (reveal, mét từ điểm đầu),
// tắt lửa thì quầng sáng tắt, còn vết xém mờ dần (scorch). Nét tính theo mét nên dài / rộng bao nhiêu cũng không giãn.
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;

uniform vec2 size = vec2(2.5, 10.0);
uniform float reveal = 0.0;
uniform float heat : hint_range(0.0, 1.0) = 0.0;
uniform float scorch : hint_range(0.0, 1.0) = 0.0;
// Số cụm lửa dọc đường (= số cầu lửa): quầng sáng nằm giữa đoạn của mỗi quả
uniform float pool_count = 6.0;
uniform vec4 char_color : source_color = vec4(0.17, 0.085, 0.05, 1.0);
uniform vec4 ash_color : source_color = vec4(0.09, 0.05, 0.035, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.45, 0.08, 1.0);
uniform vec4 glow_core_color : source_color = vec4(1.0, 0.72, 0.3, 1.0);
uniform float char_opacity = 0.5;
uniform float glow_opacity = 0.6;
uniform float rim_opacity = 0.22;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	float x = (UV.x - 0.5) * size.x;
	float along = (1.0 - UV.y) * size.y;
	float half_w = size.x * 0.5;
	// Mép rách mềm theo noise
	float edge = half_w * (0.8 + 0.2 * noise(vec2(along * 1.4, 2.0)));
	float feather = min(0.35, half_w * 0.6);
	float ends = min(along, size.y - along);
	float soil = (1.0 - smoothstep(edge - feather, edge, abs(x))) * smoothstep(0.0, min(0.5, size.y * 0.3), ends);
	float shown = 1.0 - smoothstep(reveal - 0.1, reveal + 0.2, along);
	// Vết xém không đều: chỗ đậm chỗ nhạt + lốm đốm tro
	float blotch = noise(vec2(x, along) * 1.1) * 0.6 + noise(vec2(x, along) * 2.7 + 3.0) * 0.4;
	float ash = step(0.82, hash(floor(vec2(x, along) / 0.22)));
	vec3 ground = mix(char_color.rgb, ash_color.rgb, clamp(ash * 0.7 + (blotch - 0.5) * 0.6, 0.0, 1.0));
	float ground_alpha = soil * char_opacity * (0.75 + 0.5 * blotch) * max(heat, scorch);
	// Quầng sáng dưới mỗi cụm lửa
	float count = max(pool_count, 1.0);
	float seg = size.y / count;
	float cell = floor(along / seg);
	vec2 local = vec2(x, along - (cell + 0.5) * seg);
	float pool_r = max(min(half_w * 0.95, seg * 0.6), 0.15);
	float flicker = 0.8 + 0.2 * sin(TIME * 7.0 + cell * 2.3) * sin(TIME * 4.3 + cell * 1.7);
	float pool = 1.0 - smoothstep(0.0, pool_r, length(local * vec2(1.0, 0.8)));
	pool = pool * pool * flicker * heat * step(cell, count - 1.0);
	vec3 glow = mix(glow_color.rgb, glow_core_color.rgb, clamp(pool * 1.6 - 0.4, 0.0, 1.0));
	// Viền ấm rất nhẹ chỉ khi đang cháy, để biết ranh giới vùng đốt
	float border = min(half_w - abs(x), ends);
	float rim = (1.0 - smoothstep(0.0, min(0.12, half_w * 0.5), border)) * rim_opacity * heat;
	float glow_alpha = pool * glow_opacity;
	ALBEDO = mix(ground, glow, clamp(glow_alpha / max(ground_alpha + glow_alpha, 0.001), 0.0, 1.0));
	ALBEDO = mix(ALBEDO, glow_color.rgb, clamp(rim * 2.0, 0.0, 1.0));
	ALPHA = clamp(ground_alpha + glow_alpha + rim, 0.0, 1.0) * shown;
}
