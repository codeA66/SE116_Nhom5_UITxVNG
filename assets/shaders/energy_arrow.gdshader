// Hình mũi tên bằng ánh sáng bọc quanh model tên: đầu nhọn, thân mảnh, đuôi chữ V có khuyết.
// Gắn lên QuadMesh 1x1, node con của tên với hướng mặc định (+Z của node = hướng bay, gốc node = tâm thân sáng).
// Quad xoay quanh trục bay để luôn quay mặt về camera (như tia streak), kích thước tính bằng mét qua uniform.
// Lõi chỉ sáng vừa (fill_alpha) để vẫn thấy model bên trong; quầng sáng (glow) loang ra quanh viền.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(0.78, 0.9, 1.0, 1.0);
uniform float intensity = 2.2;
// Chiều dài cả thân sáng và bề ngang quad (m); quad phải rộng hơn đuôi + quầng sáng
uniform float body_length = 0.95;
uniform float quad_width = 0.42;
uniform float head_length = 0.2;
uniform float head_half_width = 0.07;
// Ngạnh đầu tên vuốt ngược ra sau bao nhiêu mét ở mép ngoài
uniform float barb_sweep = 0.06;
uniform float shaft_half_width = 0.018;
uniform float fletch_length = 0.24;
uniform float fletch_half_width = 0.09;
// Độ sâu khuyết chữ V ở đuôi (m)
uniform float notch_depth = 0.1;
// Độ mềm mép hình (m)
uniform float edge_softness = 0.008;
// Bề dày lõi trắng tính từ mép vào (m)
uniform float core_width = 0.012;
uniform float fill_alpha : hint_range(0.0, 1.0) = 0.3;
// Quầng sáng quanh viền: độ mạnh và bán kính (m). Hình được thu vào trong quad đúng bằng bán kính này
// để quầng tắt hẳn trước mép quad (không bị cắt thành khung chữ nhật)
uniform float glow_strength : hint_range(0.0, 1.0) = 0.35;
uniform float glow_radius = 0.045;
// Nhấp nháy nhẹ cho cảm giác năng lượng; 0 = tắt
uniform float flicker = 0.12;

varying vec2 v_pos;

void vertex() {
	vec3 center = MODEL_MATRIX[3].xyz;
	vec3 axis = normalize(MODEL_MATRIX[2].xyz);
	vec3 view_dir = normalize(INV_VIEW_MATRIX[3].xyz - center);
	vec3 side = cross(axis, view_dir);
	side = side / max(length(side), 0.00001);
	vec3 world = center + axis * VERTEX.y * body_length + side * VERTEX.x * quad_width;
	// x: mét ngang so với trục; y: mét từ đuôi (0) tới mũi (body_length)
	v_pos = vec2(VERTEX.x * quad_width, (VERTEX.y + 0.5) * body_length);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	// Toạ độ trong vùng hình (đã trừ lề quầng sáng ở hai đầu)
	float shape_length = max(body_length - 2.0 * glow_radius, 0.0001);
	float u = v_pos.y - glow_radius;
	float av = abs(v_pos.x);
	float head_start = shape_length - head_length;
	// Khoảng cách (m, xấp xỉ) vào trong hình: dương = trong, âm = ngoài. Hình = hợp (max) của thân+đuôi và đầu tên
	float half_w = shaft_half_width;
	if (u < fletch_length) {
		half_w = mix(fletch_half_width, shaft_half_width, u / max(fletch_length, 0.0001));
	}
	float notch = u - notch_depth * (1.0 - clamp(av / max(fletch_half_width, 0.0001), 0.0, 1.0));
	float shaft_inside = min(half_w - av, notch);
	// Đầu tên tam giác, ngạnh vuốt ngược ra sau barb_sweep mét ở mép ngoài (không cắt thẳng đứng)
	float head_w = min(head_half_width * (shape_length - u) / max(head_length, 0.0001), head_half_width);
	float barb_t = clamp((av - shaft_half_width) / max(head_half_width - shaft_half_width, 0.0001), 0.0, 1.0);
	float head_inside = min(head_w - av, u - (head_start - barb_sweep * barb_t));
	float inside = max(shaft_inside, head_inside);
	inside = min(inside, min(u, shape_length - u));

	float body = smoothstep(-edge_softness, edge_softness, inside);
	float core = 1.0 - smoothstep(0.0, core_width, abs(inside));
	float glow_t = 1.0 - clamp(-inside / max(glow_radius, 0.0001), 0.0, 1.0);
	float glow = glow_t * glow_t * glow_strength * (1.0 - body);
	float pulse = 1.0 - flicker + flicker * sin(TIME * 37.0 + u * 9.0);

	vec3 col = mix(tint.rgb, vec3(1.0), core * body) * intensity * pulse;
	ALBEDO = col;
	ALPHA = clamp(body * mix(fill_alpha, 1.0, core) + glow, 0.0, 1.0) * tint.a;
}
