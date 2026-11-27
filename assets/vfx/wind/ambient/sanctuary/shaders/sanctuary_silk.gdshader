shader_type spatial;
render_mode cull_disabled;

uniform sampler2D silk_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D silk_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float cycle_phase = 0.0;
uniform float cloth_length : hint_range(0.1, 15.0) = 9.0;
uniform float flutter_height : hint_range(0.0, 1.0) = 0.60;
uniform float silk_brightness : hint_range(0.5, 1.5) = 1.16;

void vertex() {
	float along = clamp(VERTEX.x / max(cloth_length, 0.1), 0.0, 1.0);
	float banner_offset = fract(MODEL_MATRIX[3].x * 0.089) * 0.11;
	float phase = fract(cycle_phase - banner_offset - along * 0.08);
	float gust = smoothstep(0.05, 0.27, phase) * (1.0 - smoothstep(0.43, 0.77, phase));

	// Biên độ bằng 0 ở gốc để lụa tiếp tục bám điểm buộc khi có gió mạnh.
	float envelope = along * along * flutter_height;
	// Giảm số nhịp mỗi vòng để lụa giữ tốc độ cũ khi gió lùa thường xuyên hơn.
	float swell = sin(TAU * (cycle_phase * 3.0 - along * 1.5 + banner_offset));
	float fray = sin(TAU * (cycle_phase * 7.0 - along * 3.1) + VERTEX.y * 2.5);
	VERTEX.y += envelope * (swell * (0.18 + 0.70 * gust) + fray * along * 0.15 + gust * 0.25);
	VERTEX.z += envelope * swell * (0.10 + 0.20 * gust);
}

void fragment() {
	ALBEDO = texture(silk_color, UV).rgb * silk_brightness;
	NORMAL_MAP = texture(silk_normal, UV).rgb;
	NORMAL_MAP_DEPTH = 0.18;
	ROUGHNESS = 0.94;
}
