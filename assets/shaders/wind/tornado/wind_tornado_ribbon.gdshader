shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled, fog_disabled;

// Dải gió của cột lốc: mỗi dải là một nét cọ (mỏng hai đầu, dày giữa) chạy dọc dải và xoay quanh trục Y.
// Mesh dựng sẵn ở không gian đơn vị (cao 1, bán kính miệng 1); COLOR.r = pha riêng, COLOR.g = hệ số tốc độ xoay.
// Tô khối như nét cọ: mép tối -> thân xám -> mép sáng, để dải gió đọc ra khối 3D (kiểu lốc vẽ tay đậm đặc)
uniform vec4 core_color : source_color = vec4(0.96, 0.97, 0.98, 1.0);
uniform vec4 mid_color : source_color = vec4(0.4, 0.44, 0.5, 1.0);
uniform vec4 rim_color : source_color = vec4(0.08, 0.09, 0.12, 1.0);
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
	// Bề ngang dải: phía UV.y nhỏ là mặt tối, phía lớn là mặt hứng sáng
	float across = clamp((UV.y - edge * 0.5) / max(1.0 - edge, 0.001), 0.0, 1.0);
	vec3 col = mix(rim_color.rgb, mid_color.rgb, smoothstep(0.05, 0.55, across));
	// Chỉ một vệt mảnh ở mép sáng, phần đầu nét mới bắt sáng: giữ tông xám tối là chủ đạo
	col = mix(col, core_color.rgb, smoothstep(0.72, 0.95, across) * smoothstep(0.25, 0.6, k));
	ALBEDO = col;
	ALPHA = a;
}
