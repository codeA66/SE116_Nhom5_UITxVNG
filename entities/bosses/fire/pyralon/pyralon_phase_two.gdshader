shader_type spatial;
render_mode diffuse_burley, specular_disabled, cull_disabled;

// Shader Pyralon Phase 2 — "Hỏa Ưng Tro Tàn (Ashen Pyre Warrior)" hỗ trợ biến hình tuần tự 4 bước:
// - is_phase_one == true: phủ lên mesh gốc Phase 1 để cắt bỏ dần từng bộ phận đúng lúc bộ phận đó biến hình.
// - is_phase_one == false: phủ lên mesh Phase 2 (Pyralon_P2_Body / Pyralon_P2_Axe) hiện từng phần theo 4 stage riêng biệt:
//   stage_axe (0..1)   -> Bước 1: Rìu lưỡi liềm & vòng lò lửa bùng sáng
//   stage_body (0..1)  -> Bước 2: Đường rạn dung nham ngực/lưng/tay + giáp vai đồng cháy + mép khố cháy xém
//   stage_head (0..1)  -> Bước 3: Lông đầu/cổ tro obsidian + mắt vàng trắng + vương miện mào lửa
//   stage_wings (0..1) -> Bước 4: Đôi cánh gốc đen tro bùng lửa đỏ than -> cam nóng -> mũi vàng trắng
uniform bool transitioning = false;
uniform float stage_axe : hint_range(0.0, 1.0) = 1.0;
uniform float stage_body : hint_range(0.0, 1.0) = 1.0;
uniform float stage_head : hint_range(0.0, 1.0) = 1.0;
uniform float stage_wings : hint_range(0.0, 1.0) = 1.0;
uniform float light_sweep : hint_range(-0.3, 1.6) = -0.3;
uniform bool reverting = false;
uniform float revert_progress : hint_range(0.0, 1.0) = 0.0;

varying vec4 v_col;
varying vec2 v_uv;
varying vec2 v_uv2;
varying vec3 v_local;
varying float v_chest_dist;

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec4 k = dot(i, vec3(127.1, 311.7, 74.7)) + vec4(0.0, 127.1, 311.7, 438.8);
	vec4 a = fract(sin(k) * 43758.5453);
	vec4 b = fract(sin(k + 74.7) * 43758.5453);
	vec4 c = mix(a, b, f.z);
	return mix(mix(c.x, c.y, f.x), mix(c.z, c.w, f.x), f.y);
}

float seg_dist(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(0.0001, dot(ba, ba)), 0.0, 1.0);
	return length(pa - ba * h);
}

void vertex() {
	v_col = COLOR;
	v_uv = UV;
	v_uv2 = UV2;
	// glTF lật trục V (V_gltf = 1.0 - V_blender), đảo ngược lại để giải mã chính xác part_code (1..8) và fx_t (0..1).
	float vy = 1.0 - UV.y;
	int part = int(floor(vy * 0.5 + 0.001));
	float fx_t = clamp(vy - float(part) * 2.0, 0.0, 1.0);
	// Khoảng cách chuẩn hóa từ tâm ngực ra đầu/rìu/sải cánh để làn sóng ánh sáng cuối màn biến hình quét mượt khắp người chim.
	v_chest_dist = clamp(length(VERTEX - vec3(0.0, 2.05, 0.0)) / 3.25, 0.0, 1.0);
	// Trong 4 bước đầu giữ độ nổi siêu sát (2.5mm) để tạo hiệu ứng khung lưới năng lượng bọc bộ phận;
	// ngay sau mặt sóng ánh sáng đi qua (swept -> 1), hạ mượt về 0.0mm (trùng khít 100% vị trí cuối cùng, mesh Phase 1 đã bị discard đồng bộ -> không bao giờ nháy 1 frame!).
	if (transitioning) {
		float swept = smoothstep(-0.02, 0.06, light_sweep - v_chest_dist);
		VERTEX += NORMAL * mix(0.0025, 0.0, swept);
	} else if (reverting) {
		VERTEX += NORMAL * 0.0018;
	}
	// Dập dờn ngọn lửa nhẹ trên vương miện mào lửa (part 7) & chóp lông lửa ngoài cánh (part 8).
	if (part == 7 && fx_t > 0.15) {
		float tip = fx_t * fx_t;
		VERTEX.x += sin(TIME * 9.5 + VERTEX.z * 14.0) * 0.022 * tip;
		VERTEX.y += cos(TIME * 8.2 + VERTEX.x * 16.0) * 0.018 * tip;
	} else if (part == 8 && fx_t > 0.55) {
		float tip = smoothstep(0.55, 1.0, fx_t);
		float flutter = sin(TIME * 7.8 + VERTEX.x * 5.0 + VERTEX.z * 6.0);
		VERTEX.y += flutter * 0.032 * tip;
		VERTEX.z += cos(TIME * 6.5 + VERTEX.y * 5.0) * 0.024 * tip;
	}
	v_local = VERTEX;
}

float stage_value(int stage_idx) {
	if (stage_idx == 0) {
		return stage_axe;
	} else if (stage_idx == 1) {
		return stage_body;
	} else if (stage_idx == 2) {
		return stage_head;
	}
	return stage_wings;
}

void fragment() {
	int stage_idx = int(floor(v_uv.x * 0.5 + 0.001));
	float sweep_u = clamp(v_uv.x - float(stage_idx) * 2.0, 0.0, 1.0);
	float vy = 1.0 - v_uv.y;
	int part = int(floor(vy * 0.5 + 0.001));
	float fx_t = clamp(vy - float(part) * 2.0, 0.0, 1.0);
	vec2 body_uv = vec2(v_uv2.x, 1.0 - v_uv2.y);
	float stg = stage_value(stage_idx);
	float n_burn = noise3(v_local * 5.5 - vec3(0.0, TIME * 2.4, 0.0));
	float cut = sweep_u + (n_burn - 0.5) * 0.16;
	float front = stg * 1.24 - 0.12 - cut;
	float burn_edge = 0.0;

	if (stg <= 0.001 || front < 0.0) { discard; }
	if (stg < 0.999) {
		burn_edge = 1.0 - smoothstep(0.0, 0.22, front);
	}
	if (reverting) {
		// Dùng trực tiếp chiều cao giải phẫu bind-pose (v_local.y trước khi skinning) để hiệu ứng Phase 2 tan cực mượt
		// từ đỉnh mào lửa & đầu (rank = 1.0) -> vai/cánh -> ngực/rìu -> hông -> chân (rank = 0.0) mà không bị đốm loang UV!
		float part_rank = clamp((v_local.y - 0.12) / 2.82, 0.0, 0.94);
		if (part == 7) {
			part_rank = mix(0.92, 1.00, fx_t);
		} else if (part == 1) {
			part_rank = mix(0.50, 0.22, fx_t);
		}
		float rev_cut = 1.10 - revert_progress * 1.24 + (n_burn - 0.5) * 0.14;
		float rev_diff = rev_cut - part_rank;
		if (rev_diff < 0.0) { discard; }
		burn_edge = max(burn_edge, 1.0 - smoothstep(0.0, 0.20, rev_diff));
	}

	vec3 obsidian = vec3(0.08, 0.075, 0.09);
		vec3 ember_red = vec3(0.84, 0.10, 0.02);
		vec3 hot_orange = vec3(1.0, 0.42, 0.035);
		vec3 gold_flame = vec3(1.0, 0.82, 0.22);
		vec3 white_hot = vec3(1.0, 0.97, 0.78);

		float pulse = 0.90 + 0.10 * sin(TIME * 5.5 + n_burn * 4.5);
		float n_flow = noise3(v_local * 4.2 - vec3(0.0, TIME * 3.8, 0.0));
		float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.3);

		vec3 albedo = v_col.rgb;
		vec3 emission = vec3(0.0);

		if (part == 1) {
			// Stage 1: Rìu lưỡi liềm nung trắng-vàng-cam + vòng lõi lò lửa.
			if (fx_t > 0.75) {
				vec3 molten = mix(hot_orange, gold_flame, smoothstep(0.75, 0.95, fx_t));
				molten = mix(molten, white_hot, smoothstep(0.92, 1.0, fx_t) * (0.65 + 0.35 * n_flow));
				albedo = molten * 0.45;
				emission = molten * (1.55 + 0.45 * n_flow) * pulse;
			} else if (fx_t > 0.12) {
				albedo = mix(v_col.rgb, ember_red, fx_t * 0.65);
				emission = mix(ember_red, hot_orange, n_flow) * fx_t * 0.75;
			}
		} else if (part == 2) {
			// Stage 2: Thân tro tối + 2-3 đường rạn nhiệt dung nham đối xứng sắc nét (ngực, lưng & bắp tay).
			albedo = v_col.rgb;
			float crack_mask = 0.0;
			if (fx_t > 0.5 && body_uv.x < 1.8) {
				// Đường rạn chữ Y/X đối xứng trên ngực & lưng (body_uv.x = abs_x_norm, body_uv.y = z_norm).
				vec2 cp = body_uv + (n_burn - 0.5) * vec2(0.055, 0.045);
				float d_stem = seg_dist(cp, vec2(0.0, 0.38), vec2(0.0, 0.68));
				float d_upper = seg_dist(cp, vec2(0.0, 0.66), vec2(0.58, 0.90));
				float d_lower = seg_dist(cp, vec2(0.0, 0.40), vec2(0.54, 0.24));
				float d_rib = seg_dist(cp, vec2(0.32, 0.48), vec2(0.74, 0.58));
				float d_min = min(min(d_stem, d_upper), min(d_lower, d_rib));
				crack_mask = 1.0 - smoothstep(0.032, 0.095, d_min);
			} else if (fx_t > 0.5 && body_uv.x >= 1.9 && body_uv.x < 3.5) {
				// Đường rạn đối xứng dọc bắp tay.
				vec2 ap = vec2(body_uv.x - 2.0, body_uv.y) + (n_burn - 0.5) * 0.06;
				float d_arm = seg_dist(ap, vec2(0.12, 0.18), vec2(0.76, 0.62));
				crack_mask = (1.0 - smoothstep(0.038, 0.115, d_arm)) * 0.88;
			}
			if (crack_mask > 0.02) {
				vec3 magma = mix(ember_red, hot_orange, smoothstep(0.20, 0.72, crack_mask));
				magma = mix(magma, gold_flame, smoothstep(0.68, 1.0, crack_mask));
				albedo = mix(albedo, magma * 0.5, crack_mask);
				emission = magma * crack_mask * (1.45 + 0.35 * n_flow) * pulse;
			}
		} else if (part == 3) {
			// Stage 2: Giáp vai, thắt lưng, vòng tay & cổ chân đồng cháy đen có viền nóng đỏ.
			float rim_heat = clamp(fx_t * 0.75 + rim * 0.58, 0.0, 1.0);
			float edge_glow = smoothstep(0.52, 0.96, rim_heat + (n_burn - 0.5) * 0.22);
			albedo = mix(vec3(0.13, 0.085, 0.065), vec3(0.28, 0.14, 0.06), rim_heat * 0.45);
			emission = mix(ember_red, hot_orange, edge_glow) * edge_glow * 1.15 * pulse;
		} else if (part == 4) {
			// Stage 2: Khố vải đỏ có mép dưới cháy đen xém phát sáng than hồng nhẹ.
			float char_zone = smoothstep(0.22, 0.78, fx_t + (n_burn - 0.5) * 0.25);
			float ember_band = smoothstep(0.28, 0.55, fx_t + (n_burn - 0.5) * 0.22) * (1.0 - smoothstep(0.65, 0.95, fx_t));
			albedo = mix(vec3(0.36, 0.045, 0.04), vec3(0.07, 0.05, 0.05), char_zone);
			emission = mix(ember_red, hot_orange, n_flow) * ember_band * 1.25 * pulse;
		} else if (part == 5) {
			// Stage 3: Lông đầu & cổ chuyển tro đen obsidian tương phản cao.
			albedo = obsidian + vec3(0.02, 0.015, 0.02) * rim;
			emission = ember_red * rim * 0.14;
		} else if (part == 6) {
			// Stage 3: Mắt đại bàng sắc trắng tinh sáng vàng nhẹ (fx_t > 0.7) và mỏ vàng cam sắc nét (fx_t ~ 0.4).
			if (fx_t > 0.7) {
				albedo = vec3(1.0, 0.99, 0.94);
				emission = vec3(1.0, 0.96, 0.80) * 2.55;
			} else {
				albedo = vec3(0.95, 0.58, 0.11);
				emission = vec3(0.95, 0.42, 0.05) * (0.28 + rim * 0.35);
			}
		} else if (part == 7) {
			// Stage 3: Vương miện mào lửa đỏ cam -> vàng trắng rực trên đỉnh đầu.
			float h = clamp(fx_t + (n_flow - 0.5) * 0.24, 0.0, 1.0);
			vec3 cr = mix(ember_red, hot_orange, smoothstep(0.05, 0.52, h));
			cr = mix(cr, gold_flame, smoothstep(0.45, 0.85, h));
			cr = mix(cr, white_hot, smoothstep(0.80, 1.0, h));
			albedo = cr * 0.35;
			emission = cr * (1.45 + h * 0.85) * pulse;
		} else if (part == 8) {
			// Stage 4: Đôi cánh rực lửa — gốc cánh tro đen obsidian -> đỏ than -> cam nóng -> mũi cánh vàng trắng chói!
			float wf = clamp(fx_t + (n_flow - 0.5) * 0.18, 0.0, 1.0);
			float ignite = smoothstep(0.24, 0.44, wf);
			vec3 flame_w = mix(ember_red, hot_orange, smoothstep(0.32, 0.66, wf));
			flame_w = mix(flame_w, gold_flame, smoothstep(0.60, 0.88, wf));
			flame_w = mix(flame_w, white_hot, smoothstep(0.84, 1.0, wf));
			albedo = mix(obsidian, flame_w * 0.36, ignite);
			emission = flame_w * ignite * (1.15 + smoothstep(0.55, 1.0, wf) * 1.05) * pulse;
		}

	// Đường viền cháy bùng sáng chạy dọc biên biến hình của từng bước.
	emission += mix(hot_orange, white_hot, burn_edge) * burn_edge * 1.95;
	// Làn sóng ánh sáng trắng-vàng lan tỏa khắp người chim ở cuối màn biến hình, chuyển từ lớp khung lưới sang 3D mượt.
	if (transitioning && light_sweep > -0.2) {
		float sw_d = abs(light_sweep - v_chest_dist);
		float wave_band = 1.0 - smoothstep(0.0, 0.125, sw_d);
		float wave_core = 1.0 - smoothstep(0.0, 0.045, sw_d);
		vec3 flash_col = mix(gold_flame, white_hot, wave_core);
		albedo = mix(albedo, white_hot, wave_core * 0.72);
		emission += flash_col * (wave_band * 1.65 + wave_core * 1.90);
	}
	ALBEDO = albedo;
	EMISSION = emission;
	ROUGHNESS = 0.86;
}
