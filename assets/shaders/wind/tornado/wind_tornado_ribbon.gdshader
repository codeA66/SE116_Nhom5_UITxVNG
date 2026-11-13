shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled, fog_disabled;

// Dải gió của cột lốc: mỗi dải là một nét cọ (mỏng hai đầu, dày giữa) chạy dọc dải và xoay quanh trục Y.
// Mesh dựng sẵn ở không gian đơn vị (cao 1, bán kính miệng 1); COLOR.r = pha riêng, COLOR.g = hệ số tốc độ xoay.
uniform vec4 core_color : source_color = vec4(0.953, 0.988, 1.0, 1.0);
uniform vec4 rim_color : source_color = vec4(0.30, 0.62, 0.73, 1.0);
// Đồng hồ do script đẩy vào: lốc lấy từ pool luôn bắt đầu cùng pha
uniform float time = 0.0;
uniform float alpha : hint_range(0.0, 1.0) = 1.0;
uniform float spin = 7.0;
uniform float scroll = 1.6;
uniform float dash_count = 2.0;
uniform float dash_fill : hint_range(0.05, 1.0) = 0.6;
uniform float end_fade : hint_range(0.0, 0.5) = 0.12;
// Lắc ngang theo chiều cao để cột trông sống, không cứng như ống
uniform float wobble = 0.06;

void vertex() {
	float angle = time * spin * COLOR.g;
	float c = cos(angle);
	float s = sin(angle);
	VERTEX.xz = mat2(vec2(c, -s), vec2(s, c)) * VERTEX.xz;
	VERTEX.xz += vec2(sin(time * 3.1 + VERTEX.y * 2.0), cos(time * 2.4 + VERTEX.y * 1.6)) * wobble * VERTEX.y;
}

void fragment() {
	float s = fract(UV.x * dash_count - time * scroll + COLOR.r);
	float inside = step(s, dash_fill);
	float k = clamp(s / dash_fill, 0.0, 1.0);
	float width = mix(0.18, 1.0, sin(k * PI));
	float band = 1.0 - abs(UV.y * 2.0 - 1.0);
	float edge = 1.0 - width;
	float mask = inside * smoothstep(edge, edge + 0.12, band);
	float ends = smoothstep(0.0, end_fade, UV.x) * smoothstep(1.0, 1.0 - end_fade, UV.x);
	float a = mask * ends * alpha;
	if (a < 0.04) {
		discard;
	}
	// Viền tối hơn để vẫn đọc được trên sàn sáng
	ALBEDO = mix(rim_color.rgb, core_color.rgb, smoothstep(edge + 0.1, edge + 0.1 + width * 0.5, band));
	ALPHA = a;
}
