shader_type canvas_item;
render_mode unshaded;

// Anime Impact Frame chuẩn OpenGL 3.3 Compatibility (không dùng GPUParticles3D Shuriken):
// - Đẩy tương phản màn hình thành mảng đen-trắng sắc nét (hoặc đảo âm bản đen nền / trắng hình).
// - Quét tia speed-lines hướng tâm + méo radial nhẹ quanh tâm va chạm chiếu lên màn hình.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec2 center_uv = vec2(0.5, 0.5);
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float invert_amount : hint_range(0.0, 1.0) = 0.0;
uniform float contrast : hint_range(1.0, 14.0) = 8.5;
uniform float boost : hint_range(0.5, 4.0) = 1.45;
uniform float distortion : hint_range(0.0, 0.08) = 0.016;
uniform float speedline_pan : hint_range(0.0, 4.0) = 0.0;
uniform float threshold : hint_range(0.1, 0.9) = 0.46;
uniform float color_accent : hint_range(0.0, 1.0) = 0.0;

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
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
	return mix(
		mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

void fragment() {
	if (intensity <= 0.001) {
		discard;
	}
	vec2 aspect = vec2(SCREEN_PIXEL_SIZE.y / max(SCREEN_PIXEL_SIZE.x, 0.0001), 1.0);
	vec2 delta = (SCREEN_UV - center_uv) * aspect;
	float dist = length(delta);
	float angle = atan(delta.y, delta.x);
	float angle_norm = fract(angle / 6.2831853);

	// Méo radial nhẹ tỏa từ tâm đáp đất ra viền màn hình.
	float n_warp = value_noise(vec2(angle_norm * 48.0, dist * 5.0 - speedline_pan * 2.5));
	vec2 dir = dist > 0.0001 ? normalize(delta) : vec2(0.0);
	float warp_mask = smoothstep(0.04, 0.45, dist) * (1.0 - smoothstep(0.55, 1.15, dist));
	vec2 grab_uv = clamp(SCREEN_UV + (dir / aspect) * ((n_warp - 0.5) * 2.0 * distortion * warp_mask * intensity), vec2(0.0), vec2(1.0));
	vec3 scene = textureLod(screen_texture, grab_uv, 0.0).rgb;

	// Đẩy tương phản cực cao -> lọc ngưỡng trắng/đen -> đảo âm bản anime.
	vec3 boosted = scene * boost;
	vec3 contrasted = clamp(boosted * contrast + 0.5 * (1.0 - contrast), 0.0, 1.0);
	float lum = dot(contrasted, vec3(0.299, 0.587, 0.114));
	float bw = smoothstep(threshold - 0.07, threshold + 0.07, lum);
	float frame_val = mix(bw, 1.0 - bw, invert_amount);

	// Tia anime speed-lines sắc nhọn hướng tâm (mật độ dày quanh viền, cắt sâu vào giữa tạo cảm giác va chạm chấn động!).
	float ray_sector = floor(angle_norm * 144.0);
	float ray_seed = hash11(ray_sector + floor(speedline_pan * 6.0) * 19.0);
	float ray_fine = value_noise(vec2(angle_norm * 172.0, dist * 1.3 - speedline_pan * 3.0));
	float spoke = smoothstep(0.56, 0.84, ray_fine * 0.62 + ray_seed * 0.56);
	float radial_zone = smoothstep(0.11 + ray_seed * 0.14, 0.36 + ray_seed * 0.18, dist);
	float speed_lines = spoke * radial_zone;

	// Vòng shock trắng/đen mảnh bật ngay tâm đáp đất ở đầu impact frame.
	float core_ring = (1.0 - smoothstep(0.008, 0.035, abs(dist - mix(0.05, 0.42, speedline_pan * 0.5)))) * (1.0 - smoothstep(0.45, 0.95, speedline_pan));

	// Màu tia speed-line đối lập với nền: đen ở frame trắng, trắng ở frame đảo âm bản!
	float line_col = mix(0.0, 1.0, invert_amount);
	float final_bw = mix(frame_val, line_col, clamp(speed_lines * 0.92, 0.0, 1.0));
	final_bw = mix(final_bw, 1.0 - line_col, clamp(core_ring * 0.85, 0.0, 1.0));

	// Các impact frame sau (color_accent > 0): điểm thêm sắc đỏ thẫm rực & vàng kim anime trên 1 phần tia speed-line,
	// vòng shockwave trung tâm và viền chuyển sáng-tối của nhân vật/vụ nổ mà vẫn giữ nền đen-trắng tương phản sắc bén!
	vec3 out_col = vec3(final_bw);
	if (color_accent > 0.005) {
		vec3 anime_red = vec3(1.0, 0.13, 0.05);
		vec3 anime_gold = vec3(1.0, 0.82, 0.12);
		float edge_rim = clamp(4.0 * bw * (1.0 - bw) * 1.45, 0.0, 1.0);
		float warm_pick = hash11(ray_sector + 13.7 + floor(speedline_pan * 4.0) * 7.0);
		float is_red_ray = step(0.58, warm_pick) * step(warm_pick, 0.82);
		float is_gold_ray = step(0.82, warm_pick);

		// Viền chuyển sáng-tối của boss/ngọn lửa cháy rực viền đỏ-vàng.
		vec3 rim_tint = mix(anime_red, anime_gold, smoothstep(0.32, 0.72, lum));
		out_col = mix(out_col, rim_tint, edge_rim * color_accent * 0.82);

		// Điểm một số tia speed-line xen kẽ màu đỏ rực & vàng kim dọc quanh khung hình.
		out_col = mix(out_col, anime_red, speed_lines * is_red_ray * color_accent * 0.94);
		out_col = mix(out_col, anime_gold, speed_lines * is_gold_ray * color_accent * 0.96);

		// Vòng xung kích mảnh sắc bén (xé đoạn dạng tia anime chứ không mờ tròn) màu đỏ-vàng quanh tâm nổ.
		float arc_jag = (n_warp - 0.5) * 0.032;
		float arc_break = smoothstep(0.32, 0.54, value_noise(vec2(angle_norm * 26.0, speedline_pan * 2.0)));
		float ring2 = (1.0 - smoothstep(0.004, 0.015, abs(dist + arc_jag - mix(0.16, 0.60, clamp((speedline_pan - 0.9) * 0.65, 0.0, 1.0))))) * arc_break;
		vec3 ring_col = mix(anime_red, anime_gold, step(0.52, n_warp));
		out_col = mix(out_col, ring_col, clamp((core_ring + ring2) * color_accent * 0.95, 0.0, 0.96));

		// Phủ rất nhẹ sắc ấm vào vùng sáng ở tâm nổ (giữ nguyên độ sắc đen-trắng xung quanh).
		float core_warm = (1.0 - smoothstep(0.05, 0.42, dist)) * smoothstep(0.55, 0.95, final_bw);
		out_col = mix(out_col, mix(anime_gold, vec3(1.0, 0.95, 0.75), 0.35), core_warm * color_accent * 0.48);
	}

	COLOR = vec4(out_col, clamp(intensity, 0.0, 1.0));
}
