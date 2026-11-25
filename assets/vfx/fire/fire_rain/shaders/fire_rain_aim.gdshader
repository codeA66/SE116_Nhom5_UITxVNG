shader_type spatial;
// Vạch ngắm Mưa Hỏa Tiễn: khung chữ nhật nét sáng (kiểu nét của game: lõi + quầng exp) trên mặt sàn,
// mũi chevron chạy dọc từ điểm đầu tới điểm cuối, vòng tròn ở điểm đầu. Nét tính theo mét nên dài / rộng bao nhiêu
// nét cũng không bị kéo giãn. Không kiểm tra độ sâu: sàn gồ ghề vẫn thấy trọn vạch.
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, depth_test_disabled, shadows_disabled;

uniform vec2 size = vec2(2.5, 10.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.94, 0.67, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.48, 0.04, 1.0);
uniform vec4 cancel_color : source_color = vec4(0.55, 0.52, 0.5, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
// 0 đang ngắm, 1 vừa thả (sáng bừng)
uniform float commit : hint_range(0.0, 1.0) = 0.0;
uniform float cancel : hint_range(0.0, 1.0) = 0.0;
uniform float stroke = 0.05;
uniform float glow_width = 0.22;
uniform float chevron_spacing = 1.4;
uniform float chevron_speed = 3.0;
uniform float fill_opacity = 0.12;

float line_glow(float d, float core, float glow) {
	return smoothstep(core, core * 0.4, d) + exp(-max(d - core, 0.0) / glow) * 0.55;
}

void fragment() {
	// Toạ độ theo mét: x ngang tính từ trục giữa, a dọc tính từ điểm đầu
	float x = (UV.x - 0.5) * size.x;
	float a = (1.0 - UV.y) * size.y;
	float half_w = size.x * 0.5;
	float edge_d = min(half_w - abs(x), min(a, size.y - a));
	float frame = line_glow(abs(edge_d), stroke, glow_width) * step(0.0, edge_d + glow_width * 3.0);
	// Chevron chạy về phía cuối đường
	float period = max(chevron_spacing, 0.2);
	float local = mod(a - TIME * chevron_speed, period) - period * 0.5;
	float chevron_d = abs(local + abs(x) * 0.45);
	float chevron = smoothstep(stroke * 1.6, 0.0, chevron_d) * step(abs(x), half_w * 0.6) * step(0.6, a) * step(a, size.y - 0.3);
	// Vòng ở điểm đầu
	float ring_r = clamp(half_w * 0.7, 0.25, 1.2);
	float ring = line_glow(abs(length(vec2(x, a)) - ring_r), stroke, glow_width * 0.6);
	float inside = step(0.0, edge_d);
	float pulse = 0.85 + 0.15 * sin(TIME * 9.0);
	float shape = max(max(frame, chevron * 0.8 * pulse), ring);
	vec3 color = mix(glow_color.rgb, core_color.rgb, clamp(shape - 0.55, 0.0, 1.0) * 2.0);
	color = mix(color, core_color.rgb * 1.4, commit);
	color = mix(color, cancel_color.rgb, cancel);
	ALBEDO = color;
	ALPHA = clamp(shape + inside * fill_opacity * (1.0 + commit * 2.0), 0.0, 1.0) * opacity;
}
