// Thân mờ của lốc xoáy (mặt phễu): sáng ở giữa nhìn thẳng, nhạt dần ra mép viền (fresnel ngược),
// có các vệt dọc xoắn trôi lên theo TIME. Cho lốc có "khối" như ảnh mẫu thay vì chỉ các dải rời.
// UV.x: quanh trục (0..1), UV.y: chiều cao (0 đáy → 1 đỉnh).
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 body_color : source_color = vec4(0.62, 0.84, 0.95, 1.0);
uniform float body_intensity = 1.3;
uniform float opacity : hint_range(0.0, 1.0) = 0.45;
uniform float spin_speed = 2.6;
// Số vệt xoắn quanh thân và độ nghiêng xoắn
uniform float streaks = 6.0;
uniform float twist = 1.2;
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// Mép phễu (nhìn xiên) mờ, phần giữa đậm: lốc trông tròn trịa
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rim_fade = smoothstep(0.05, 0.6, facing);
	// Vệt xoắn trôi lên
	float band = fract(UV.x * streaks + UV.y * twist - TIME * spin_speed);
	float streak = smoothstep(0.0, 0.15, band) * (1.0 - smoothstep(0.45, 0.6, band));
	// Đáy và đỉnh mờ đi
	float height_fade = smoothstep(0.0, 0.15, UV.y) * (1.0 - smoothstep(0.75, 1.0, UV.y));
	float a = opacity * rim_fade * height_fade * mix(0.45, 1.0, streak) * (1.0 - dissolve);
	ALBEDO = body_color.rgb * body_intensity;
	ALPHA = clamp(a, 0.0, 1.0);
}
