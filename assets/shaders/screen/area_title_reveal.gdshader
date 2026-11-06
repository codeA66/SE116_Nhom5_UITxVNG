shader_type canvas_item;
// Chữ tên khu vực hiện như mực loang từ giữa màn ra hai bên: mép lởm chởm theo từng dòng quét, có viền sáng ở mép.
// Tính theo SCREEN_UV nên không phụ thuộc kích thước Label (đổi giãn chữ không làm lệch mép).

// Nửa bề ngang đã hiện, tính theo bề ngang màn hình (0 = ẩn, 0.5 trở lên = hiện hết)
uniform float reveal : hint_range(0.0, 0.7) = 0.7;
// Mốc reveal mà mép mực đã đi hết chữ (code tính theo bề ngang tên): viền sáng tắt dần khi tới mốc này
uniform float reveal_end : hint_range(0.01, 0.7) = 0.6;
// Độ mềm của mép (theo bề ngang màn)
uniform float edge_softness : hint_range(0.001, 0.2) = 0.03;
// Độ lởm chởm của mép mực
uniform float edge_jag : hint_range(0.0, 0.1) = 0.018;
// Mật độ vân lởm chởm theo chiều dọc
uniform float jag_frequency : hint_range(1.0, 400.0) = 90.0;
uniform vec4 glow_color : source_color = vec4(1.0, 0.92, 0.72, 1.0);
uniform float glow_strength : hint_range(0.0, 4.0) = 1.4;
uniform float glow_width : hint_range(0.001, 0.2) = 0.04;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

float value_noise(float x) {
	float i = floor(x);
	float f = fract(x);
	return mix(hash(i), hash(i + 1.0), f * f * (3.0 - 2.0 * f));
}

void fragment() {
	vec4 base = COLOR;
	float distance_from_center = abs(SCREEN_UV.x - 0.5);
	float jag = (value_noise(SCREEN_UV.y * jag_frequency) - 0.5) * edge_jag;
	float front = reveal + jag;
	float mask = 1.0 - smoothstep(front - edge_softness, front, distance_from_center);
	// Viền sáng chỉ sống ở dải ngay sau mép, tắt hẳn khi đã hiện hết
	float glow = (1.0 - smoothstep(0.0, glow_width, front - distance_from_center)) * mask;
	glow *= 1.0 - smoothstep(reveal_end * 0.7, reveal_end, reveal);
	base.rgb = mix(base.rgb, glow_color.rgb, clamp(glow * glow_strength, 0.0, 1.0) * 0.6);
	base.a *= mask;
	COLOR = base;
}
