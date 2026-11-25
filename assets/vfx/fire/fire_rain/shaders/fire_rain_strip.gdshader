shader_type spatial;
// Dải đất cháy dọc đường lửa: nền cháy xém mép rách, các vệt nứt dung nham chập chờn (sáng theo heat),
// hiện dần theo các quả đã rơi (reveal tính bằng mét từ điểm đầu), tắt lửa thì chỉ còn vết xém rồi mờ (scorch).
// Nét tính theo mét nên dài / rộng bao nhiêu cũng không giãn hoa văn.
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;

uniform vec2 size = vec2(2.5, 10.0);
uniform float reveal = 0.0;
uniform float heat : hint_range(0.0, 1.0) = 0.0;
uniform float scorch : hint_range(0.0, 1.0) = 0.0;
uniform vec4 char_color : source_color = vec4(0.12, 0.045, 0.02, 1.0);
uniform vec4 ember_color : source_color = vec4(0.9, 0.22, 0.03, 1.0);
uniform vec4 hot_color : source_color = vec4(1.0, 0.62, 0.16, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.94, 0.67, 1.0);
uniform float crack_scale = 1.3;
uniform vec4 outline_color : source_color = vec4(1.0, 0.9, 0.7, 1.0);
uniform float outline_width = 0.06;
uniform float outline_opacity = 0.7;

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
	float a = (1.0 - UV.y) * size.y;
	vec2 m = vec2(x, a);
	// Mép rách: bề ngang dao động theo noise dọc đường; hai đầu bo tròn
	float half_w = size.x * 0.5 * (0.82 + 0.18 * noise(vec2(a * 1.7, 3.0)));
	float edge = smoothstep(half_w, half_w * 0.7, abs(x));
	float ends = smoothstep(0.0, min(0.6, size.y * 0.2), a) * smoothstep(0.0, min(0.6, size.y * 0.2), size.y - a);
	float shown = smoothstep(reveal + 0.3, reveal - 0.3, a);
	float mask = edge * ends * shown;
	// Vệt nứt: gờ của noise hai tầng, chập chờn theo thời gian
	float n = noise(m * crack_scale) * 0.65 + noise(m * crack_scale * 2.3 + 5.0) * 0.35;
	float ridge = 1.0 - abs(n * 2.0 - 1.0);
	float flicker = 0.75 + 0.25 * noise(m * 0.8 + vec2(0.0, TIME * 2.5));
	float crack = smoothstep(0.78, 0.95, ridge) * flicker;
	float glow = smoothstep(0.55, 0.95, ridge) * flicker * 0.45;
	// Giữa dải nóng hơn mép
	float center_heat = 1.0 - smoothstep(0.0, half_w, abs(x)) * 0.6;
	float hot = clamp((crack + glow) * center_heat, 0.0, 1.0) * heat;
	vec3 color = char_color.rgb;
	color = mix(color, ember_color.rgb, clamp(glow * 2.0, 0.0, 1.0) * heat);
	color = mix(color, hot_color.rgb, clamp(crack * 1.2, 0.0, 1.0) * heat);
	color = mix(color, core_color.rgb, clamp(crack - 0.6, 0.0, 1.0) * heat * center_heat);
	float base = 0.62 * max(heat, scorch);
	// Viền mảnh bao trọn vùng đốt (đúng cỡ vùng trúng, không rách): người chơi biết rõ ranh giới dải cháy
	float edge_d = min(size.x * 0.5 - abs(x), min(a, size.y - a));
	float outline = smoothstep(outline_width, outline_width * 0.3, abs(edge_d)) * outline_opacity * heat * shown;
	vec3 final_color = mix(color, outline_color.rgb, clamp(outline * 2.0, 0.0, 1.0));
	ALBEDO = final_color;
	ALPHA = clamp(clamp(base + hot, 0.0, 1.0) * mask + outline, 0.0, 1.0);
}
