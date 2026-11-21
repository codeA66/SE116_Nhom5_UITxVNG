shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// Bộ shader VFX hoàn toàn mới riêng cho Sky Dive Meteor Barrage (KHÔNG tái dùng hiệu ứng nổ lông / khe nứt cũ):
// kind == 0: Hố crater 3D lõm nứt lở đất đá thật + mạch dung nham cháy nguội dần theo thời gian
// kind == 1: Cột lửa phun trào đa tầng 3D chân thật (lõi trắng-vàng xoáy -> cam rực -> đỏ lửa -> khói đen cuộn ở đỉnh)
// kind == 2: Mảnh đá vỡ & cục nham thạch văng theo quỹ đạo trọng lực Parabol (ballistic debris)
// kind == 3: Sóng xung kích trang trí (decorative room shockwave — nhẹ đợt 1–4, dữ dội nhiều tầng đợt 5)
uniform int kind = 0;
uniform float age = 0.0;
uniform float heavy = 0.0;

varying vec2 v_uv;
varying vec4 v_col;
varying vec3 v_pos;
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

float fbm(vec2 p) {
	float v = 0.0;
	v += 0.54 * noise2(p);
	v += 0.30 * noise2(p * 2.18 + vec2(9.1, 17.3));
	v += 0.16 * noise2(p * 4.42 - vec2(13.4, 6.2));
	return v;
}

void vertex() {
	v_uv = UV;
	v_col = COLOR;
	vec3 pos = VERTEX;

	if (kind == 1) {
		// Cột lửa phun trào 3D sống động: nở nhanh ở đáy rồi cuộn xoáy thuôn bùng lên trời.
		float t = clamp(age, 0.0, 1.0);
		float h = clamp(UV.y, 0.0, 1.0);
		float burst = smoothstep(0.0, 0.12, t);
		float collapse = 1.0 - smoothstep(0.62, 1.0, t);
		float twist = h * 3.8 - TIME * 7.5 + COLOR.r * 6.2831;
		float billow = sin(twist) * 0.12 * h + cos(h * 9.0 - TIME * 12.0 + COLOR.g * 6.28) * 0.08 * (0.3 + h);
		float flare_xz = mix(0.62, 1.08, burst) * mix(1.0, 0.45, pow(h, 1.25)) * (0.85 + 0.35 * collapse);
		pos.xz = pos.xz * (flare_xz + billow);
		pos.y *= mix(0.28, 1.05, burst) * mix(0.70, 1.0, collapse);
	} else if (kind == 2) {
		// Mảnh đá & cục nham thạch bắn tung theo trọng lực parabol rồi rơi xuống quanh miệng hố.
		float t = clamp(age, 0.0, 1.0);
		float ang = COLOR.r * 6.2831853;
		float spd = mix(1.25, 3.15, COLOR.g) * mix(1.0, 1.38, heavy);
		float up_v = mix(2.2, 5.4, COLOR.b) * mix(1.0, 1.32, heavy);
		float spin = t * mix(6.0, 14.0, COLOR.g) + COLOR.r * 10.0;
		float cs = cos(spin);
		float sn = sin(spin);
		vec3 rot_v = vec3(pos.x * cs - pos.z * sn, pos.y * cs - pos.x * sn, pos.x * sn + pos.z * cs);
		float grav_y = max(0.03, up_v * t - 5.2 * t * t);
		float rad = spd * (1.0 - pow(1.0 - min(t * 1.15, 1.0), 1.8));
		float sc = smoothstep(0.0, 0.05, t) * (1.0 - smoothstep(0.72, 1.0, t));
		pos = rot_v * sc + vec3(cos(ang) * rad, grav_y, sin(ang) * rad);
	}

	VERTEX = pos;
	v_pos = pos;
	vec3 wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 wp = (MODEL_MATRIX * vec4(pos, 1.0)).xyz;
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - wp);
	v_rim = 1.0 - abs(dot(wn, view_dir));
}

void fragment() {
	vec3 basalt_deep = vec3(0.05, 0.045, 0.05);
	vec3 basalt_mid = vec3(0.16, 0.14, 0.135);
	vec3 basalt_rim = vec3(0.32, 0.28, 0.26);
	vec3 ember_red = vec3(0.86, 0.08, 0.015);
	vec3 hot_orange = vec3(1.0, 0.36, 0.025);
	vec3 gold_flame = vec3(1.0, 0.78, 0.16);
	vec3 white_core = vec3(1.0, 0.96, 0.80);

	vec3 col = basalt_mid;
	float alpha = 1.0;
	float boost = 1.0;

	if (kind == 0) {
		// Hố crater 3D lõm nứt lở chân thật: v_col.r = bán kính chuẩn hóa (0..1), v_col.g = độ gồ đá, v_col.b = vùng vành nhô.
		float t = clamp(age, 0.0, 1.0);
		float fade = 1.0 - smoothstep(0.74, 1.0, t);
		float rad = v_col.r;
		float ang = atan(v_pos.z, v_pos.x);
		float n_rock = fbm(v_pos.xz * 2.4 + vec2(3.1, 7.7));
		float n_cr = fbm(vec2(ang * 4.5, rad * 6.5));

		// 11 đường nứt vỡ đá gãy khúc tỏa từ tâm hố ra vành gờ đá 3D.
		float crack_mask = 0.0;
		for (int i = 0; i < 11; i++) {
			float fi = float(i);
			float a0 = fi * 0.5712 + sin(fi * 2.7) * 0.16;
			float j = (fbm(vec2(rad * 4.2 + fi * 1.9, fi * 3.1)) - 0.5) * 0.24;
			float da = abs(atan(sin(ang - a0 - j), cos(ang - a0 - j)));
			float arc = da * max(rad, 0.06);
			float w = mix(0.055, 0.012, rad);
			float reach = 0.76 + 0.20 * hash21(vec2(fi, 5.3));
			crack_mask = max(crack_mask, (1.0 - smoothstep(w * 0.30, w, arc)) * (1.0 - smoothstep(reach * 0.70, reach, rad)));
		}

		// Lòng hố tối lõm sâu + gờ đá nổi sáng cạnh sắc low-poly + mạch dung nham nóng nguội dần.
		float pit_shade = 1.0 - smoothstep(0.08, 0.62, rad);
		float lip_hi = v_col.b * (0.55 + 0.45 * n_rock);
		float cool = 1.0 - smoothstep(0.10, 0.85, t);
		float lava = clamp((pow(pit_shade, 1.7) * 0.90 + crack_mask * 0.96) * cool * (0.72 + 0.40 * n_cr), 0.0, 1.0);
		float edge_fade = 1.0 - smoothstep(0.84, 1.0, rad + (n_rock - 0.5) * 0.12);

		col = mix(basalt_mid, basalt_deep, clamp(pit_shade * 0.92 + crack_mask * 0.80, 0.0, 1.0));
		col = mix(col, basalt_rim, lip_hi * 0.75);
		col = mix(col, ember_red, smoothstep(0.08, 0.48, lava));
		col = mix(col, hot_orange, smoothstep(0.32, 0.72, lava));
		col = mix(col, gold_flame, smoothstep(0.64, 0.96, lava));
		col = mix(col, white_core, smoothstep(0.86, 1.0, lava) * (1.0 - smoothstep(0.0, 0.28, t)));
		boost = mix(0.92, 1.82, lava);
		alpha = clamp(edge_fade * fade, 0.0, 1.0);
	} else if (kind == 1) {
		// Cột lửa phun trào chân thật đa tầng: lấy mẫu tuần hoàn theo góc (KHÔNG đường nối dọc), lưỡi lửa rách tự nhiên + khói đen cuộn ở đỉnh!
		float t = clamp(age, 0.0, 1.0);
		float h = clamp(v_uv.y, 0.0, 1.0);
		float shell = v_col.b;
		float burn_out = 1.0 - smoothstep(0.32, 1.0, t);
		float ang = atan(v_pos.z, v_pos.x);
		vec2 ring_coord = vec2(cos(ang), sin(ang));

		// Nhiễu FBM liền mạch 360° không có đường seam dọc!
		float warp = fbm(ring_coord * 2.3 + vec2(shell * 3.1, h * 3.2 - TIME * 7.8));
		float turb = fbm(ring_coord * 4.6 + vec2((warp - 0.5) * 1.9, h * 5.8 - TIME * 12.2));
		float tongues = warp * 0.52 + turb * 0.48;

		// Tạo lưỡi lửa nhọn tách khe trong suốt để thấy rõ hố crater 3D & dáng Pyralon bên trong!
		float tongue_cut = smoothstep(mix(0.24, 0.44, shell) + h * 0.24, mix(0.56, 0.78, shell) + h * 0.22, tongues);
		float top_cut = mix(0.42, 1.02, smoothstep(0.0, 0.14, t)) * (0.58 + 0.50 * tongues) * mix(1.04, 0.86, shell);
		float mask_h = smoothstep(0.0, 0.08, h) * (1.0 - smoothstep(top_cut - 0.24, top_cut + 0.02, h));
		float erode = smoothstep(t * 0.94 - 0.14, t * 0.94 + 0.20, tongues + (1.0 - h) * 0.36);
		float edge_soft = pow(clamp(1.0 - v_rim * 0.85, 0.0, 1.0), mix(0.65, 1.35, shell));

		// Khói than cuộn chân thật ở nửa trên ngọn lửa.
		float smoke_zone = smoothstep(0.46, 0.88, h + t * 0.34);
		float heat = clamp((1.0 - h * 0.86) * mix(1.12, 0.72, shell) + (turb - 0.42) * 0.48, 0.0, 1.0);

		col = mix(vec3(0.09, 0.08, 0.09), ember_red, smoothstep(0.06, 0.36, heat));
		col = mix(col, hot_orange, smoothstep(0.28, 0.64, heat));
		col = mix(col, gold_flame, smoothstep(0.56, 0.86, heat));
		col = mix(col, white_core, smoothstep(0.78, 1.0, heat) * (1.0 - shell * 0.70));
		col = mix(col, vec3(0.11, 0.09, 0.10), smoke_zone * mix(0.45, 0.85, shell));

		float base_alpha = mask_h * mix(0.45, 1.0, tongue_cut) * mix(1.0, erode, smoothstep(0.20, 0.85, t)) * burn_out * edge_soft;
		alpha = clamp(base_alpha * mix(0.92, 0.62, shell), 0.0, 0.92);
		boost = mix(0.90, 2.05, heat * (1.0 - smoke_zone * 0.75));
	} else if (kind == 2) {
		// Mảnh đá vỡ & nham thạch văng ra từ hố crater.
		float t = clamp(age, 0.0, 1.0);
		float is_lava = step(0.62, v_col.a);
		float cool = 1.0 - smoothstep(0.20, 0.92, t);
		col = mix(basalt_mid, basalt_rim, v_col.b * 0.65);
		col = mix(col, mix(hot_orange, gold_flame, cool), is_lava * cool);
		boost = mix(0.95, 1.65, is_lava * cool);
		alpha = 1.0 - smoothstep(0.74, 1.0, t);
	} else {
		// Sóng xung kích trang trí (decorative): mảnh sắc nét, có vòng lặp & vệt tia hướng tâm rõ ràng (đợt 1–4 nhẹ, đợt 5 dữ dội 2 tầng)!
		vec2 p = v_uv * 2.0 - 1.0;
		float r = length(p);
		float a = atan(p.y, p.x);
		vec2 dir_p = r > 0.001 ? p / r : vec2(1.0, 0.0);
		float t = clamp(age, 0.0, 1.0);
		float fade = smoothstep(0.0, 0.06, t) * (1.0 - smoothstep(0.40, 1.0, t));
		float front = mix(0.14, 0.96, pow(t, 0.74));
		float n_sw = fbm(dir_p * 3.8 + vec2(r * 5.0 - t * 4.5, TIME * 1.4));

		float w1 = mix(0.022, 0.044, heavy);
		float ring1 = (1.0 - smoothstep(0.006, w1, abs(r - front))) * (0.70 + 0.30 * n_sw);
		float halo1 = (1.0 - smoothstep(w1, w1 * 2.6, abs(r - (front - 0.025)))) * (0.24 + 0.26 * n_sw) * mix(0.45, 0.85, heavy);
		float ring2 = (1.0 - smoothstep(0.006, w1 * 0.80, abs(r - front * 0.70))) * mix(0.20, 0.80, heavy);
		float streaks = pow(max(0.0, sin(a * 22.0 + n_sw * 3.6)), 4.0)
			* smoothstep(front - 0.16, front, r) * (1.0 - smoothstep(front, front + 0.025, r)) * mix(0.32, 0.92, heavy);

		float peak_alpha = mix(0.46, 0.90, heavy);
		alpha = clamp(max(max(ring1, halo1), max(ring2, streaks)) * fade * peak_alpha, 0.0, peak_alpha);
		vec3 light_col = mix(vec3(0.84, 0.66, 0.45), hot_orange, heavy);
		col = mix(light_col, gold_flame, clamp(ring1 * 0.85 + streaks * 0.75, 0.0, 1.0));
		col = mix(col, white_core, pow(ring1, 2.0) * mix(0.45, 0.92, heavy));
		boost = mix(1.18, 2.00, heavy * ring1);
	}

	if (alpha <= 0.01) {
		discard;
	}
	ALBEDO = col * boost;
	EMISSION = col * max(0.0, boost - 0.85) * 0.95;
	ALPHA = alpha;
}
