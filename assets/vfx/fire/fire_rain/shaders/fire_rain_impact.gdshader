shader_type spatial;
// Vết nổ dưới chân mỗi cầu lửa: lóe sáng ở tâm rồi tắt nhanh, vòng sóng lan ra và mảnh dần, tia nứt toả ra cháy đỏ
// rồi nguội. age 0 -> 1 suốt đời vết nổ (script đẩy). Mặt sàn sáng vẫn đọc được nên dùng blend_mix.
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;

uniform float age : hint_range(0.0, 1.0) = 1.0;
uniform float seed = 0.0;
uniform vec4 core_color : source_color = vec4(1.0, 0.94, 0.67, 1.0);
uniform vec4 hot_color : source_color = vec4(1.0, 0.55, 0.1, 1.0);
uniform vec4 char_color : source_color = vec4(0.19, 0.065, 0.025, 1.0);
uniform float crack_count = 7.0;

float hash(float n) {
	return fract(sin(n * 127.1 + seed * 311.7) * 43758.5453);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float angle = atan(p.y, p.x);
	// Lóe tâm: tắt trong 30% đầu đời
	float flash_t = clamp(age / 0.3, 0.0, 1.0);
	float flash = (1.0 - smoothstep(0.0, mix(0.55, 0.2, flash_t), r)) * (1.0 - flash_t);
	// Vòng sóng
	float wave_t = 1.0 - pow(1.0 - clamp(age / 0.55, 0.0, 1.0), 2.0);
	float ring_r = mix(0.15, 0.95, wave_t);
	float ring_w = mix(0.12, 0.02, wave_t);
	float ring = smoothstep(ring_w, 0.0, abs(r - ring_r)) * (1.0 - wave_t);
	// Tia nứt: vài tia lệch góc ngẫu nhiên, dài tới 70% bán kính, nguội từ đỏ sang cháy xém
	float sector = floor((angle / 6.28318 + 0.5) * crack_count);
	float center_angle = (sector + 0.5 + (hash(sector) - 0.5) * 0.5) / crack_count * 6.28318 - 3.14159;
	float crack_len = mix(0.35, 0.75, hash(sector + 7.0));
	float crack = smoothstep(0.06 * (1.0 - r / crack_len), 0.0, abs(angle - center_angle) * r) * step(r, crack_len);
	float cool = clamp((age - 0.15) / 0.85, 0.0, 1.0);
	float scorch = (1.0 - smoothstep(0.25, 0.6, r)) * 0.55;
	vec3 color = mix(hot_color.rgb, char_color.rgb, cool);
	color = mix(color, core_color.rgb, clamp(flash * 1.5 + ring * 0.6, 0.0, 1.0));
	float fade = 1.0 - smoothstep(0.7, 1.0, age);
	ALBEDO = color;
	ALPHA = clamp(flash + ring + crack * (1.0 - cool * 0.5) + scorch * cool, 0.0, 1.0) * fade;
}
