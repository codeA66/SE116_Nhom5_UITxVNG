shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// Shader VFX trong suốt cho bộ 3 chiêu Phase 2 Hổ Răng Kiếm:
// vfx_kind == 0: Khe cổng hư vô phẳng trên sàn + luồng lửa cuộn bừng quanh mép cắt (Void Dive — không vòng sci-fi)
// vfx_kind == 1: Đường ống trụ cảnh báo ngang với các vệt lửa cách điệu chảy dọc chiều ống (KHÔNG mũi tên)
// vfx_kind == 2: 3 vết móng cào thô sắc nét phát sáng cam-đỏ glow + lưỡi lửa xé gió chéo độc đáo (KHÔNG hình chữ nhật vàng)
// vfx_kind == 3: Các vệt lửa xoáy tụ từ hư vô (Flame Reformation Frame 1-3)
// vfx_kind == 4: Sóng nhiệt mặt đất khi hổ hạ dáng tái hình thành (Flame Reformation Frame 4)
uniform int vfx_kind = 0;
uniform float progress = 0.0;
uniform float strength = 1.0;

varying vec2 v_uv;
varying vec4 v_col;
varying float v_rim;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.5);
	return fract(p.x * p.y);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

float fbm2(vec2 p) {
	float v = 0.0;
	v += 0.55 * noise2(p);
	v += 0.30 * noise2(p * 2.15 + vec2(7.3, 13.1));
	v += 0.15 * noise2(p * 4.45 - vec2(11.2, 5.4));
	return v;
}

void vertex() {
	v_uv = UV;
	v_col = COLOR;
	if (vfx_kind == 1) {
		float along_v = clamp(UV.y * 2.0, 0.0, 1.0);
		float end_flare = pow(abs(along_v * 2.0 - 1.0), 4.0);
		VERTEX.xz *= 1.0 + end_flare * 0.22;
	} else if (vfx_kind == 3) {
		float t = UV.x;
		float width_side = UV.y * 2.0 - 1.0;
		float seed = COLOR.r;
		float tier = COLOR.g;
		float p = clamp(progress, 0.0, 1.0);
		float inward = smoothstep(0.0, 0.88, p);
		float radius = mix(3.4, 0.42, inward) * mix(0.68, 1.18, COLOR.b) * (1.0 + t * 0.48);
		float spin = seed * 6.2831853 + p * 7.8 + t * 2.6;
		float y_arc = mix(0.35, 2.15, tier) + sin(t * 3.14159 + seed * 6.0) * 0.45 * (1.0 - inward * 0.55);
		vec3 pos = vec3(cos(spin) * radius, y_arc, sin(spin) * radius);
		vec3 tangent = normalize(vec3(-sin(spin), 0.18, cos(spin)));
		vec3 up_v = normalize(cross(tangent, normalize(vec3(cos(spin), 0.0, sin(spin)))));
		float half_w = sin(t * 3.14159) * mix(0.26, 0.10, inward) * (1.0 - smoothstep(0.75, 1.0, p));
		VERTEX = pos + up_v * (width_side * half_w);
	}
	vec3 wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - wp);
	v_rim = 1.0 - abs(dot(wn, view_dir));
}

void fragment() {
	vec3 deep_red = vec3(0.78, 0.04, 0.015);
	vec3 crimson = vec3(0.95, 0.12, 0.02);
	vec3 hot_orange = vec3(1.0, 0.36, 0.03);
	vec3 gold = vec3(1.0, 0.78, 0.18);
	vec3 ivory = vec3(1.0, 0.95, 0.76);

	vec3 col = hot_orange;
	float alpha = 0.0;
	float boost = 1.25;

	if (vfx_kind == 0) {
		// Khe rách không gian hẹp dọc theo hướng lao đầu trên sàn + các lưỡi lửa rách tỏa mạnh từ ranh giới hổ chui xuống (KHÔNG vòng tròn sci-fi).
		vec2 p = v_uv * 2.0 - 1.0;
		float a = atan(p.y, p.x);
		float n_flame = fbm2(vec2(p.x * 4.5, p.y * 5.0 - TIME * 5.2));
		float n_sharp = noise2(vec2(p.x * 11.0 + TIME * 2.0, p.y * 9.0 - TIME * 7.5));
		// Khe rách thuôn hẹp dọc theo thân hổ thay vì lỗ tròn.
		float slit = length(vec2(p.x * 2.95 + (n_flame - 0.5) * 0.35, p.y * 1.10));
		float rays = pow(max(0.0, sin(a * 11.0 + n_flame * 5.0 + TIME * 7.5)), 2.2);
		float dark_void = 1.0 - smoothstep(0.18, 0.44, slit + (n_sharp - 0.5) * 0.16);
		float seam_rim = (1.0 - smoothstep(0.02, 0.26, abs(slit - 0.42 - (n_flame - 0.5) * 0.18))) * (0.65 + 0.55 * n_sharp);
		float flare_licks = smoothstep(0.24, 0.55, slit) * (1.0 - smoothstep(0.58, 1.02, slit)) * rays * (0.45 + 0.65 * n_flame);
		float heat_wake = (1.0 - smoothstep(0.45, 0.98, length(vec2(p.x * 1.45, p.y * 1.05)))) * smoothstep(0.48, 0.85, n_flame) * 0.48;
		float active_pulse = smoothstep(0.0, 0.14, progress) * (1.0 - smoothstep(0.84, 1.0, progress));
		float energy = clamp(seam_rim * 1.08 + flare_licks * 1.05 + heat_wake, 0.0, 1.0);
		alpha = clamp(max(dark_void * 0.94, energy * 0.90) * active_pulse, 0.0, 1.0);
		col = mix(vec3(0.02, 0.005, 0.01), deep_red, clamp(energy * 1.10, 0.0, 1.0));
		col = mix(col, crimson, smoothstep(0.18, 0.58, energy));
		col = mix(col, hot_orange, smoothstep(0.42, 0.84, energy));
		col = mix(col, gold, smoothstep(0.75, 1.0, energy * n_sharp * 1.35));
		boost = mix(0.60, 1.85, energy);
	} else if (vfx_kind == 1) {
		// Đường ống trụ cảnh báo: CylinderMesh trải UV.y mặt bên trong [0..0.5], nhân 2 để đối xứng cả 2 đầu!
		float along = clamp(v_uv.y * 2.0, 0.0, 1.0); // 0 = đầu vào -> 1 = đầu ra
		float around = v_uv.x;
		float rim = pow(clamp(v_rim, 0.0, 1.0), 1.80);
		float end_glow = pow(abs(along * 2.0 - 1.0), 8.0) * smoothstep(0.0, 0.05, along) * smoothstep(1.0, 0.95, along);
		float end_mask = smoothstep(0.0, 0.08, along) * (1.0 - smoothstep(0.92, 1.0, along));
		float soft_caps = smoothstep(0.0, 0.06, along) * smoothstep(1.0, 0.94, along);

		// Hai lớp vệt lửa cách điệu lượn sóng dài chảy nhanh dọc ống theo hướng lao của hổ.
		float flow_fast = fbm2(vec2(around * 8.0, along * 3.8 - TIME * 8.5));
		float flow_sharp = fbm2(vec2(around * 16.0 + (flow_fast - 0.5) * 1.6, along * 6.5 - TIME * 12.0));
		float streak_a = smoothstep(0.52, 0.84, flow_fast * 0.55 + flow_sharp * 0.65) * end_mask;
		float streak_b = smoothstep(0.64, 0.92, sin(around * 18.8495 + flow_fast * 5.2) * 0.5 + 0.5) * smoothstep(0.40, 0.85, flow_fast) * end_mask;
		float flame_streams = clamp(streak_a * 0.78 + streak_b * 0.85, 0.0, 1.0);

		float pulse = 0.88 + 0.12 * sin(TIME * 24.0);
		float entry_fade = smoothstep(0.0, 0.10, progress) * (1.0 - smoothstep(0.88, 1.0, progress));

		float shell = (0.10 + rim * 0.56 + end_glow * 0.52) * soft_caps;
		alpha = clamp(max(shell, flame_streams * 0.88) * entry_fade * pulse * strength, 0.0, 0.92);
		col = mix(deep_red, crimson, clamp(rim * 0.7 + end_glow * 0.6, 0.0, 1.0));
		col = mix(col, hot_orange, clamp(flame_streams * 0.95 + end_glow * 0.45, 0.0, 1.0));
		col = mix(col, gold, smoothstep(0.55, 0.95, flame_streams));
		boost = mix(1.15, 1.82, max(flame_streams, end_glow * 0.75));
	} else if (vfx_kind == 2) {
		// 3 vết móng cào thô, răng cưa sắc nét màu cam hơi đỏ glow mạnh + hiệu ứng lưỡi sóng lửa xé gió chéo (KHÔNG hình chữ nhật vàng!).
		float along = v_uv.x;
		float across = v_uv.y * 2.0 - 1.0;
		float p = clamp(progress, 0.0, 1.0);
		float reveal = smoothstep(along - 0.14, along + 0.03, clamp(p * 3.8, 0.0, 1.18));
		float end_taper = smoothstep(0.0, 0.07, along) * (1.0 - smoothstep(0.86, 1.0, along));

		// Nhiễu sắc đa tầng để 3 vết móng cào có bờ thô gãy khúc, răng cưa sắc bén như móng vuốt cào rách không khí.
		float n_coarse = fbm2(vec2(along * 12.0 - TIME * 3.5, across * 7.0));
		float n_jagged = noise2(vec2(along * 34.0 - TIME * 6.5, across * 16.0));
		float n_tooth = noise2(vec2(along * 52.0, across * 9.0));
		float raw_shift = (n_coarse - 0.5) * 0.17 + (n_jagged - 0.5) * 0.095;
		float thick_var = mix(0.48, 1.32, n_coarse) * (0.62 + 0.38 * n_tooth);

		// 3 vết cào chính bất đối xứng nhẹ (móng giữa dài & sắc hơn 2 móng ngoài).
		float w_outer = 0.062 * thick_var;
		float w_mid = 0.078 * thick_var;
		float d1 = abs(across + 0.54 + raw_shift * 1.15);
		float d2 = abs(across + raw_shift * 0.90);
		float d3 = abs(across - 0.54 - raw_shift * 1.10);
		float c1 = (1.0 - smoothstep(w_outer * 0.18, w_outer, d1)) * smoothstep(0.04, 0.14, along) * (1.0 - smoothstep(0.84, 0.96, along));
		float c2 = (1.0 - smoothstep(w_mid * 0.16, w_mid, d2));
		float c3 = (1.0 - smoothstep(w_outer * 0.18, w_outer, d3)) * smoothstep(0.05, 0.16, along) * (1.0 - smoothstep(0.82, 0.95, along));
		// Viền glow cam-đỏ rộng và đậm quanh 3 vết cào.
		float c_glow = max(
			1.0 - smoothstep(0.03, 0.24, d1),
			max(1.0 - smoothstep(0.03, 0.27, d2), 1.0 - smoothstep(0.03, 0.24, d3))
		) * (0.58 + 0.42 * n_coarse);
		float claws = max(c1, max(c2, c3));

		// Hiệu ứng phụ độc đáo thay hình chữ nhật vàng: lưỡi sóng xé gió lửa nghiêng chéo (oblique shearing flame wakes)
		// tỏa chéo từ đường cào ra 2 bên như luồng khí nóng rách bùng khi hổ phóng qua!
		float side_s = sign(across);
		float shear_u = along * 8.2 - abs(across) * 3.8 - TIME * 4.6;
		float wake_wave = fbm2(vec2(shear_u, abs(across) * 5.6 + side_s * 1.9));
		float wake_ridges = smoothstep(0.50, 0.84, sin(shear_u * 4.8 + wake_wave * 4.4) * 0.5 + 0.5);
		float wake_env = smoothstep(0.08, 0.38, abs(across)) * (1.0 - smoothstep(0.62, 0.99, abs(across)));
		float shear_wisps = wake_ridges * wake_env * smoothstep(0.28, 0.74, wake_wave);

		float claw_fade = 1.0 - smoothstep(0.35, 0.94, p);
		float wake_fade = 1.0 - smoothstep(0.18, 0.86, p);
		float erode = smoothstep(p * 1.05 - 0.22, p * 1.05 + 0.20, n_coarse * 0.65 + n_jagged * 0.35 + claws * 0.45);
		float combined = max(max(claws * claw_fade, c_glow * 0.64 * claw_fade), shear_wisps * 0.82 * wake_fade);
		alpha = clamp(combined * reveal * end_taper * erode, 0.0, 1.0);

		// Tông màu cam hơi đỏ glow rực sắc nét (đỏ thẫm rìa -> đỏ cam sáng thân vết -> điểm nhấn cam lửa nóng sắc cạnh, không bạc trắng / vàng chanh).
		vec3 red_orange = vec3(1.0, 0.24, 0.025);
		vec3 hot_ember_tip = vec3(1.0, 0.54, 0.09);
		col = mix(deep_red, crimson, clamp(c_glow * 0.90 + shear_wisps * 0.95, 0.0, 1.0));
		col = mix(col, red_orange, clamp(claws * 0.95 + shear_wisps * 0.50 + c_glow * 0.42, 0.0, 1.0));
		col = mix(col, hot_ember_tip, pow(claws, 2.0) * (0.48 + 0.42 * n_tooth));
		boost = mix(1.30, 2.25, max(claws, shear_wisps * 0.70));
	} else if (vfx_kind == 3) {
		float t = v_uv.x;
		float edge = 1.0 - smoothstep(0.35, 1.0, abs(v_uv.y * 2.0 - 1.0));
		float taper = sin(t * 3.14159);
		float n = noise2(vec2(t * 5.0 - TIME * 4.0, v_col.r * 9.0));
		float env = smoothstep(0.0, 0.12, progress) * (1.0 - smoothstep(0.68, 0.98, progress));
		alpha = clamp(edge * taper * (0.65 + 0.35 * n) * env * strength, 0.0, 1.0);
		col = mix(crimson, hot_orange, clamp(taper * 0.8 + n * 0.35, 0.0, 1.0));
		col = mix(col, gold, smoothstep(0.55, 0.95, taper * edge));
		col = mix(col, ivory, smoothstep(0.80, 1.0, taper * edge) * (1.0 - t));
		boost = 1.55;
	} else {
		vec2 p = v_uv * 2.0 - 1.0;
		float r = length(p);
		float front = mix(0.24, 0.94, sqrt(clamp(progress, 0.0, 1.0)));
		float ring = 1.0 - smoothstep(0.02, 0.11, abs(r - front));
		float halo = (1.0 - smoothstep(0.04, 0.24, abs(r - front))) * 0.42;
		float fade = smoothstep(0.0, 0.12, progress) * (1.0 - smoothstep(0.45, 1.0, progress));
		alpha = clamp(max(ring, halo) * fade * strength, 0.0, 1.0);
		col = mix(hot_orange, gold, ring * 0.85);
		col = mix(col, ivory, ring * 0.45);
		boost = 1.50;
	}

	ALBEDO = col * boost;
	EMISSION = col * boost * 1.18;
	ALPHA = alpha;
}
