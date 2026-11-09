shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

// UV.y chạy từ chân lên đỉnh ở lõi, và ngang bề rộng ở các dải.
uniform vec4 core_color : source_color = vec4(0.847, 0.98, 1.0, 1.0);
uniform vec4 edge_color : source_color = vec4(0.569, 0.914, 0.961, 1.0);
uniform float progress = 0.0;
uniform float opacity = 1.0;
uniform bool volume_mode = false;
uniform float fade_in = 0.06;
uniform float erode_start = 0.5;
uniform float scroll_speed = 2.5;

void fragment() {
	float clock = TIME * scroll_speed;
	float appear = smoothstep(0.0, max(fade_in, 0.001), progress);
	float decay = smoothstep(erode_start, 1.0, progress);
	float age = appear * (1.0 - decay);
	if (volume_mode) {
		float rise = UV.y;
		float angle = UV.x * TAU;
		// Hai dòng gió lệch độ dốc đổi vị trí quanh lõi, giữ khoảng hở giữa các sợi.
		float warp = sin(angle * 2.0 + rise * 8.0 + clock * 1.8);
		float broad = 0.5 + 0.5 * sin(angle - clock * 2.6 + rise * 10.0 + warp * 0.62);
		float filament_a = smoothstep(0.78, 1.0, sin(angle * 3.0 + rise * 22.0 - clock * 3.8 + warp * 0.8));
		float filament_b = smoothstep(0.89, 1.0, sin(angle * 2.0 - rise * 17.0 - clock * 3.1));
		float foot = smoothstep(0.01, 0.12, rise) * (1.0 - smoothstep(0.24, 0.48, rise));
		float envelope = smoothstep(0.0, 0.12, rise) * (1.0 - smoothstep(0.68, 1.0, rise));
		float bright = clamp(foot * (0.62 + broad * 0.44) + filament_a * 0.40 + filament_b * 0.16, 0.0, 1.0);
		float density = 0.07 + broad * 0.19 + foot * 0.68 + filament_a * 0.25 + filament_b * 0.11;
		ALBEDO = mix(edge_color.rgb, core_color.rgb, bright);
		ALPHA = opacity * envelope * age * min(0.91, density);
	} else {
		// Dải mềm, thon ở hai đầu và đứt nhẹ theo chiều chạy của gió.
		float across = 1.0 - abs(UV.y * 2.0 - 1.0);
		float taper = smoothstep(0.0, 0.28, UV.x) * (1.0 - smoothstep(0.84, 1.0, UV.x));
		float break_up = sin(UV.x * 33.0 - clock * 2.2) * 0.5 + 0.5;
		float thread = smoothstep(0.02, 0.72, across) * mix(0.44, 1.0, break_up);
		ALBEDO = mix(edge_color.rgb, core_color.rgb, smoothstep(0.32, 1.0, across));
		ALPHA = opacity * age * taper * thread;
	}
}
