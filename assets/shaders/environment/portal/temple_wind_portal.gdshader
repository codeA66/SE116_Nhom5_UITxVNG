shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 deep_air : source_color = vec4(0.07, 0.17, 0.23, 1.0);
uniform vec4 veil_color : source_color = vec4(0.25, 0.59, 0.66, 1.0);
uniform vec4 rim_color : source_color = vec4(0.62, 0.91, 0.96, 1.0);
uniform vec4 highlight_color : source_color = vec4(0.85, 0.99, 1.0, 1.0);
uniform float glow_strength : hint_range(0.0, 0.45) = 0.23;
uniform float drift_speed : hint_range(0.0, 1.0) = 0.23;

float grain(vec2 cell) {
	return fract(sin(dot(cell, vec2(83.23, 47.17))) * 3829.17);
}

float edge_motes(vec2 uv, float drift) {
	float side = sign(uv.x - 0.5);
	float vertical = uv.y + drift * (0.30 + 0.06 * side);
	float cell = floor(vertical * 13.0);
	float seed = grain(vec2(cell, side));
	float height = fract(vertical * 13.0) - mix(0.22, 0.74, seed);
	float center = 0.5 + side * (0.30 + 0.105 * seed - 0.04 * sin(drift * 2.7 + cell));
	vec2 offset = vec2((uv.x - center) * 105.0, height * 5.8);
	return (1.0 - smoothstep(0.31, 1.0, length(offset))) * step(0.37, seed);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float height = 1.0 - UV.y;
	float drift = TIME * drift_speed;

	// Màn thu vào ở đầu và chân để ánh sáng không chồng lên trụ hay sàn đá.
	vec2 corner = abs(p) - vec2(0.77, 0.87);
	float shape = length(max(corner, vec2(0.0))) + min(max(corner.x, corner.y), 0.0) - 0.106;
	float aa = max(fwidth(shape), 0.007);
	float boundary = 1.0 - smoothstep(-aa, aa, shape);
	float inset = max(-shape, 0.0);
	float border = 1.0 - smoothstep(0.004, 0.029 + aa, abs(inset - 0.022));
	float border_haze = 1.0 - smoothstep(0.016, 0.15, inset);

	// Hai nhịp cong lệch nhau dẫn mắt vào giữa và giữ cổng đọc được từ camera cao.
	float breath = sin(drift * 1.7 + p.y * 2.7);
	float left = -0.45 + 0.22 * sin(height * 5.8 - drift * 1.6) + height * 0.11;
	float right = 0.46 + 0.24 * sin(height * 5.3 - drift * 1.32 + 2.0) - height * 0.14;
	float distance_a = abs(p.x - left);
	float distance_b = abs(p.x - right);
	float ribbon_a = 1.0 - smoothstep(0.025, 0.155, distance_a);
	float ribbon_b = 1.0 - smoothstep(0.021, 0.132, distance_b);
	float lobe_a = 0.36 + 0.64 * smoothstep(-0.7, 0.95, sin(height * 12.0 - drift * 4.5));
	float lobe_b = 0.38 + 0.62 * smoothstep(-0.6, 0.94, sin(height * 10.0 - drift * 3.7 + 1.5));
	float ribbon_fade = smoothstep(0.02, 0.22, height) * (1.0 - smoothstep(0.72, 0.98, height));
	float ribbon = (ribbon_a * lobe_a + ribbon_b * lobe_b) * ribbon_fade;
	// Lõi mảnh giúp đường gió vẫn còn nét khi cổng chỉ rộng vài chục pixel.
	float thread_a = (1.0 - smoothstep(0.018, 0.057, distance_a)) * lobe_a * lobe_a;
	float thread_b = (1.0 - smoothstep(0.013, 0.047, distance_b)) * lobe_b * lobe_b;
	float threads = (thread_a + thread_b) * ribbon_fade;

	vec2 hollow = vec2(p.x * 0.97, (height - 0.37) * 1.30);
	float depth_lift = (1.0 - smoothstep(0.04, 0.83, length(hollow))) * (0.80 + breath * 0.12);
	float current = sin(p.x * 9.6 + height * 7.8 - drift * 1.9 + 0.65 * sin(p.y * 5.3 + drift));
	float mist = depth_lift * (0.72 + 0.24 * current);
	float crown = 0.70 + 0.28 * sin(height * 10.0 - drift * 3.1 + p.x * 2.2);
	float motes = edge_motes(UV, drift) * smoothstep(0.04, 0.19, height) * (1.0 - smoothstep(0.81, 0.96, height));

	vec3 color = mix(deep_air.rgb, veil_color.rgb, clamp(mist + ribbon * 0.28, 0.0, 1.0));
	color = mix(color, rim_color.rgb, clamp(border * crown * 0.83 + border_haze * 0.23 + ribbon * 0.75, 0.0, 1.0));
	color = mix(color, highlight_color.rgb, clamp(motes * 0.80 + threads * 0.62 + border * border_haze * crown * 0.13, 0.0, 1.0));
	// Chỉ nâng phần viền và đường gió để tâm cổng giữ được sắc xanh sâu.
	float glow = clamp(border * crown * 0.82 + threads * 0.62 + ribbon * 0.17 + motes * 0.20, 0.0, 1.0);
	ALBEDO = color + rim_color.rgb * glow * glow_strength;
	ALPHA = boundary * clamp(0.67 + mist * 0.26 + ribbon * 0.17 + border * 0.26 + motes * 0.18, 0.0, 0.99);
}
