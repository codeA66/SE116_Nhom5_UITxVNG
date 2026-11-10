shader_type canvas_item;
// Hình hiệu ứng "Thổi gió" trên bảng nhận kỹ năng, vẽ bằng code: các vệt gió trắng tỏa ra từ tay cáo (mép trái)
// sang phải, gợn sóng và chạy nhẹ, cuộn thành xoáy ở đầu luồng. Lõi trắng + quầng màu kỹ năng.
uniform vec4 core_color : source_color = vec4(0.97, 0.99, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(0.65, 0.88, 0.94, 1.0);
// Tỉ lệ ngang / dọc của khung vẽ (để xoáy tròn không bị méo)
uniform float aspect = 1.7;
uniform int streaks = 6;
uniform float thickness = 0.016;
uniform float wave = 0.05;
// Nửa bề cao luồng ở đầu xa (luồng tỏa ra)
uniform float spread = 0.3;
uniform float flow_speed = 0.35;
uniform float glow = 0.7;
uniform vec2 curl_center = vec2(0.8, 0.5);
uniform float curl_radius = 0.2;
uniform float curl_turns = 5.0;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float core = 0.0;
	float halo = 0.0;
	for (int i = 0; i < streaks; i++) {
		float seed = hash(float(i) * 7.13);
		float k = float(i) / max(float(streaks - 1), 1.0) * 2.0 - 1.0;
		float x = uv.x;
		float center_y = 0.5 + k * spread * smoothstep(0.0, 1.0, x)
			+ sin(x * 9.0 + seed * 6.283 - TIME * flow_speed * 6.0) * wave * x;
		float d = abs(uv.y - center_y);
		float taper = smoothstep(0.0, 0.15, x) * (1.0 - smoothstep(0.55 + 0.3 * seed, 0.95, x));
		// Vệt đứt quãng chạy theo luồng
		float dash = 0.55 + 0.45 * smoothstep(0.15, 0.45, fract(x * 2.2 - TIME * flow_speed + seed));
		float w = thickness * mix(0.35, 1.0, taper);
		core += (1.0 - smoothstep(0.0, w, d)) * taper * dash;
		halo += (1.0 - smoothstep(0.0, w * 6.0, d)) * taper * 0.3;
	}
	// Xoáy gió ở đầu luồng
	vec2 p = (uv - curl_center) * vec2(aspect, 1.0);
	float r = length(p);
	float spiral = fract(atan(p.y, p.x) / 6.283185 + r * curl_turns - TIME * flow_speed);
	float inside = (1.0 - smoothstep(curl_radius * 0.5, curl_radius, r)) * smoothstep(0.0, curl_radius * 0.25, r);
	float arm = (1.0 - smoothstep(0.0, 0.09, abs(spiral - 0.5))) * inside;
	core += arm * 0.9;
	halo += inside * 0.25;
	float edges = smoothstep(0.0, 0.08, uv.y) * smoothstep(1.0, 0.92, uv.y) * smoothstep(1.0, 0.94, uv.x);
	vec3 color = core_color.rgb * min(core, 1.0) + glow_color.rgb * halo * glow;
	COLOR = vec4(color, clamp(core + halo * glow, 0.0, 1.0) * edges);
}
