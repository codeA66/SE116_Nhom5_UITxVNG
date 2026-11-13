shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled, fog_disabled;

// Mặt đất dưới lốc: vòng đứt nét đúng bán kính hút, các nhánh xoắn trôi vào tâm (cho thấy đang hút),
// và lúc nổ: vòng sóng xung kích nở tới bán kính nổ, vệt gió bắn ra ngoài, đĩa sáng ở tâm.
uniform vec4 core_color : source_color = vec4(0.953, 0.988, 1.0, 1.0);
uniform vec4 rim_color : source_color = vec4(0.30, 0.62, 0.73, 1.0);
uniform float time = 0.0;
// Nửa cạnh của mặt phẳng (m): script đặt bằng scale của node
uniform float extent = 4.0;
uniform float pull_radius = 3.5;
uniform float burst_radius = 3.5;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
// < 0 = chưa nổ; 0..1 = tiến độ sóng nổ
uniform float shock = -1.0;
uniform float arms = 3.0;
uniform float ring_dashes = 22.0;
// Vòng hút chỉ là gợi ý tầm, không được át thân lốc
uniform float ring_strength : hint_range(0.0, 1.0) = 0.45;

void fragment() {
	vec2 p = (UV * 2.0 - 1.0) * extent;
	float r = length(p);
	float a = atan(p.y, p.x) / TAU + 0.5;
	float pr = max(pull_radius, 0.001);
	float w = clamp(pr * 0.022, 0.015, 0.18);

	float ring = 1.0 - smoothstep(w * 0.5, w, abs(r - pr));
	ring *= step(0.5, fract(a * ring_dashes - time * 0.5)) * ring_strength;

	// Pha tăng theo thời gian nên đường cùng pha co về tâm: nhánh trôi vào trong
	float rn = r / pr;
	float sp = fract(a * arms + rn * 1.3 + time * 1.7);
	float arm = smoothstep(0.0, 0.04, sp) * (1.0 - smoothstep(0.1, 0.17, sp));
	arm *= (1.0 - smoothstep(0.75, 1.0, rn)) * smoothstep(0.12, 0.3, rn);

	float v = max(ring, arm * 0.75) * intensity;

	if (shock >= 0.0) {
		float grow = 1.0 - pow(1.0 - shock, 2.0);
		float br = max(burst_radius, 0.001);
		float sr = br * grow;
		float sw = clamp(br * 0.12, 0.04, 0.9) * (1.0 - shock * 0.5);
		// Giữ đậm phần lớn quãng nở rồi mới tắt nhanh ở cuối
		float fade = 1.0 - smoothstep(0.45, 1.0, shock);
		float wave = (1.0 - smoothstep(sw * 0.4, sw, abs(r - sr))) * fade;
		// Vệt gió ngắn bắn ra ngay sau mép sóng, dài ngắn khác nhau theo làn
		// Làn cong theo bán kính: vệt văng ra vẫn còn xoáy, không thẳng như kim đồng hồ
		float curl = a * 9.0 + r / br * 0.8;
		float lane_id = floor(curl);
		float lane = fract(curl);
		float len = mix(0.18, 0.4, fract(sin(lane_id * 12.9898) * 43758.5453));
		float streak = (1.0 - smoothstep(0.02, 0.07, abs(lane - 0.5))) * smoothstep(sr * (1.0 - len), sr * (1.0 - len * 0.5), r) * step(r, sr * 0.97) * fade;
		// Mép trong mềm của sóng: luồng gió quét qua sau mép
		float wake = smoothstep(sr * 0.55, sr, r) * step(r, sr) * fade * 0.35;
		float disk = (1.0 - smoothstep(0.0, sr * 0.6 + 0.01, r)) * (1.0 - smoothstep(0.0, 0.4, shock)) * 0.7;
		v = max(v, max(max(wave, wake), max(streak, disk)));
	}
	if (v < 0.03) {
		discard;
	}
	ALBEDO = mix(rim_color.rgb, core_color.rgb, smoothstep(0.2, 0.7, v));
	ALPHA = v;
}
