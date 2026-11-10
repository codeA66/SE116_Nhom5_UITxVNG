shader_type spatial;
// Vẽ đè: năng lượng cuốn vào người phải nổi lên trên thân nhân vật và không bị sàn cắt
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled, blend_mix;
// Pha Hấp thu. Một mesh, UV2.y = loại: 0 dải xoắn từ sách vào ngực (UV.x = 0 ở sách, 1 ở ngực),
// 1 vòng co quanh người (dựng bán kính 1, co theo ring_radius), 2 quả cầu sáng nuốt nhân vật (quad quay về camera).
// Node đặt tại ngực nhân vật; mọi chuyển động tính trên GPU từ progress / flow.
uniform vec4 core_color : source_color = vec4(0.95, 1.0, 1.0, 1.0);
uniform vec4 accent_color : source_color = vec4(0.65, 0.88, 0.94, 1.0);
uniform vec4 rim_color : source_color = vec4(0.14, 0.34, 0.38, 1.0);
uniform float progress = 0.0;
uniform float flow = 0.0;
uniform float dashes = 3.0;
uniform float ring_radius = 1.0;
uniform float orb_radius = 0.0;
uniform float orb_alpha = 0.0;
uniform float stream_alpha = 1.0;
varying float kind;
varying float ring_index;

void vertex() {
	kind = UV2.y;
	ring_index = UV2.x;
	vec3 p = VERTEX;
	if (kind > 0.5 && kind < 1.5) {
		// Mỗi vòng co lệch nhịp một chút: vòng ngoài trễ hơn vòng trong
		float lag = 1.0 + ring_index * 0.18;
		p.xz *= ring_radius * lag;
	} else if (kind > 1.5) {
		mat3 to_local = inverse(mat3(MODEL_MATRIX));
		vec3 r = normalize(to_local * INV_VIEW_MATRIX[0].xyz);
		vec3 u = normalize(to_local * INV_VIEW_MATRIX[1].xyz);
		p = (r * (UV.x - 0.5) + u * (UV.y - 0.5)) * orb_radius * 2.0;
	}
	VERTEX = p;
}

void fragment() {
	vec3 col;
	float a;
	if (kind < 0.5) {
		float across = 1.0 - abs(UV.y * 2.0 - 1.0);
		// Đoạn sáng chạy dọc dải về phía ngực: đọc ra dòng năng lượng đang bị hút vào
		float cell = fract(UV.x * dashes - flow);
		float dash = smoothstep(0.0, 0.55, cell) * (1.0 - smoothstep(0.75, 1.0, cell));
		float ends = smoothstep(0.0, 0.08, UV.x) * (1.0 - smoothstep(0.93, 1.0, UV.x));
		a = smoothstep(0.05, 0.6, across) * mix(0.25, 1.0, dash) * ends * stream_alpha;
		col = mix(accent_color.rgb, core_color.rgb, smoothstep(0.45, 1.0, across) * dash);
	} else if (kind < 1.5) {
		float across = 1.0 - abs(UV.y * 2.0 - 1.0);
		a = smoothstep(0.0, 0.5, across) * stream_alpha * 0.5;
		col = mix(rim_color.rgb, mix(accent_color.rgb, core_color.rgb, across), smoothstep(0.15, 0.4, across));
	} else {
		float d = length(UV - 0.5) * 2.0;
		if (d > 1.0) discard;
		// Lõi trắng đặc, viền màu nguyên tố, mép ngoài đậm để tách khỏi nền sáng
		col = mix(core_color.rgb, accent_color.rgb, smoothstep(0.55, 0.85, d));
		col = mix(col, rim_color.rgb, smoothstep(0.92, 1.0, d) * 0.7);
		a = orb_alpha * (1.0 - smoothstep(0.96, 1.0, d));
	}
	ALBEDO = col;
	ALPHA = clamp(a, 0.0, 1.0);
}
