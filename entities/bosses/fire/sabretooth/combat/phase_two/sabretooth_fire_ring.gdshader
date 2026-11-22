shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform bool shockwave = false;
uniform bool barrier_mode = false;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float draw_progress : hint_range(0.0, 1.0) = 1.0;
uniform float wall_height_t : hint_range(0.0, 1.0) = 0.0;
uniform float barrier_fade : hint_range(0.0, 1.0) = 1.0;
varying float flame;

void vertex() {
	flame = UV2.x;
}

void fragment() {
	float angle = UV.x * 6.283185;
	float radial = abs(UV.y - 0.5);
	float noise = sin(angle * 21.0 - TIME * 9.0 + sin(angle * 9.0 + TIME * 6.0) * 1.4);
	float edge = clamp(fwidth(radial), 0.01, 0.06);
	vec3 dark_red = vec3(0.37, 0.009, 0.028);
	vec3 red = vec3(0.76, 0.024, 0.026);
	vec3 hot = vec3(1.0, 0.22, 0.04);
	vec3 amber = vec3(1.0, 0.62, 0.14);
	vec3 white_hot = vec3(1.0, 0.94, 0.72);
	float alpha;
	vec3 fire;
	float em_mult = 1.0;

	if (barrier_mode) {
		// Chế độ Barrier chiêu Beam:
		// Layer 0 (flame < 0.5): nét bút vẽ vòng tròn lửa chạy dần từ 0 -> 360 độ kèm đầu bút phát sáng trắng-vàng.
		// Layer 1 (flame > 0.5): thành barrier lửa cao dựng dần từ mặt đất lên trời, rõ rệt là tường năng lượng không thể vượt qua.
		float along = UV.x;
		float brush_head = draw_progress;
		float drawn = (1.0 - smoothstep(brush_head - 0.018, brush_head + 0.008, along));
		if (brush_head < 0.995) {
			drawn *= smoothstep(0.0, 0.035, along);
		} else {
			drawn = 1.0;
		}
		if (flame < 0.5) {
			float core = 1.0 - smoothstep(0.025, 0.095 + edge, radial);
			float halo = (1.0 - smoothstep(0.020, 0.44, radial)) * 0.68;
			float nib = exp(-pow((along - brush_head) / 0.024, 2.0)) * step(brush_head, 0.992) * smoothstep(0.005, 0.04, brush_head);
			float nib_ring = nib * (1.0 - smoothstep(0.02, 0.36, radial));
			alpha = max(max(core, halo) * drawn, nib_ring * 1.15) * barrier_fade;
			fire = mix(dark_red, red, clamp(halo + core * 0.5, 0.0, 1.0));
			fire = mix(fire, hot, core * (0.58 + 0.24 * noise));
			fire = mix(fire, amber, core * smoothstep(0.25, 0.95, wall_height_t) * 0.45 + nib_ring * 0.65);
			fire = mix(fire, white_hot, clamp(nib_ring * 1.15, 0.0, 1.0));
			em_mult = mix(0.85, 1.55, max(wall_height_t * 0.6, nib_ring));
		} else {
			if (wall_height_t <= 0.004) {
				discard;
			}
			float h = UV.y;
			float wave1 = sin(angle * 15.0 - TIME * 6.5 + h * 4.5);
			float wave2 = sin(angle * 31.0 + wave1 * 1.4 - TIME * 12.0 - h * 7.5);
			float wave3 = 0.5 + 0.5 * sin(angle * 48.0 + TIME * 9.0 + h * 11.0);
			float tongue_top = 0.80 + 0.14 * (0.5 + 0.5 * wave1) + 0.06 * wave3;
			float cur_top = wall_height_t * tongue_top;
			float height_mask = (1.0 - smoothstep(cur_top - 0.14, cur_top + 0.025, h));
			// Thành lửa rực đỏ-cam đậm bão hòa + các dải năng lượng xoắn chéo nổi bật biểu thị tường chặn barrier!
			float pillars = 0.5 + 0.5 * sin(angle * 24.0 + sin(h * 5.0 - TIME * 5.0) * 0.6);
			float helix = 0.5 + 0.5 * sin(angle * 16.0 - h * 14.0 + TIME * 7.2);
			float base_band = (1.0 - smoothstep(0.0, 0.24, h));
			float crest_band = smoothstep(cur_top - 0.14, cur_top - 0.03, h) * (1.0 - smoothstep(cur_top - 0.02, cur_top + 0.02, h));
			float wall_veil = mix(0.32, 0.66, base_band) + pillars * 0.16 + smoothstep(0.70, 0.98, helix) * 0.18;
			float tongues = smoothstep(0.18, 0.78, 0.48 + 0.32 * wave2 + 0.20 * wave3) * (1.0 - h * 0.42);
			alpha = clamp((wall_veil * 0.76 + tongues * 0.44 + crest_band * 0.58) * height_mask * drawn * barrier_fade, 0.0, 0.92);
			fire = mix(vec3(0.84, 0.04, 0.015), hot, clamp(base_band * 0.78 + tongues * 0.68 + pillars * 0.24, 0.0, 1.0));
			fire = mix(fire, amber, clamp(base_band * 0.58 + crest_band * 0.85 + smoothstep(0.74, 0.98, helix) * 0.45, 0.0, 1.0));
			fire = mix(fire, white_hot, clamp(crest_band * 0.55 + base_band * tongues * 0.32, 0.0, 1.0));
			em_mult = mix(1.05, 1.62, max(base_band * 0.7, crest_band));
		}
		if (alpha <= 0.01) {
			discard;
		}
	} else {
		if (flame > 0.5) {
			float twist = sin(angle * 11.0 - TIME * 8.0 + UV.y * 4.0);
			float strand = sin(angle * 37.0 + twist * 1.5 - TIME * 15.0 - UV.y * 8.0);
			float tongue = 0.28 + 0.57 * pow(max(0.0, noise), 1.65) + strand * 0.14;
			float height = tongue * mix(0.70, 1.10, progress);
			alpha = (1.0 - smoothstep(height - 0.07, height + 0.04, UV.y)) * (1.0 - UV.y * 0.75);
			fire = mix(red, hot, smoothstep(0.1, 0.95, 1.0 - UV.y));
			fire = mix(fire, amber, max(0.0, strand) * pow(1.0 - UV.y, 2.6) * 0.55);
		} else {
			float core = 1.0 - smoothstep(0.023, 0.068 + edge, radial);
			float halo = (1.0 - smoothstep(0.018, 0.37, radial)) * 0.57;
			alpha = max(core, halo);
			fire = mix(dark_red, red, alpha);
			fire = mix(fire, hot, core * (0.40 + 0.20 * noise));
			if (shockwave) {
				alpha *= 1.0 - smoothstep(0.06, 0.55, progress);
				fire = mix(hot, amber, core * 0.87);
			}
		}
		em_mult = shockwave ? 0.75 : mix(0.52, 1.0, progress);
	}
	ALBEDO = fire;
	EMISSION = fire * em_mult;
	ALPHA = alpha;
}
