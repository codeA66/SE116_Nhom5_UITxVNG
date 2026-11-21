shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// Shader trong suốt riêng cho 56 tia sáng tụ vào quả cầu lửa khi charge up,
// tách khỏi sabretooth_fire.gdshader để tia beam giữ nguyên chế độ opaque có depth-write chuẩn.
uniform float progress = 0.0;
uniform float strength = 1.0;

varying vec4 v_ray;

void vertex() {
	// NORMAL lưu hướng tia từ tâm ra ngoài; UV.x (0=đầu gần tâm, 1=đuôi xa); UV.y (-1..1 bề rộng mảnh).
	vec3 ray_dir = normalize(NORMAL);
	float seed = COLOR.r;
	float outer_r = mix(2.6, 5.2, COLOR.g);
	float spd = mix(0.78, 1.45, COLOR.b);
	float cycle = fract(TIME * spd * mix(0.95, 1.45, progress) + seed);
	float pull = pow(cycle, 1.65);
	float head_r = mix(outer_r, 0.18, pull);
	float streak_len = mix(0.65, 1.75, sin(cycle * 3.14159)) * mix(0.65, 1.15, progress);
	float along_r = head_r + UV.x * streak_len;
	vec3 ref = abs(ray_dir.y) > 0.92 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
	vec3 side_a = normalize(cross(ray_dir, ref));
	vec3 side_b = cross(ray_dir, side_a);
	float spin = seed * 6.283185;
	vec3 width_axis = side_a * cos(spin) + side_b * sin(spin);
	float half_w = mix(0.045, 0.008, UV.x) * sin(cycle * 3.14159);
	VERTEX = ray_dir * along_r + width_axis * (UV.y * half_w);
	v_ray = vec4(cycle, UV.x, COLOR.g, 1.0);
}

void fragment() {
	float cycle = v_ray.x;
	float along = v_ray.y;
	float fade = smoothstep(0.0, 0.16, cycle) * (1.0 - smoothstep(0.76, 1.0, cycle));
	float tail_fade = 1.0 - smoothstep(0.25, 1.0, along);
	float alpha = fade * tail_fade * clamp(strength, 0.0, 1.2);
	if (alpha < 0.02) { discard; }
	vec3 ray_col = mix(vec3(1.0, 0.94, 0.68), vec3(1.0, 0.42, 0.05), smoothstep(0.08, 0.85, along));
	ALBEDO = ray_col * 1.45;
	EMISSION = ray_col * 1.85;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
