shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// kind:
// 0 = vỏ lửa lông vàng (active/warning)
// 1 = vòng telegraph đỏ dưới sàn (lông vàng warning)
// 2 = vòng nền vụ nổ (false = boom lông vàng to hơn; true = nền cháy sém cột lửa khe nứt không vòng đỏ)
// 3 = xung chạm đất / tia lửa thấp lông trắng (white = true)
// 4 = vết nứt đất đá thực tế trên sàn (Action_005, heat = seed ngẫu nhiên từng đoạn)
// 5 = lưỡi liềm lửa vòng cung (Action_002, heat = mức ép vào tường)
// 6 = cột lửa bùng nở to và tự nhiên (Action_005 phun trào, không cách điệu)
// 7 = vệt sáng thuôn dài sau lông trắng
// 8 = vùng đất đá nứt toác lớn dưới chân player (Action_005 chờ phun lửa, không vòng tròn đỏ)
// 9 = dự phòng (không dùng cho khe nứt đất đá)
// 10 = mảng lửa áp dẹt & tan dần trên mặt tường (Action_002 wall press)
// 11 = mảnh lửa góc cạnh bung nổ / tàn lửa (white = true) / mảnh đá vỡ đất (heat > 0.5)
// 12 = cụm khói than tối low-poly bốc lên khi nổ
// 13 = sóng xung lửa trang trí khi đít rìu giậm sàn (AxeSignal)
// 14 = mảnh tro đen lật chậm (ash flakes) + đốm tàn lửa cam nhỏ tắt nhanh (glowing embers)
// 15 = thân lông trắng cắm cháy dần từ đỉnh xuống gốc (ivory -> pale yellow -> hot orange -> ember red -> black char)
// 16 = làn khói mảnh mờ (thin smoke wisp) bay uốn nhẹ lên trên
// 17 = vết cháy sém mờ nhỏ tại gốc cắm lông trắng rồi tan biến ở 1.6s
// 18 = vòng phản lực gió đẩy lùi (Sky Dive Launch — 0 sát thương, xoáy gió trắng-xanh nhạt)
// 19 = vòng cảnh báo lửa rực cho đợt đáp Sky Dive (0.7s)
// 20 = vòng cảnh báo crosshair tròn xoay lớn cho đợt đáp Sky Dive thứ 5
// 21 = hố crater lõm sâu nứt đá + lõi dung nham nóng khi đáp Sky Dive
// 22 = sóng chấn động đẩy lùi toàn phòng (Resonance Slam — 0 sát thương)
uniform int kind = 0;
uniform bool white = false;
uniform float age = 0.0;
uniform float heat = 0.0;

varying vec2 coord;
varying vec4 v_data;

float tri_wave(float x) {
	return abs(fract(x) * 2.0 - 1.0) * 2.0 - 1.0;
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	v += 0.55 * value_noise(p);
	v += 0.30 * value_noise(p * 2.13 + vec2(17.3, 9.1));
	v += 0.15 * value_noise(p * 4.37 - vec2(5.7, 21.4));
	return v;
}

void vertex() {
	coord = UV * 2.0 - 1.0;
	v_data = COLOR;
	if (kind == 11) {
		float t = clamp(age, 0.0, 1.0);
		float angle = COLOR.r * 6.2831853;
		float speed = mix(0.45, 1.15, COLOR.g);
		float lift = mix(0.28, 1.15, COLOR.b);
		vec3 dir = vec3(cos(angle), 0.0, sin(angle));
		float ease = 1.0 - pow(1.0 - t, 2.2);
		float shrink = smoothstep(0.0, 0.08, t) * (1.0 - smoothstep(0.50, 1.0, t));
		if (heat > 0.5) {
			// Mảnh đất đá văng thấp rồi rơi xuống khi rãnh nứt xé sàn.
			float arc_y = lift * 0.95 * t - 1.45 * t * t;
			vec3 offset = dir * (ease * speed * 0.65) + vec3(0.0, max(0.0, arc_y), 0.0);
			VERTEX = VERTEX * (shrink * 0.42) + offset;
		} else if (white) {
			// Tàn lửa mảnh bắn ra khi lông trắng bị gió hất hoặc lửa áp tường tan.
			vec3 drift = vec3(cos(angle) * 1.1, 0.65 + lift * 1.05, sin(angle) * 0.55);
			VERTEX = VERTEX * (shrink * 0.55) + drift * (ease * speed * 1.55);
		} else {
			// Mảnh lửa góc cạnh bung rộng bao phủ vòng tròn khi lông vàng nổ.
			vec3 offset = dir * (ease * speed * 1.12) + vec3(0.0, ease * lift * 0.85 - t * t * 0.18, 0.0);
			VERTEX = VERTEX * (shrink * 1.18) + offset;
		}
	} else if (kind == 12) {
		float t = clamp(age, 0.0, 1.0);
		float angle = COLOR.r * 6.2831853;
		float rad = mix(0.22, 0.85, COLOR.g);
		float rise = mix(0.75, 1.85, COLOR.b);
		float grow = mix(0.55, 1.48, sqrt(t));
		float ease = 1.0 - pow(1.0 - t, 1.8);
		vec3 offset = vec3(cos(angle) * rad * ease, 0.34 + rise * ease, sin(angle) * rad * ease);
		VERTEX = VERTEX * grow + offset;
	} else if (kind == 14) {
		// Mảnh tro đen (ash flakes, COLOR.b < 0.68) lật/cuốn chậm bay lên & tản ra ngoài;
		// đốm tàn lửa cam (glowing embers, COLOR.b >= 0.68) bay lên nhanh và tắt sớm.
		float t = clamp(age, 0.0, 1.0);
		float angle = COLOR.r * 6.2831853 + heat * 6.2831853;
		float start_h = COLOR.g;
		bool is_ember = COLOR.b >= 0.68;
		float spd = mix(0.55, 1.25, COLOR.a);
		// Mỗi hạt tách ra đúng lúc mặt sóng cháy từ đỉnh xuống đi qua chiều cao start_h của nó.
		float spawn_t = mix(0.16, 0.72, 1.0 - start_h);
		float life_span = is_ember ? 0.24 : 0.44;
		float local_t = clamp((t - spawn_t) / life_span, 0.0, 1.0);
		float alive = step(spawn_t, t) * (1.0 - step(0.999, local_t));
		// Xoay lật chậm 3D cho mảnh tro (tumbling, slow, curling).
		float spin = local_t * (is_ember ? 3.0 : 5.2) * spd + COLOR.r * 12.0;
		float cs = cos(spin);
		float sn = sin(spin);
		vec3 v = VERTEX;
		v = vec3(v.x * cs - v.z * sn, v.y * cs - v.x * sn * 0.4, v.x * sn + v.z * cs);
		float sz = smoothstep(0.0, 0.14, local_t) * (1.0 - smoothstep(0.62, 1.0, local_t)) * alive;
		// Tản ra ngoài + bay lên trên (một số mảnh tro thấp rơi nhẹ quanh gốc giống Panel 0.6s/1.2s).
		float radial = (0.06 + mix(0.28, 0.72, COLOR.a) * pow(local_t, 0.85));
		float curl = sin(local_t * 5.0 + COLOR.r * 9.0) * 0.10 * local_t;
		float rise_dir = (!is_ember && start_h < 0.34 && fract(COLOR.r * 7.0) < 0.55) ? -0.35 : 1.0;
		float y_pos = max(0.02, start_h * 0.92 + rise_dir * local_t * (is_ember ? 0.85 : 0.62) * spd);
		vec3 offset = vec3(cos(angle) * radial + curl, y_pos, sin(angle) * radial - curl);
		VERTEX = v * sz + offset;
		v_data = vec4(local_t, is_ember ? 1.0 : 0.0, start_h, alive);
	}
}

void fragment() {
	vec2 p = coord;
	float r = length(p);
	float a = atan(p.y, p.x);

	vec3 charcoal = vec3(0.11, 0.08, 0.07);
	vec3 stone_dark = vec3(0.16, 0.14, 0.13);
	vec3 stone_mid = vec3(0.30, 0.26, 0.23);
	vec3 deep_red = vec3(0.84, 0.07, 0.02);
	vec3 hot_orange = vec3(1.0, 0.34, 0.03);
	vec3 bright_gold = vec3(1.0, 0.78, 0.14);
	vec3 ivory = vec3(1.0, 0.96, 0.82);

	vec3 color = hot_orange;
	float opacity = 0.0;
	float boost = 1.0;

	if (kind == 0) {
		// Lửa bao lông vàng: active có viền sáng + tàn nhỏ; warning bùng lưỡi lửa cam đỏ sắc hướng lên.
		float h = 1.0 - UV.y;
		float warn = smoothstep(0.42, 0.72, heat);
		float active = smoothstep(0.05, 0.35, heat);
		float glow = exp(-dot(p * vec2(1.4, 1.9), p * vec2(1.4, 1.9)) * 2.8);
		float sway = sin(TIME * 9.0 + p.x * 5.0 + h * 4.0) * 0.09;
		float tongues = 0.5 + 0.5 * tri_wave((p.x + sway) * 2.9 - TIME * 0.9);
		float sub = 0.5 + 0.5 * tri_wave((p.x - sway) * 5.4 + TIME * 1.7 + 0.3);
		float env_x = 1.0 - smoothstep(0.32, 0.86, abs(p.x));
		float flame_h = mix(0.26, 0.86, warn) * (0.48 + 0.36 * tongues + 0.24 * sub) * env_x;
		float mask = smoothstep(0.18, 0.34, h) * (1.0 - smoothstep(flame_h - 0.07, flame_h + 0.03, h));
		vec2 cell = vec2(p.x * 5.2, h * 4.4 - TIME * 3.1);
		float spark_seed = hash21(floor(cell));
		vec2 local = fract(cell) - 0.5;
		float spark = step(0.83, spark_seed) * (1.0 - smoothstep(0.03, 0.14, length(local))) * (1.0 - h) * active;
		float aura = glow * mix(0.16, 0.42, active);
		opacity = clamp(max(aura, max(mask * mix(0.22, 0.94, warn), spark * 0.95)), 0.0, 1.0);
		float tip_t = clamp((h - 0.22) / max(0.15, flame_h - 0.20), 0.0, 1.0);
		color = mix(bright_gold, hot_orange, smoothstep(0.18, 0.72, tip_t));
		color = mix(color, deep_red, smoothstep(0.68, 1.0, tip_t));
		color = mix(color, ivory, (1.0 - smoothstep(0.0, 0.24, tip_t)) * warn * 0.65 + spark * 0.8);
		boost = mix(1.05, 1.42, warn * (1.0 - tip_t * 0.5));
	} else if (kind == 1) {
		// Vòng telegraph đỏ sắc nét dưới sàn cho lông vàng.
		float pulse = 0.93 + 0.07 * sin(TIME * 22.0);
		float edge = abs(r - 0.90);
		float ring = 1.0 - smoothstep(0.016, 0.045, edge);
		float halo = (1.0 - smoothstep(0.03, 0.14, edge)) * 0.42;
		float fill = (1.0 - smoothstep(0.0, 0.90, r)) * 0.12 * mix(0.5, 1.0, heat);
		opacity = clamp(max(ring, max(halo, fill)), 0.0, 1.0) * pulse;
		color = mix(vec3(1.0, 0.10, 0.05), vec3(1.0, 0.36, 0.12), ring * mix(0.20, 0.65, heat));
		boost = 1.32;
	} else if (kind == 2) {
		float phase = clamp(age, 0.0, 1.0);
		float fade = 1.0 - smoothstep(0.45, 1.0, phase);
		if (white) {
			// Nền đất cháy sém + ánh lửa nóng dưới chân cột lửa phun trào (KHÔNG vẽ vòng tròn đỏ).
			float n = fbm(p * 3.6 + vec2(0.0, TIME * 0.8));
			float scorch = (1.0 - smoothstep(0.32, 0.96, r + (n - 0.5) * 0.24)) * 0.78;
			float fire_pool = (1.0 - smoothstep(0.08, 0.78, r + (n - 0.5) * 0.22)) * (1.0 - smoothstep(0.15, 0.90, phase));
			opacity = clamp(max(scorch, fire_pool) * fade, 0.0, 1.0);
			color = mix(charcoal, deep_red, smoothstep(0.05, 0.55, fire_pool));
			color = mix(color, hot_orange, smoothstep(0.35, 0.80, fire_pool));
			color = mix(color, bright_gold, smoothstep(0.72, 1.0, fire_pool));
			boost = mix(0.95, 1.55, fire_pool);
		} else {
			// Nổ lông vàng (boom): vùng lửa ở tâm nở rộng hơn để bao phủ sát vòng tròn cảnh báo.
			float ring_r = mix(0.52, 0.93, sqrt(min(phase * 2.5, 1.0)));
			float edge = abs(r - ring_r);
			float ring = 1.0 - smoothstep(0.016, 0.054, edge);
			float halo = (1.0 - smoothstep(0.03, 0.18, edge)) * 0.48;
			float scorch = (1.0 - smoothstep(0.22, 0.92, r)) * 0.48 * (1.0 - phase * 0.60);
			float inner_fire = (1.0 - smoothstep(0.18, 0.84, r)) * (1.0 - smoothstep(0.0, 0.52, phase));
			float flash = (1.0 - smoothstep(0.06, 0.74, r)) * (1.0 - smoothstep(0.0, 0.30, phase));
			float rays = pow(max(0.0, tri_wave(a / 6.2831853 * 12.0)), 3.0);
			float sparks = rays * (1.0 - smoothstep(0.02, 0.15, abs(r - mix(0.35, 0.98, phase)))) * (1.0 - phase) * 0.85;
			opacity = clamp(max(max(ring, halo), max(scorch, max(inner_fire * 0.85, max(flash, sparks)))) * fade, 0.0, 1.0);
			color = mix(charcoal, vec3(1.0, 0.32, 0.05), clamp(ring + halo + inner_fire + sparks, 0.0, 1.0));
			color = mix(color, bright_gold, clamp(inner_fire * 0.65 + flash * 0.85, 0.0, 1.0));
			color = mix(color, ivory, flash * 0.60);
			boost = mix(1.08, 1.62, max(flash, inner_fire * 0.6));
		}
	} else if (kind == 3) {
		float phase = clamp(age, 0.0, 1.0);
		if (white) {
			float rays = pow(max(0.0, tri_wave(a / 6.2831853 * 10.0 + 0.15)), 4.0);
			float sub_rays = pow(max(0.0, tri_wave(a / 6.2831853 * 17.0 - 0.35)), 5.0);
			float reach = mix(0.28, 0.96, sqrt(phase));
			float splash = max(rays, sub_rays * 0.75) * smoothstep(0.06, 0.22, r) * (1.0 - smoothstep(reach * 0.45, reach, r));
			float core = (1.0 - smoothstep(0.05, 0.32, r)) * (1.0 - smoothstep(0.0, 0.45, phase));
			float crack = (1.0 - smoothstep(0.02, 0.06, abs(sin(a * 3.0 + r * 4.0)))) * (1.0 - smoothstep(0.18, 0.46, r)) * 0.55;
			opacity = clamp(max(max(splash, core), crack) * (1.0 - smoothstep(0.35, 1.0, phase)), 0.0, 1.0);
			color = mix(charcoal, bright_gold, clamp(splash + core, 0.0, 1.0));
			color = mix(color, ivory, clamp(core + splash * 0.65, 0.0, 1.0));
			boost = 1.42;
		} else {
			float front = mix(0.18, 0.94, sqrt(phase));
			float edge = abs(r - front);
			float rim = 1.0 - smoothstep(0.015, 0.075, edge);
			float halo = (1.0 - smoothstep(0.03, 0.18, edge)) * 0.42;
			float flash = (1.0 - smoothstep(0.04, 0.52, r)) * (1.0 - smoothstep(0.0, 0.32, phase));
			opacity = clamp(max(max(rim, halo), flash) * (1.0 - phase), 0.0, 1.0);
			color = mix(deep_red, bright_gold, clamp(rim * 0.75 + flash, 0.0, 1.0));
			color = mix(color, ivory, flash * 0.85);
			boost = 1.38;
		}
	} else if (kind == 4) {
		// Vết nứt đất đá thực tế trên sàn (không tia sét cách điệu): rãnh đất đá vỡ tối màu, nhánh rạn mảnh và ánh đỏ nóng âm ỉ dưới đáy khe.
		float phase = clamp(age, 0.0, 1.0);
		float fade = 1.0 - smoothstep(0.72, 1.0, phase);
		float seed = heat * 6.2831853;
		float n_rock = fbm(p * 4.8 + vec2(seed, 0.0));
		float mid_env = 1.0 - p.y * p.y;
		float bend = (sin(p.y * 2.5 + seed) * 0.24 + (n_rock - 0.5) * 0.28) * mid_env;
		float d_main = abs(p.x - bend);

		// Hai nhánh rạn đá tự nhiên tỏa ra hai bên.
		float side1 = heat > 0.5 ? 1.0 : -1.0;
		float b1_start = mix(-0.42, 0.05, fract(heat * 3.1));
		float b1_t = clamp((p.y - b1_start) / 0.52, 0.0, 1.0);
		float b1_mask = smoothstep(b1_start - 0.02, b1_start + 0.04, p.y) * (1.0 - smoothstep(b1_start + 0.38, b1_start + 0.55, p.y));
		float d_b1 = abs(p.x - (bend + side1 * (0.03 + b1_t * 0.42 + (n_rock - 0.5) * 0.10))) + (1.0 - b1_mask) * 2.0;

		float b2_start = mix(-0.12, 0.34, fract(heat * 5.7));
		float b2_t = clamp((p.y - b2_start) / 0.44, 0.0, 1.0);
		float b2_mask = smoothstep(b2_start - 0.02, b2_start + 0.04, p.y) * (1.0 - smoothstep(b2_start + 0.32, b2_start + 0.46, p.y));
		float d_b2 = abs(p.x - (bend - side1 * (0.03 + b2_t * 0.34 - (n_rock - 0.5) * 0.08))) + (1.0 - b2_mask) * 2.0;

		float dist = min(d_main, min(d_b1 * 1.45, d_b2 * 1.65));
		float end_taper = 1.0 - smoothstep(0.84, 1.0, abs(p.y));
		float rubble_rim = (1.0 - smoothstep(0.14, 0.34, dist + (n_rock - 0.5) * 0.12)) * end_taper;
		float crevice = (1.0 - smoothstep(0.05, 0.14, dist)) * end_taper;
		float deep_ember = (1.0 - smoothstep(0.012, 0.045, d_main)) * end_taper * (1.0 - smoothstep(0.25, 0.95, phase));

		opacity = clamp(max(rubble_rim * 0.52, crevice * 0.96), 0.0, 1.0) * fade;
		color = mix(stone_mid, stone_dark, smoothstep(0.10, 0.70, crevice));
		color = mix(color, vec3(0.05, 0.04, 0.04), crevice * 0.85);
		// Ánh đỏ cam âm ỉ dưới đáy khe nứt sâu (không lóe trắng cách điệu).
		color = mix(color, vec3(0.95, 0.24, 0.03), deep_ember * 0.72);
		boost = mix(0.88, 1.15, deep_ember);
	} else if (kind == 5) {
		// Lưỡi liềm lửa vòng cung tách rời (Action_002).
		float wall_press = clamp(heat, 0.0, 1.0);
		float phase = clamp(age, 0.0, 1.0);
		float curvature = mix(1.42, 0.26, wall_press);
		float front = mix(0.82, 0.90, wall_press) - p.x * p.x * curvature;
		float back_dist = front - p.y;
		float x_ratio = clamp(abs(p.x) / 0.96, 0.0, 1.0);
		float horn_taper = pow(1.0 - x_ratio * x_ratio, 0.85);

		float flow = value_noise(vec2(p.x * 4.5 - sign(p.x) * TIME * 3.2, back_dist * 3.2 - TIME * 5.0));
		float ribbon = 0.5 + 0.5 * sin((p.x * 6.5 - back_dist * 4.2) + flow * 3.4 - TIME * 7.5);
		float tail_len = mix(1.18, 0.44, wall_press) * horn_taper * (0.68 + 0.36 * flow + 0.20 * ribbon);

		float leading = smoothstep(-0.035, 0.04, back_dist);
		float body = leading * (1.0 - smoothstep(tail_len * 0.48, max(0.06, tail_len), back_dist));
		float edge_core = leading * (1.0 - smoothstep(0.04, max(0.06, 0.28 * horn_taper), back_dist));
		float tail_zone = smoothstep(0.24 * horn_taper, max(0.26, tail_len * 0.92), back_dist);
		float wisp_cut = smoothstep(0.24, 0.72, flow * 0.62 + ribbon * 0.38);
		float shaped = body * mix(1.0, wisp_cut, tail_zone * 0.68);
		float life_fade = (1.0 - smoothstep(0.75, 1.0, phase)) * (1.0 - smoothstep(0.35, 1.0, wall_press));

		opacity = clamp(shaped * life_fade, 0.0, 1.0);
		color = mix(deep_red, hot_orange, smoothstep(0.0, 0.72, 1.0 - tail_zone));
		color = mix(color, bright_gold, edge_core * 0.95);
		color = mix(color, ivory, pow(edge_core, 2.0) * (0.85 + wall_press * 0.35));
		boost = mix(1.12, 1.78, max(edge_core, wall_press * 0.55));
	} else if (kind == 6) {
		// Ngọn lửa bình thường bùng lên thật to, dày và bự (KHÔNG gai tam giác cách điệu) bằng nhiễu cuộn tự nhiên FBM.
		float h = 1.0 - UV.y;
		float phase = clamp(age, 0.0, 1.0);
		float burst_in = smoothstep(0.0, 0.16, phase);
		float burn_out = 1.0 - smoothstep(0.42, 1.0, phase);

		// Nhiễu cuộn mạnh hướng lên trên tạo khối lửa bùng nở tự nhiên dày đặc.
		vec2 flow_uv = vec2(p.x * 2.4, h * 2.2 - TIME * 4.6);
		float n_warp = fbm(flow_uv);
		float n_detail = fbm(vec2(p.x * 4.6 + (n_warp - 0.5) * 1.4, h * 4.2 - TIME * 7.2));
		float turb = n_warp * 0.60 + n_detail * 0.40;

		// Phình to bự ở phần thân dưới, bo tròn tự nhiên ở đáy để không lộ cạnh phẳng mặt giao nhau.
		float base_round = smoothstep(0.0, 0.22, h);
		float bulge = mix(0.55, 0.24, pow(h, 1.15)) + sin(pow(h, 0.72) * 3.14159) * 0.42;
		float width_now = bulge * mix(0.68, 1.02, burst_in) * (0.72 + 0.40 * turb) * mix(0.58, 1.0, base_round);
		float max_h = burst_in * (0.62 + 0.44 * turb) * (1.0 - pow(abs(p.x) / max(0.22, width_now), 2.0) * 0.55);

		float x_dist = abs(p.x + (n_warp - 0.5) * 0.24 * h);
		float edge_fade = 1.0 - smoothstep(0.72, 0.98, abs(p.x));
		float body = (1.0 - smoothstep(width_now * 0.44, width_now, x_dist)) * (1.0 - smoothstep(max_h - 0.24, max_h + 0.04, h)) * edge_fade;
		float erode = smoothstep(phase * 0.95 - 0.22, phase * 0.95 + 0.24, turb + (1.0 - h) * 0.48);
		float base_in = smoothstep(0.0, 0.14, h);
		float flame_alpha = body * mix(1.0, erode, smoothstep(0.28, 0.85, phase)) * base_in * burn_out;

		// Lõi nhiệt trắng vàng rất sáng ở bụng lửa, chuyển dần cam cháy -> đỏ lửa -> rìa khói sẫm.
		float core_d = length(vec2(x_dist / max(0.15, width_now * 0.65), (h - 0.22) * 1.35));
		float hot_core = clamp((1.0 - smoothstep(0.15, 0.78, core_d)) * (0.75 + 0.35 * n_detail), 0.0, 1.0);
		float mid_heat = clamp((1.0 - h * 0.72) * 0.75 + turb * 0.38, 0.0, 1.0);

		opacity = clamp(flame_alpha * 1.15, 0.0, 1.0);
		color = mix(vec3(0.28, 0.07, 0.04), deep_red, smoothstep(0.08, 0.42, mid_heat));
		color = mix(color, hot_orange, smoothstep(0.32, 0.70, mid_heat));
		color = mix(color, bright_gold, smoothstep(0.56, 0.92, mid_heat + hot_core * 0.35));
		color = mix(color, ivory, smoothstep(0.55, 0.95, hot_core));
		boost = mix(1.05, 1.65, hot_core);
	} else if (kind == 7) {
		// Vệt sáng thuôn dài mảnh phía sau lông đang bay (heat > 0.5 = vệt đỏ thẫm rực lửa của lông đỏ Phase 2).
		float along = UV.y;
		float taper = pow(max(0.0, 1.0 - along), 1.30);
		float w = abs(p.x);
		float shimmer = 0.86 + 0.14 * sin(along * 26.0 - TIME * 34.0);
		float is_crimson = step(0.5, heat);
		float core_w = mix(0.24, 0.34, is_crimson);
		float glow_w = mix(0.62, 0.84, is_crimson);
		float core = 1.0 - smoothstep(0.02 * taper, max(0.025, core_w * taper), w);
		float glow = (1.0 - smoothstep(0.10 * taper, max(0.06, glow_w * taper), w)) * mix(0.45, 0.72, is_crimson);
		float head_in = smoothstep(0.0, 0.08, along);
		opacity = clamp(max(core, glow) * taper * head_in * shimmer, 0.0, 1.0);
		vec3 white_col = mix(bright_gold, ivory, smoothstep(0.15, 0.75, core));
		vec3 crimson_outer = vec3(0.58, 0.01, 0.01);
		vec3 crimson_mid = vec3(0.95, 0.06, 0.03);
		vec3 crimson_core = vec3(1.0, 0.36, 0.12);
		vec3 crimson_col = mix(crimson_outer, crimson_mid, smoothstep(0.08, 0.55, max(core, glow)));
		crimson_col = mix(crimson_col, crimson_core, smoothstep(0.45, 0.92, core));
		color = mix(white_col, crimson_col, is_crimson);
		boost = mix(1.45, 1.85, is_crimson);
	} else if (kind == 8) {
		// Vùng đất đá nứt toác lớn ngay dưới chân player (KHÔNG vòng tròn cảnh báo đỏ), hắt ánh lửa tăng dần trong lúc chờ phun trào.
		float phase = clamp(age, 0.0, 1.0);
		float fade = 1.0 - smoothstep(0.82, 1.0, phase);
		float n_cr = fbm(p * 4.5);
		float n_cr2 = value_noise(p * 11.0);

		// 7 khe nứt xuyên tâm bất đối xứng gãy khúc tự nhiên tỏa ra từ tâm vỡ.
		float radial_crack = 0.0;
		float warm_glow = 0.0;
		for (int i = 0; i < 7; i++) {
			float fi = float(i);
			float base_a = fi * 0.8976 + sin(fi * 2.3) * 0.22;
			float jitter = (fbm(vec2(r * 4.2 + fi * 3.1, fi * 1.7)) - 0.5) * 0.34;
			float da = abs(atan(sin(a - base_a - jitter), cos(a - base_a - jitter)));
			float arc_d = da * max(r, 0.06);
			float reach = 0.72 + 0.24 * hash21(vec2(fi, 2.7));
			float mask_r = (1.0 - smoothstep(reach * 0.65, reach, r));
			float w_crack = mix(0.075, 0.018, r);
			radial_crack = max(radial_crack, (1.0 - smoothstep(w_crack * 0.45, w_crack, arc_d)) * mask_r);
			warm_glow = max(warm_glow, (1.0 - smoothstep(w_crack * 0.15, w_crack * 0.70, arc_d)) * mask_r);
		}
		// Vết rạn vòng đá vỡ gãy không đều quanh tâm (KHÔNG phải vòng tròn đỏ).
		float shatter_r = abs(r - (0.36 + (n_cr - 0.5) * 0.18));
		float cross_crack = (1.0 - smoothstep(0.018, 0.048, shatter_r)) * smoothstep(0.25, 0.70, n_cr2);
		float pit = (1.0 - smoothstep(0.08, 0.34 + (n_cr - 0.5) * 0.14, r));
		float rubble = (1.0 - smoothstep(0.45, 0.94, r + (n_cr - 0.5) * 0.25)) * 0.45;

		float cracks_all = clamp(max(radial_crack, max(cross_crack, pit)), 0.0, 1.0);
		float heat_build = smoothstep(0.05, 0.55, phase) * (1.0 - smoothstep(0.75, 1.0, phase));
		float glow_mask = clamp(max(warm_glow, pit * 0.85), 0.0, 1.0) * heat_build;

		opacity = clamp(max(rubble, cracks_all * 0.96), 0.0, 1.0) * fade;
		color = mix(stone_mid, stone_dark, smoothstep(0.1, 0.7, rubble + cracks_all));
		color = mix(color, vec3(0.05, 0.04, 0.04), cracks_all * 0.90);
		color = mix(color, deep_red, glow_mask * 0.85);
		color = mix(color, hot_orange, pow(glow_mask, 1.4) * 0.95);
		color = mix(color, bright_gold, pow(glow_mask, 2.2) * heat_build * 0.85);
		boost = mix(0.90, 1.65, glow_mask * heat_build);
	} else if (kind == 10) {
		// Mảng lửa áp dẹt lên tường & tan thành lưỡi lửa tự nhiên khi vòng cung chạm tường.
		float phase = clamp(age, 0.0, 1.0);
		float h = 1.0 - UV.y;
		float spread_x = mix(0.58, 1.0, sqrt(min(phase * 2.4, 1.0)));
		float x_n = abs(p.x) / max(0.1, spread_x);

		float n_coarse = value_noise(vec2(p.x * 3.8, h * 3.2 - TIME * 6.5));
		float n_fine = value_noise(vec2(p.x * 9.5 + n_coarse * 1.4, h * 6.5 - TIME * 11.0));
		float turb = n_coarse * 0.62 + n_fine * 0.38;

		float impact_y = mix(0.28, 0.42, phase);
		float arch = 1.0 - pow(x_n, 1.65);
		float top_reach = impact_y + mix(0.22, 0.58, sqrt(phase)) * arch * (0.48 + 0.72 * turb);
		float bot_reach = max(0.04, impact_y - mix(0.20, 0.10, phase) * arch * (0.75 + 0.35 * n_coarse));

		float horiz = 1.0 - smoothstep(0.68, 1.0, x_n);
		float vert = smoothstep(bot_reach - 0.06, bot_reach + 0.05, h) * (1.0 - smoothstep(top_reach - 0.16, top_reach + 0.03, h));

		float erode_t = smoothstep(0.24, 0.96, phase);
		float wisp_field = turb + (1.0 - x_n) * 0.25 + (1.0 - h) * 0.18;
		float dissolve = smoothstep(erode_t * 1.05 - 0.12, erode_t * 1.05 + 0.22, wisp_field);

		float hot_band = (1.0 - smoothstep(0.0, 0.56, x_n)) * (1.0 - smoothstep(0.03, 0.18, abs(h - impact_y))) * (1.0 - smoothstep(0.0, 0.44, phase));
		float fade = 1.0 - smoothstep(0.58, 1.0, phase);
		opacity = clamp(horiz * vert * dissolve * fade, 0.0, 1.0);

		float height_frac = clamp((h - bot_reach) / max(0.15, top_reach - bot_reach), 0.0, 1.0);
		color = mix(hot_orange, deep_red, smoothstep(0.32, 0.92, height_frac + (1.0 - turb) * 0.22));
		color = mix(color, bright_gold, clamp(hot_band * 1.15 + (1.0 - height_frac) * 0.42 * (1.0 - phase * 0.7), 0.0, 1.0));
		color = mix(color, ivory, hot_band * 0.92);
		boost = mix(1.10, 1.80, hot_band);
	} else if (kind == 11) {
		// Mảnh lửa bung nổ, tàn lửa gió (white), hoặc mảnh đất đá vỡ (heat > 0.5).
		float phase = clamp(age, 0.0, 1.0);
		float tip = v_data.a;
		float fade = 1.0 - smoothstep(0.45, 1.0, phase);
		opacity = fade;
		if (heat > 0.5) {
			color = mix(stone_dark, stone_mid, tip);
			boost = 0.85;
		} else if (white) {
			color = mix(hot_orange, bright_gold, smoothstep(0.10, 0.70, 1.0 - phase * 0.6));
			color = mix(color, ivory, smoothstep(0.45, 1.0, tip) * (1.0 - phase));
			boost = 1.45;
		} else {
			color = mix(ivory, bright_gold, smoothstep(0.05, 0.35, tip));
			color = mix(color, hot_orange, smoothstep(0.32, 0.72, tip));
			color = mix(color, deep_red, smoothstep(0.68, 1.0, tip));
			boost = mix(1.52, 1.05, tip);
		}
	} else if (kind == 12) {
		// Cụm khói than tối low-poly bốc lên phía trên lửa nổ.
		float phase = clamp(age, 0.0, 1.0);
		float fade = smoothstep(0.0, 0.14, phase) * (1.0 - smoothstep(0.42, 1.0, phase));
		opacity = 0.74 * fade;
		float rim_glow = (1.0 - v_data.a) * (1.0 - smoothstep(0.0, 0.45, phase));
		color = mix(vec3(0.15, 0.12, 0.13), vec3(0.55, 0.18, 0.06), rim_glow * 0.55);
		boost = 0.92;
	} else if (kind == 13) {
		// kind == 13: Sóng âm / xung lửa trang trí bung ra dưới đuôi cán rìu (Concept 2 panel A).
		float phase = clamp(age, 0.0, 1.0);
		float fade = 1.0 - smoothstep(0.42, 1.0, phase);
		float front = mix(0.14, 0.88, sqrt(phase));
		float ring1 = 1.0 - smoothstep(0.016, 0.055, abs(r - front));
		float ring2 = (1.0 - smoothstep(0.014, 0.045, abs(r - front * 0.62))) * 0.55;
		float halo = (1.0 - smoothstep(0.03, 0.16, abs(r - front))) * 0.42;
		// 4 mũi tên hướng ngoại bung dọc theo sóng xung (khớp Concept 2 panel A).
		float sector = fract(a / 6.2831853 * 4.0 + 0.5) - 0.5;
		float arrow_r = clamp((r - front) / 0.15, 0.0, 1.0);
		float in_arrow = step(front - 0.02, r) * (1.0 - smoothstep(front + 0.13, front + 0.17, r));
		float arrow_w = mix(0.09, 0.008, arrow_r);
		float arrows = (1.0 - smoothstep(arrow_w, arrow_w + 0.02, abs(sector))) * in_arrow;
		float center_hit = (1.0 - smoothstep(0.02, 0.22, r)) * (1.0 - smoothstep(0.0, 0.28, phase));

		opacity = clamp(max(max(ring1, ring2), max(halo, max(arrows * 0.95, center_hit))) * fade, 0.0, 1.0);
		color = mix(deep_red, hot_orange, clamp(ring1 + halo + arrows, 0.0, 1.0));
		color = mix(color, bright_gold, clamp(ring1 * 0.75 + arrows * 0.80 + center_hit, 0.0, 1.0));
		color = mix(color, ivory, center_hit * 0.90);
		boost = mix(1.15, 1.70, max(ring1, center_hit));
	} else if (kind == 14) {
		// Mảnh tro đen (ash flakes) + đốm tàn lửa cam nhỏ tắt nhanh (glowing embers).
		float local_t = v_data.x;
		bool is_ember = v_data.y > 0.5;
		float alive = v_data.a;
		if (alive < 0.5) { discard; }
		if (is_ember) {
			float fade = smoothstep(0.0, 0.10, local_t) * (1.0 - smoothstep(0.32, 1.0, local_t));
			opacity = 0.95 * fade;
			color = mix(bright_gold, hot_orange, smoothstep(0.10, 0.65, local_t));
			color = mix(color, deep_red, smoothstep(0.60, 1.0, local_t));
			boost = mix(1.75, 1.05, local_t);
		} else {
			float fade = smoothstep(0.0, 0.12, local_t) * (1.0 - smoothstep(0.55, 1.0, local_t));
			opacity = 0.88 * fade;
			float hot_edge = (1.0 - smoothstep(0.0, 0.25, local_t)) * 0.42;
			color = mix(vec3(0.09, 0.08, 0.08), vec3(0.22, 0.20, 0.21), v_data.z * 0.55);
			color = mix(color, deep_red, hot_edge);
			boost = mix(0.85, 1.18, hot_edge);
		}
	} else if (kind == 15) {
		// Thân lông trắng cắm cháy dần từ đỉnh (UV.y = 1) xuống gốc (UV.y = 0) đúng Concept Art:
		// 0.0s stuck -> 0.3s ignite tip -> 0.6s burn down -> 0.9s half -> 1.2s glowing base -> 1.45s gone.
		float t_sec = clamp(age, 0.0, 1.0) * 1.60;
		float y = UV.y;
		float edge_bias = abs(UV.x - 0.5) * 0.14;
		float jag = (fbm(vec2(UV.x * 7.5 + heat * 11.0, y * 9.5 + heat * 5.0)) - 0.5) * 0.22;
		// Mặt sóng cháy đi từ trên đỉnh (1.22) xuống dưới gốc (-0.12).
		float burn_progress = clamp((t_sec - 0.16) / 1.18, 0.0, 1.0);
		float burn_front = mix(1.22, -0.14, burn_progress) - edge_bias + jag;
		float d = burn_front - y;
		if (d < 0.0) { discard; }

		// Màu gốc lông trắng ngà + gân xám (hoặc đỏ thẫm phát sáng nếu white == true cho lông đỏ Phase 2 cháy tàn).
		vec3 base_col = white ? mix(vec3(0.45, 0.02, 0.06), vec3(0.95, 0.14, 0.18), dot(v_data.rgb, vec3(0.333))) : v_data.rgb;
		// 5 dải màu mép cháy (Panel A: ivory -> pale yellow -> hot orange -> ember red -> black char).
		float ignite = smoothstep(0.14, 0.32, t_sec);
		float band_char = (1.0 - smoothstep(0.00, 0.042, d)) * ignite;
		float band_red = smoothstep(0.022, 0.055, d) * (1.0 - smoothstep(0.085, 0.130, d)) * ignite;
		float band_orange = smoothstep(0.075, 0.115, d) * (1.0 - smoothstep(0.155, 0.205, d)) * ignite;
		float band_yellow = smoothstep(0.145, 0.190, d) * (1.0 - smoothstep(0.235, 0.305, d)) * ignite;
		// Ở 1.2s (BASE), cuống lông dưới gốc đỏ rực trước khi tắt hẳn.
		float base_glow = smoothstep(0.95, 1.18, t_sec) * (1.0 - smoothstep(1.24, 1.44, t_sec)) * (1.0 - smoothstep(0.0, 0.28, y));

		color = mix(base_col, vec3(1.0, 0.92, 0.56), clamp(band_yellow, 0.0, 1.0));
		color = mix(color, hot_orange, clamp(band_orange + base_glow * 0.55, 0.0, 1.0));
		color = mix(color, deep_red, clamp(band_red + base_glow * 0.85, 0.0, 1.0));
		color = mix(color, vec3(0.07, 0.05, 0.05), clamp(band_char, 0.0, 1.0));
		boost = 1.0 + band_yellow * 0.35 + band_orange * 0.85 + band_red * 0.50 + base_glow * 0.90;
		opacity = 1.0 - smoothstep(1.30, 1.46, t_sec);
	} else if (kind == 16) {
		// Làn khói mảnh mờ (thin smoke wisp, low opacity) uốn nhẹ bay lên từ 0.38s -> 1.55s.
		float t_sec = clamp(age, 0.0, 1.0) * 1.60;
		float h = 1.0 - UV.y;
		float env_t = smoothstep(0.32, 0.65, t_sec) * (1.0 - smoothstep(1.08, 1.56, t_sec));
		float sway = sin(h * 5.2 - TIME * 2.4 + heat * 6.2831853) * (0.14 + h * 0.22);
		float n_smoke = fbm(vec2(p.x * 3.2 + heat * 7.0, h * 3.4 - TIME * 1.2));
		float x_d = abs(p.x - sway + (n_smoke - 0.5) * 0.26);
		float width_w = mix(0.24, 0.62, h);
		float wisp = (1.0 - smoothstep(width_w * 0.20, width_w, x_d)) * smoothstep(0.06, 0.28, h) * (1.0 - smoothstep(0.62, 1.0, h));
		wisp *= smoothstep(0.28, 0.78, n_smoke);
		opacity = clamp(wisp * env_t * 0.34, 0.0, 0.34);
		color = mix(vec3(0.26, 0.26, 0.29), vec3(0.56, 0.54, 0.52), n_smoke * 0.65 + h * 0.25);
		boost = 0.88;
	} else if (kind == 17) {
		// kind == 17: Vết cháy sém mờ nhỏ tại gốc cắm lông trắng rồi tan biến hoàn toàn ở 1.6s.
		float t_sec = clamp(age, 0.0, 1.0) * 1.60;
		float n_sc = fbm(p * 4.5);
		float spot = 1.0 - smoothstep(0.18, 0.88, r + (n_sc - 0.5) * 0.26);
		float fade = smoothstep(0.24, 0.55, t_sec) * (1.0 - smoothstep(1.25, 1.60, t_sec));
		float ember_dot = (1.0 - smoothstep(0.04, 0.26, r)) * smoothstep(0.85, 1.15, t_sec) * (1.0 - smoothstep(1.22, 1.42, t_sec));
		opacity = clamp(spot * fade * 0.58, 0.0, 1.0);
		color = mix(vec3(0.10, 0.08, 0.08), deep_red, ember_dot * 0.85);
		color = mix(color, hot_orange, ember_dot * 0.55);
		boost = mix(0.82, 1.45, ember_dot);
	} else if (kind == 18) {
		// kind == 18: Vòng phản lực gió đẩy lùi (Sky Dive lần bay đầu — 0 sát thương, dải xoáy gió sắc nét cách điệu).
		float phase = clamp(age, 0.0, 1.0);
		float fade = smoothstep(0.0, 0.08, phase) * (1.0 - smoothstep(0.46, 1.0, phase));
		float front = mix(0.18, 0.96, pow(phase, 0.72));
		float spiral1 = pow(max(0.0, sin(a * 4.0 - r * 11.0 + TIME * 14.0)), 2.0);
		float spiral2 = pow(max(0.0, sin(a * 6.0 - r * 8.5 + TIME * 10.0 + 1.4)), 2.5);
		float n_wind = fbm(vec2(a * 3.5 - TIME * 5.0, r * 5.0 - phase * 3.5));
		float outer_arc = (1.0 - smoothstep(0.015, 0.075, abs(r - front))) * (0.45 + 0.55 * spiral1);
		float inner_swirl = (1.0 - smoothstep(0.02, 0.14, abs(r - front * 0.68))) * max(spiral1, spiral2) * (0.50 + 0.50 * n_wind);
		float core_gust = (1.0 - smoothstep(0.02, 0.12, abs(r - front * 0.40))) * spiral2 * 0.72;
		opacity = clamp(max(outer_arc, max(inner_swirl * 0.85, core_gust)) * fade, 0.0, 0.92);
		vec3 wind_cool = vec3(0.76, 0.88, 0.96);
		vec3 wind_core = vec3(0.97, 0.99, 1.0);
		color = mix(vec3(0.52, 0.58, 0.64), wind_cool, clamp(inner_swirl + outer_arc * 0.7, 0.0, 1.0));
		color = mix(color, wind_core, clamp(pow(outer_arc, 1.35) + core_gust * 0.65, 0.0, 1.0));
		boost = mix(1.05, 1.60, outer_arc);
	} else if (kind == 19) {
		// kind == 19: Vòng cảnh báo rực lửa cho Sky Dive đợt 1–4 (0.7s).
		float phase = clamp(age, 0.0, 1.0);
		float pulse = 0.90 + 0.10 * sin(TIME * 24.0);
		float n_ring = fbm(vec2(a * 5.0 + TIME * 2.8, r * 5.0 - TIME * 3.5));
		float jag = (n_ring - 0.5) * 0.09;
		float ring_r = 0.88 + jag;
		float main_ring = 1.0 - smoothstep(0.018, 0.068, abs(r - ring_r));
		float tongues = pow(max(0.0, sin(a * 14.0 + TIME * 8.5 + n_ring * 4.0)), 2.0)
			* (1.0 - smoothstep(0.02, 0.14, abs(r - (ring_r + 0.03)))) * (0.55 + 0.45 * n_ring);
		float inner_fill = (1.0 - smoothstep(0.0, 0.88, r)) * mix(0.08, 0.24, phase);
		// Vòng thu hẹp báo thời điểm sắp chạm đất trong 0.3s cuối sau khi khóa vị trí.
		float shrink_r = mix(0.88, 0.16, smoothstep(0.0, 1.0, phase));
		float countdown_ring = (1.0 - smoothstep(0.012, 0.040, abs(r - shrink_r))) * 0.65;
		float fade_in = smoothstep(0.0, 0.10, phase);
		opacity = clamp(max(max(main_ring, tongues * 0.95), max(inner_fill, countdown_ring)) * fade_in * pulse, 0.0, 1.0);
		color = mix(deep_red, hot_orange, clamp(main_ring * 0.85 + tongues * 0.95 + countdown_ring * 0.6, 0.0, 1.0));
		color = mix(color, bright_gold, clamp(pow(main_ring, 1.8) * 0.85 + tongues * 0.60 + countdown_ring * 0.75, 0.0, 1.0));
		color = mix(color, ivory, pow(main_ring, 3.0) * smoothstep(0.55, 1.0, phase) * 0.75);
		boost = mix(1.20, 1.80, max(main_ring, countdown_ring * 0.7));
	} else if (kind == 20) {
		// kind == 20: Vòng cảnh báo Crosshair tròn xoay (giống tâm ngắm game bắn súng) cho đợt đáp Sky Dive thứ 5!
		float phase = clamp(age, 0.0, 1.0);
		float fade_in = smoothstep(0.0, 0.10, phase);
		float rot = TIME * 2.2 + phase * 2.4;
		float cs = cos(rot);
		float sn = sin(rot);
		vec2 rp = vec2(p.x * cs - p.y * sn, p.x * sn + p.y * cs);
		float n_f = fbm(vec2(a * 6.0 - TIME * 3.5, r * 5.0 - TIME * 4.2));
		float outer_r = 0.89 + (n_f - 0.5) * 0.06;
		float outer_ring = 1.0 - smoothstep(0.018, 0.068, abs(r - outer_r));
		float outer_flames = pow(max(0.0, sin(a * 18.0 - TIME * 9.0 + n_f * 4.5)), 2.0)
			* (1.0 - smoothstep(0.02, 0.13, abs(r - (outer_r + 0.025))));
		// Vòng tâm ngắm bên trong siết nhẹ vào tâm khi gần đáp.
		float inner_r = mix(0.58, 0.42, smoothstep(0.45, 1.0, phase));
		float inner_ring = 1.0 - smoothstep(0.012, 0.036, abs(r - inner_r));
		// 4 vạch chữ thập crosshair xoay quanh tâm (cắt ngang từ inner_r tới outer_r và chĩa vào gần tâm).
		float tick_x = (1.0 - smoothstep(0.012, 0.032, abs(rp.y))) * step(0.18, abs(rp.x)) * (1.0 - smoothstep(0.86, 0.94, abs(rp.x)));
		float tick_y = (1.0 - smoothstep(0.012, 0.032, abs(rp.x))) * step(0.18, abs(rp.y)) * (1.0 - smoothstep(0.86, 0.94, abs(rp.y)));
		float crosshair = max(tick_x, tick_y);
		float center_dot = 1.0 - smoothstep(0.03, 0.075, r);
		float fill = (1.0 - smoothstep(0.0, 0.88, r)) * mix(0.10, 0.28, phase);

		float reticle = max(inner_ring, max(crosshair, center_dot));
		opacity = clamp(max(max(outer_ring, outer_flames * 0.92), max(reticle, fill)) * fade_in, 0.0, 1.0);
		color = mix(deep_red, hot_orange, clamp(outer_ring * 0.95 + outer_flames + reticle * 0.55, 0.0, 1.0));
		color = mix(color, bright_gold, clamp(reticle * 0.95 + outer_ring * 0.55, 0.0, 1.0));
		color = mix(color, ivory, clamp(pow(reticle, 2.4) * 0.48 + center_dot * 0.75, 0.0, 1.0));
		boost = mix(1.22, 1.85, max(reticle, outer_ring * 0.8));
	} else if (kind == 21) {
		// kind == 21: Hố crater lõm xuống đất với lòng hố tối sâu + vành đá vỡ + rãnh dung nham nóng vàng cam sau cú đáp Sky Dive!
		float phase = clamp(age, 0.0, 1.0);
		float fade = 1.0 - smoothstep(0.72, 1.0, phase);
		float n_cr = fbm(p * 5.2);
		float n_fine = value_noise(p * 12.0);
		float pit_r = r + (n_cr - 0.5) * 0.14;
		float pit_depth = 1.0 - smoothstep(0.18, 0.72, pit_r);
		float bowl_shadow = smoothstep(0.0, 0.58, pit_r) * (1.0 - smoothstep(0.58, 0.74, pit_r));
		float raised_lip = (1.0 - smoothstep(0.03, 0.15, abs(pit_r - 0.72))) * (0.55 + 0.45 * n_fine);
		float cracks = 0.0;
		for (int i = 0; i < 9; i++) {
			float fi = float(i);
			float base_a = fi * 0.6981 + sin(fi * 3.1) * 0.18;
			float jitter = (fbm(vec2(r * 4.8 + fi * 2.7, fi * 1.9)) - 0.5) * 0.28;
			float da = abs(atan(sin(a - base_a - jitter), cos(a - base_a - jitter)));
			float arc_d = da * max(r, 0.05);
			float reach = 0.80 + 0.16 * hash21(vec2(fi, 4.1));
			float w = mix(0.056, 0.014, r);
			cracks = max(cracks, (1.0 - smoothstep(w * 0.35, w, arc_d)) * (1.0 - smoothstep(reach * 0.68, reach, r)));
		}
		float cool = 1.0 - smoothstep(0.10, 0.84, phase);
		float magma = clamp((pow(1.0 - smoothstep(0.0, 0.48, pit_r), 1.6) * 0.82 + cracks * 0.92) * cool, 0.0, 1.0);
		float outer_scorch = (1.0 - smoothstep(0.58, 0.98, pit_r)) * 0.60;

		opacity = clamp(max(max(pit_depth * 0.98, raised_lip * 0.88), max(cracks * 0.96, outer_scorch)) * fade, 0.0, 1.0);
		color = mix(stone_mid, stone_dark, clamp(outer_scorch + raised_lip * 0.5, 0.0, 1.0));
		color = mix(color, vec3(0.03, 0.025, 0.028), clamp(pit_depth * 0.95 + bowl_shadow * 0.65 + cracks * 0.72, 0.0, 1.0));
		color = mix(color, vec3(0.42, 0.36, 0.32), raised_lip * 0.62);
		color = mix(color, deep_red, smoothstep(0.12, 0.55, magma));
		color = mix(color, hot_orange, smoothstep(0.36, 0.78, magma));
		color = mix(color, bright_gold, smoothstep(0.68, 1.0, magma));
		boost = mix(0.82, 1.72, magma);
	} else {
		// kind == 22: Sóng chấn động đẩy lùi toàn phòng (Resonance Slam — vòng lửa cam-vàng sắc nét quét ngang toàn sàn, 0 sát thương).
		float phase = clamp(age, 0.0, 1.0);
		float fade = smoothstep(0.0, 0.06, phase) * (1.0 - smoothstep(0.58, 1.0, phase));
		float front = mix(0.06, 0.96, pow(phase, 0.78));
		float n_sw = fbm(vec2(a * 6.0 + TIME * 3.0, r * 7.0 - phase * 6.0));
		float main_wave = 1.0 - smoothstep(0.012, 0.058, abs(r - front));
		float trail_wave = (1.0 - smoothstep(0.018, 0.14, abs(r - (front - 0.055)))) * (0.45 + 0.55 * n_sw);
		float echo_ring = (1.0 - smoothstep(0.010, 0.042, abs(r - front * 0.74))) * 0.62;
		float radial_streaks = pow(max(0.0, sin(a * 16.0 + n_sw * 3.5)), 3.0)
			* smoothstep(front - 0.22, front, r) * (1.0 - smoothstep(front, front + 0.03, r)) * 0.65;
		opacity = clamp(max(max(main_wave, trail_wave * 0.80), max(echo_ring, radial_streaks)) * fade, 0.0, 0.96);
		color = mix(deep_red, hot_orange, clamp(trail_wave * 0.95 + echo_ring * 0.85 + radial_streaks, 0.0, 1.0));
		color = mix(color, bright_gold, clamp(main_wave * 0.92 + echo_ring * 0.55 + radial_streaks * 0.55, 0.0, 1.0));
		color = mix(color, ivory, pow(main_wave, 2.4) * 0.68);
		boost = mix(1.20, 1.85, main_wave);
	}

	ALBEDO = color * boost;
	EMISSION = color * (0.32 + (boost - 1.0) * 0.80);
	ALPHA = opacity;
}
