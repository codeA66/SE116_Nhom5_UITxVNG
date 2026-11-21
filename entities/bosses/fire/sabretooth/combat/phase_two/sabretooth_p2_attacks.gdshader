shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// Shader VFX cho 2 chiêu Phase 2 mới của Hổ Răng Kiếm bám sát Concept Art (chuẩn OpenGL 3.3 Compatibility):
// kind == 0: Khối 3D đầu hổ răng kiếm lửa truy đuổi 7s (nanh trắng-vàng, mắt xếch trắng-vàng, sọ lửa điêu khắc, họng rực, bờm & đuôi lửa)
// kind == 1: Vệt nổ sao lửa + vết cháy đen & khe nứt nham thạch bám tường (Concept Art Panel 3)
// kind == 2: Cảnh báo 3 vết cào UỐN CONG trên sàn (vết giữa bự & dài hơn, 0.7s)
// kind == 3: Hiệu ứng cào lửa uốn cong quét trái -> phải / dọc
// kind == 4: 3 vết nứt cong răng cưa + nhiều nhánh nứt phụ tỏa ra xung quanh (tồn tại 30s, sáng dần theo chu kỳ 5s)
// kind == 5: Lửa nhọn phun trào hình quạt dọc theo khe nứt cong + lớp khói núi lửa đen bốc trên đỉnh (Concept Art Panel 4)
// kind == 6: Đá bazan vỡ sắc cạnh & cụm khói billboard mềm bay cuộn lên trời
uniform int kind = 0;
uniform float progress = 0.0;
uniform float charge = 0.0;
uniform float erupt = 0.0;
uniform float fade = 1.0;
uniform vec2 zone_half = vec2(3.8, 2.1);

varying vec2 v_uv;
varying vec4 v_col;
varying vec3 v_pos;
varying vec3 v_nrm;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 38.41);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

float fbm(vec2 p) {
	float v = 0.0;
	v += 0.55 * vnoise(p);
	v += 0.30 * vnoise(p * 2.17 + vec2(11.3, 7.9));
	v += 0.15 * vnoise(p * 4.35 - vec2(5.1, 19.4));
	return v;
}

// 3 vết cào UỐN CONG tự nhiên (không thẳng băng nhàm chán): vết giữa bự & dài hơn 2 vết bên, vuốt nhọn sạch không tia dư.
vec3 triple_claw_dist(vec2 p, float jag_val) {
	float x_c = abs(p.x) / 0.96;
	float x_s = abs(p.x) / 0.80;
	float env_c = pow(max(0.0, 1.0 - x_c * x_c), 0.58);
	float env_s = pow(max(0.0, 1.0 - x_s * x_s), 0.65);

	// Độ cong mềm hình vòng cung vuốt móng + dao động răng cưa tự nhiên.
	float arc_c = 0.19 * (1.0 - p.x * p.x);
	float arc_s = 0.16 * (1.0 - p.x * p.x);
	float bend = (jag_val - 0.5) * 0.095;

	float w_c = 0.195 * env_c;
	float w_s = 0.105 * env_s;
	float dc = abs(p.y - (arc_c + bend)) / max(0.002, w_c);
	float d1 = abs(p.y - (0.50 + arc_s + bend * 0.85)) / max(0.002, w_s);
	float d2 = abs(p.y - (-0.50 + arc_s - bend * 0.85)) / max(0.002, w_s);

	float best_d = min(dc, min(d1, d2));
	float is_center = step(dc, min(d1, d2));
	float tip_fade = (is_center > 0.5) ? smoothstep(0.995, 0.86, x_c) : smoothstep(0.995, 0.84, x_s);
	float inside = (1.0 - smoothstep(0.58, 1.02, best_d)) * tip_fade;
	return vec3(inside, best_d, is_center);
}

void vertex() {
	v_uv = UV;
	v_col = COLOR;
	v_nrm = NORMAL;
	vec3 pos = VERTEX;

	if (kind == 0 && COLOR.r >= 0.78) {
		// Dải bờm lửa & đuôi sao chổi vẫy uốn lượn dữ dội phía sau đầu hổ.
		float tail_t = clamp(UV.y, 0.0, 1.0);
		float flutter = sin(TIME * 20.0 - tail_t * 8.5 + COLOR.g * 6.283) * 0.12 * tail_t;
		pos.x += flutter;
		pos.y += cos(TIME * 17.0 - tail_t * 7.2 + COLOR.b * 6.283) * 0.09 * tail_t;
	} else if (kind == 6) {
		float t = clamp(progress, 0.0, 1.0);
		float along = (COLOR.r - 0.5) * 2.0 * zone_half.x;
		float across = (COLOR.g - 0.5) * 2.0 * zone_half.y;
		float seed = COLOR.b;
		if (COLOR.a < 0.5) {
			float up_v = mix(4.2, 7.8, seed);
			float spread_x = (fract(seed * 7.3) - 0.5) * 2.4;
			float spread_z = (fract(seed * 13.7) - 0.5) * 2.2;
			float spin = t * mix(7.0, 15.0, seed);
			float cs = cos(spin);
			float sn = sin(spin);
			vec3 rv = vec3(pos.x * cs - pos.z * sn, pos.y * cs - pos.x * sn, pos.x * sn + pos.z * cs);
			float sc = smoothstep(0.0, 0.06, t) * (1.0 - smoothstep(0.72, 1.0, t));
			float y_arc = max(0.05, up_v * t - 7.8 * t * t);
			pos = rv * sc + vec3(along * 0.85 + spread_x * t, y_arc, across * 0.72 + spread_z * t);
			v_nrm = normalize(vec3(NORMAL.x * cs - NORMAL.z * sn, NORMAL.y, NORMAL.x * sn + NORMAL.z * cs));
		} else {
			float ease = 1.0 - pow(1.0 - t, 1.85);
			float rise = mix(1.4, 3.6, seed) * ease;
			float grow = mix(0.60, 2.05, sqrt(t));
			float drift_x = (fract(seed * 5.9) - 0.5) * 1.6 * ease;
			float drift_z = (fract(seed * 9.7) - 0.5) * 1.6 * ease;
			float edge_push = (across >= 0.0 ? 1.0 : -1.0) * 0.42 * ease;
			vec3 center_local = vec3(along * 0.82 + drift_x, 0.25 + rise, across * 0.72 + edge_push + drift_z);
			mat3 inv_model = transpose(mat3(MODEL_MATRIX));
			vec3 cam_r = normalize(inv_model * INV_VIEW_MATRIX[0].xyz);
			vec3 cam_u = normalize(inv_model * INV_VIEW_MATRIX[1].xyz);
			pos = center_local + (cam_r * pos.x + cam_u * pos.y) * grow;
		}
	}

	VERTEX = pos;
	v_pos = pos;
}

void fragment() {
	vec2 p = v_uv * 2.0 - 1.0;
	vec3 stone_dark = vec3(0.065, 0.055, 0.062);
	vec3 stone_mid = vec3(0.22, 0.19, 0.185);
	vec3 deep_red = vec3(0.54, 0.03, 0.01);
	vec3 crimson = vec3(0.88, 0.10, 0.015);
	vec3 hot_orange = vec3(1.0, 0.38, 0.025);
	vec3 bright_gold = vec3(1.0, 0.80, 0.16);
	vec3 white_hot = vec3(1.0, 0.97, 0.82);

	vec3 col = hot_orange;
	float alpha = 1.0;
	float boost = 1.15;

	if (kind == 0) {
		// Khối 3D ĐẦU HỔ RĂNG KIẾM LỬA giống Concept Art Panel 1 & 2 (tương phản rõ giữa nanh trắng, mắt rực, hốc mắt/mũi đỏ thẫm & sọ cam-vàng)!
		float n_f = fbm(vec2(v_uv.x * 5.5, v_uv.y * 5.5 - TIME * 10.5));
		float ndl = clamp(dot(normalize(v_nrm), normalize(vec3(0.32, 0.85, 0.42))) * 0.5 + 0.5, 0.15, 1.0);
		if (v_col.r < 0.18) {
			// Răng nanh kiếm & răng hàm: gốc vàng ấm -> thân và mũi trắng ngà sắc lẹm!
			float tip = clamp(v_uv.y, 0.0, 1.0);
			col = mix(vec3(1.0, 0.72, 0.28), white_hot, smoothstep(0.08, 0.52, tip));
			col = mix(col, vec3(1.0, 0.99, 0.94), smoothstep(0.45, 0.92, tip));
			boost = mix(1.18, 1.58, tip);
			alpha = 0.99 * fade;
		} else if (v_col.r < 0.33) {
			// Đôi mắt hổ xếch rực sáng trắng-vàng nổi bật giữa hốc mắt đỏ thẫm!
			col = mix(bright_gold, vec3(1.0, 0.99, 0.92), 0.78);
			boost = 1.92;
			alpha = 0.99 * fade;
		} else if (v_col.r < 0.46) {
			// Hốc mắt, chóp mũi mèo lớn & lòng họng đỏ thẫm tạo độ sâu tương phản rõ rệt cho nanh trắng & mắt sáng!
			float inner_h = clamp(v_col.g * 0.72 + n_f * 0.28, 0.0, 1.0);
			col = mix(vec3(0.24, 0.015, 0.008), deep_red, smoothstep(0.0, 0.45, inner_h));
			col = mix(col, crimson, smoothstep(0.40, 0.85, inner_h));
			col = mix(col, hot_orange, smoothstep(0.80, 1.0, inner_h) * v_col.b);
			boost = mix(0.85, 1.24, inner_h);
			alpha = 0.98 * fade;
		} else if (v_col.r < 0.72) {
			// Khối đầu hổ, sống mũi, gờ mày, tai & hàm dưới: nổi khối 3D rõ giữa cam rực và vàng đỉnh!
			float heat = clamp(v_col.g * 0.58 + ndl * 0.30 + (n_f - 0.5) * 0.28, 0.0, 1.0);
			col = mix(deep_red, crimson, smoothstep(0.0, 0.30, heat));
			col = mix(col, hot_orange, smoothstep(0.24, 0.62, heat));
			col = mix(col, bright_gold, smoothstep(0.58, 0.90, heat));
			col = mix(col, white_hot, smoothstep(0.88, 1.0, heat) * v_col.b);
			boost = mix(0.98, 1.42, heat);
			alpha = 0.97 * fade;
		} else {
			// Gai bờm lửa & chùm đuôi sao chổi thon gọn cuộn sóng phía sau.
			float along = clamp(v_uv.y, 0.0, 1.0);
			float edge = 1.0 - smoothstep(0.18, 0.96, abs(p.x));
			float taper = pow(max(0.0, 1.0 - along), 1.08);
			float wisps = smoothstep(0.16 + along * 0.40, 0.60 + along * 0.24, n_f + 0.34 * (1.0 - along));
			col = mix(deep_red, crimson, smoothstep(0.0, 0.36, 1.0 - along + n_f * 0.25));
			col = mix(col, hot_orange, smoothstep(0.22, 0.66, 1.0 - along + n_f * 0.35));
			col = mix(col, bright_gold, smoothstep(0.56, 0.94, (1.0 - along) * edge + n_f * 0.22));
			alpha = clamp(edge * taper * wisps * 0.94, 0.0, 0.94) * fade;
			boost = mix(1.04, 1.46, 1.0 - along);
		}
	} else if (kind == 1) {
		// Concept Art Panel 3: Vệt nổ sao lửa rực chớp ban đầu + hố cháy đen & 9 nhánh nứt nham thạch bám tường!
		float r = length(p);
		float a = atan(p.y, p.x);
		float h = 1.0 - v_uv.y;
		float t_life = clamp(progress, 0.0, 1.0);
		float life_fade = 1.0 - smoothstep(0.75, 1.0, t_life);
		float cool = 1.0 - smoothstep(0.18, 0.92, t_life);
		float flash_burst = 1.0 - smoothstep(0.0, 0.24, t_life);
		float n_w = fbm(vec2(p.x * 4.4, h * 4.0 - TIME * 5.2));

		float scorch = (1.0 - smoothstep(0.32, 0.94, r + (n_w - 0.5) * 0.30)) * 0.94;
		float cracks = 0.0;
		for (int i = 0; i < 9; i++) {
			float fi = float(i);
			float a0 = fi * 0.698 + sin(fi * 2.7) * 0.20;
			float zig = sin(r * 16.0 + fi * 3.1) * 0.06;
			float da = abs(atan(sin(a - a0 + zig), cos(a - a0 + zig))) * max(r, 0.05);
			cracks = max(cracks, (1.0 - smoothstep(0.016, 0.052, da)) * (1.0 - smoothstep(0.45, 0.94, r)));
		}
		// Tia nổ sao nhọn 10 cánh bùng sáng lúc vừa đập tường!
		float star_r = 0.34 + 0.34 * pow(0.5 + 0.5 * cos(a * 10.0 + 0.4), 2.2);
		float starburst = (1.0 - smoothstep(star_r * 0.65, star_r, r)) * flash_burst;

		float core_glow = (1.0 - smoothstep(0.0, 0.40, r + (n_w - 0.5) * 0.16)) * cool;
		float lick_h = mix(0.56, 0.96, n_w) * (1.0 - smoothstep(0.18, 0.78, abs(p.x)));
		float wall_flames = smoothstep(0.16, 0.36, h) * (1.0 - smoothstep(lick_h - 0.16, lick_h + 0.05, h)) * smoothstep(0.30, 0.74, n_w) * cool;

		alpha = clamp(max(max(scorch, starburst), max(cracks * 0.98, wall_flames * 0.95)) * life_fade, 0.0, 0.98);
		col = mix(stone_dark, crimson, clamp(cracks * 0.95 * cool + wall_flames * 0.85 + core_glow * 0.65, 0.0, 1.0));
		col = mix(col, hot_orange, clamp(pow(cracks, 1.15) * cool + wall_flames * 0.95 + core_glow * 0.85 + starburst * 0.9, 0.0, 1.0));
		col = mix(col, bright_gold, clamp(wall_flames * 0.72 + core_glow * 0.78 + starburst, 0.0, 1.0));
		col = mix(col, white_hot, clamp(pow(core_glow, 2.2) * 0.65 + starburst * 0.72, 0.0, 1.0));
		boost = mix(0.95, 1.58, max(max(wall_flames, cracks * cool), max(core_glow, starburst)));
	} else if (kind == 2) {
		// Cảnh báo 3 vết cào uốn cong (0.7s) sắc nét, vết giữa bự & dài hơn.
		float n_j = fbm(p * 4.8 + vec2(TIME * 1.4, 0.0));
		vec3 c = triple_claw_dist(p, n_j * 0.38 + 0.31);
		float inside = c.x;
		float d = c.y;
		float rim = smoothstep(0.45, 0.88, d) * (1.0 - smoothstep(0.88, 1.06, d)) * smoothstep(0.02, 0.18, inside);
		float sweep_x = mix(-1.05, 1.05, clamp(progress, 0.0, 1.0));
		float fill_sweep = 1.0 - smoothstep(sweep_x - 0.18, sweep_x + 0.10, p.x);
		float pulse = 0.86 + 0.14 * sin(TIME * 24.0);
		float fade_in = smoothstep(0.0, 0.10, clamp(progress, 0.0, 1.0));

		float body_a = inside * mix(0.38, 0.78, fill_sweep);
		alpha = clamp(max(body_a, rim * 0.96) * fade_in * pulse, 0.0, 0.96);
		col = mix(crimson, hot_orange, clamp(fill_sweep * 0.75 + rim * 0.90, 0.0, 1.0));
		col = mix(col, bright_gold, clamp(rim * 0.85 + pow(fill_sweep, 2.0) * c.z * 0.45, 0.0, 1.0));
		boost = mix(1.15, 1.55, max(rim, fill_sweep * 0.65));
	} else if (kind == 3) {
		// Vệt cào lửa uốn cong quét thực sự từ trái sang phải / dọc.
		float t = clamp(progress, 0.0, 1.0);
		float n_j = fbm(vec2(p.x * 5.2 - TIME * 12.0, p.y * 6.0));
		vec3 c = triple_claw_dist(p, n_j);
		float head = mix(-1.12, 1.24, pow(t, 0.72));
		float tail_dist = head - p.x;
		float wave = smoothstep(-0.06, 0.08, tail_dist) * (1.0 - smoothstep(0.42, 1.15, tail_dist));
		float hot_front = smoothstep(-0.04, 0.05, tail_dist) * (1.0 - smoothstep(0.08, 0.34, tail_dist));
		float fade_out = 1.0 - smoothstep(0.68, 1.0, t);

		float slash = c.x * wave;
		alpha = clamp(slash * fade_out * 1.15, 0.0, 0.98);
		col = mix(crimson, hot_orange, clamp(slash * 0.85 + n_j * 0.35, 0.0, 1.0));
		col = mix(col, bright_gold, clamp(hot_front * 0.95 + c.z * 0.35, 0.0, 1.0));
		col = mix(col, white_hot, pow(hot_front, 1.6) * (0.65 + 0.30 * c.z));
		boost = mix(1.15, 1.65, hot_front);
	} else if (kind == 4) {
		// Concept Art Panel 3: 3 khe nứt UỐN CONG răng cưa + NHIỀU NHÁNH NỨT PHỤ TỎA XUNG QUANH (tồn tại 30s, tích sáng mỗi 5s)!
		float n_cr = fbm(p * 6.8 + vec2(3.1, 7.4));
		float n_fine = vnoise(p * 18.0);
		vec3 c = triple_claw_dist(p, n_cr * 0.78 + n_fine * 0.22);
		float d = c.y;
		float inside = c.x;

		// Các nhánh nứt đá đen răng cưa rạn chéo tỏa rộng xung quanh 3 rãnh cào chính giống Concept Art Panel 3!
		float zone_env = smoothstep(0.99, 0.72, abs(p.x)) * smoothstep(0.99, 0.68, abs(p.y));
		float near_claw = (1.0 - smoothstep(0.55, 3.10, d)) * zone_env;
		float zig1 = abs(sin((p.x * 12.0 + p.y * 5.8) + (n_cr - 0.5) * 4.8));
		float zig2 = abs(sin((p.x * 8.8 - p.y * 8.2) + (n_fine - 0.5) * 4.4));
		float branch_1 = (1.0 - smoothstep(0.03, 0.22, zig1)) * smoothstep(0.26, 0.68, n_cr) * near_claw;
		float branch_2 = (1.0 - smoothstep(0.03, 0.20, zig2)) * smoothstep(0.30, 0.72, n_fine) * near_claw;
		float side_cracks = clamp(max(branch_1, branch_2) * 1.05, 0.0, 1.0);

		float rubble = (1.0 - smoothstep(0.78, 1.85 + (n_fine - 0.5) * 0.55, d)) * smoothstep(0.01, 0.20, inside + side_cracks);
		float crevice = max(inside * (0.82 + 0.18 * n_fine), side_cracks * 0.96);
		float core_slit = max((1.0 - smoothstep(0.0, 0.50, d)) * inside, side_cracks * 0.52);

		float heat_level = clamp(0.18 + pow(clamp(charge, 0.0, 1.0), 1.35) * 0.85 + erupt * 0.60, 0.0, 1.35);
		float glow = clamp(core_slit * heat_level * (0.78 + 0.36 * n_cr), 0.0, 1.0);

		alpha = clamp(max(rubble * 0.62, crevice * 0.96) * fade, 0.0, 0.96);
		col = mix(stone_mid, stone_dark, clamp(crevice * 0.92 + rubble * 0.45, 0.0, 1.0));
		col = mix(col, crimson, smoothstep(0.08, 0.40, glow));
		col = mix(col, hot_orange, smoothstep(0.30, 0.70, glow));
		col = mix(col, bright_gold, smoothstep(0.60, 0.92, glow));
		col = mix(col, white_hot, smoothstep(0.84, 1.0, glow) * clamp(charge + erupt, 0.0, 1.0));
		boost = mix(0.88, 1.56, glow);
	} else if (kind == 5) {
		// Concept Art Panel 4: Các chùm lửa nhọn bùng xòe từ 3 khe nứt uốn cong + cột khói núi lửa đen bốc cao trên đỉnh!
		float t = clamp(erupt, 0.0, 1.0);
		float h = clamp(1.0 - v_uv.y, 0.0, 1.0);
		float is_center = v_col.r;
		float sheet_seed = v_col.g * 7.3;
		float end_taper = smoothstep(0.99, 0.72, abs(p.x));

		if (v_col.b > 0.5) {
			// Lớp khói núi lửa đen bốc cuộn dày phía trên các ngọn lửa phun trào.
			float s_in = smoothstep(0.05, 0.25, t);
			float s_out = 1.0 - smoothstep(0.50, 1.0, t);
			float sn1 = fbm(vec2(p.x * 4.2 + sheet_seed, h * 2.6 - TIME * 3.8));
			float sn2 = fbm(vec2(p.x * 8.0 - sn1 * 1.2, h * 4.2 - TIME * 5.2));
			float billow = smoothstep(0.24, 0.72, sn1 * 0.58 + sn2 * 0.42);
			float h_mask = smoothstep(0.0, 0.26, h) * (1.0 - smoothstep(0.56, 0.98, h + (sn1 - 0.5) * 0.24));
			float under_lit = (1.0 - smoothstep(0.0, 0.46, h)) * (1.0 - t * 0.55);

			alpha = clamp(billow * h_mask * end_taper * s_in * s_out * 0.78 * fade, 0.0, 0.78);
			col = mix(vec3(0.09, 0.08, 0.09), vec3(0.26, 0.23, 0.22), sn2 * 0.75);
			col = mix(col, hot_orange, under_lit * 0.48);
			boost = 0.94;
		} else {
			// Lớp lửa nhọn bùng xòe mạnh mẽ từ khe nứt cong.
			float burst_in = smoothstep(0.0, 0.14, t);
			float burn_out = 1.0 - smoothstep(0.46, 1.0, t);
			float warp = (fbm(vec2(p.x * 4.5 + sheet_seed, h * 2.2 - TIME * 9.0)) - 0.5) * 0.36;
			float n1 = fbm(vec2((p.x + warp) * 7.8 + sheet_seed, h * 2.6 - TIME * 13.0));
			float n2 = fbm(vec2((p.x - warp * 0.7) * 14.5, h * 4.8 - TIME * 18.0));
			float spire_wave = 0.5 + 0.5 * sin(p.x * 18.0 + sheet_seed + warp * 5.5);
			float tongues = n1 * 0.46 + n2 * 0.32 + spire_wave * 0.22;

			float max_h = burst_in * (0.30 + 0.84 * tongues) * end_taper * mix(0.80, 1.05, is_center);
			float mask_h = smoothstep(0.0, 0.06, h) * (1.0 - smoothstep(max_h - 0.18, max_h + 0.04, h));
			float carve = smoothstep(0.24 + h * 0.44, 0.62 + h * 0.26, tongues);
			float base_glow = (1.0 - smoothstep(0.0, 0.20, h)) * end_taper * burst_in * (0.28 + 0.72 * carve);

			float flame_a = max(mask_h * carve, base_glow * 0.82);
			float heat = clamp((1.0 - h * 0.90) * 0.84 + tongues * 0.36, 0.0, 1.0);

			alpha = clamp(flame_a * burn_out * fade * 0.94, 0.0, 0.94);
			col = mix(deep_red, crimson, smoothstep(0.05, 0.36, heat));
			col = mix(col, hot_orange, smoothstep(0.28, 0.64, heat));
			col = mix(col, bright_gold, smoothstep(0.58, 0.88, heat));
			col = mix(col, white_hot, smoothstep(0.88, 1.0, heat) * (1.0 - smoothstep(0.0, 0.14, h)) * 0.62);
			boost = mix(1.02, 1.34, heat);
		}
	} else {
		float t = clamp(progress, 0.0, 1.0);
		if (v_col.a < 0.5) {
			float ndl = clamp(dot(normalize(v_nrm), normalize(vec3(0.45, 0.82, 0.35))) * 0.5 + 0.5, 0.18, 1.0);
			float is_hot = step(0.74, v_col.b);
			col = mix(stone_dark, stone_mid, ndl * (0.55 + 0.45 * v_col.r));
			col = mix(col, hot_orange, is_hot * (1.0 - t) * 0.85);
			boost = mix(0.95, 1.38, is_hot * (1.0 - t));
			alpha = 1.0 - smoothstep(0.74, 1.0, t);
		} else {
			float r = length(p);
			float cloud_n = fbm(p * 2.8 + vec2(v_col.b * 9.0, -t * 2.2));
			float puff = (1.0 - smoothstep(0.28, 0.96, r + (cloud_n - 0.5) * 0.42)) * smoothstep(0.18, 0.68, cloud_n + 0.25);
			float smoke_fade = smoothstep(0.0, 0.14, t) * (1.0 - smoothstep(0.40, 1.0, t));
			float under_fire = (1.0 - smoothstep(0.0, 0.42, t)) * clamp(v_uv.y * 0.9, 0.0, 1.0) * 0.42;
			col = mix(vec3(0.12, 0.11, 0.12), vec3(0.30, 0.27, 0.26), cloud_n * 0.78);
			col = mix(col, hot_orange, under_fire);
			boost = 0.92;
			alpha = clamp(puff * smoke_fade * 0.78, 0.0, 0.78);
		}
	}

	if (alpha <= 0.01) {
		discard;
	}
	ALBEDO = col * boost;
	EMISSION = col * max(0.0, boost - 0.96) * 0.55;
	ALPHA = alpha;
}
