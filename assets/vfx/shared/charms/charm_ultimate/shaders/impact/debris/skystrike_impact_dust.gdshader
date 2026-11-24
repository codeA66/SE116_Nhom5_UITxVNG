shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Bụi đất cuộn ra từ chỗ nổ. Hình bụi tính bằng nhiễu mềm (không dùng ảnh): ảnh bị phóng theo bán kính nổ
// làm mép vỡ thành ô vuông. Mỗi hạt lệch nhiễu theo vị trí riêng nên không có hai cụm giống nhau.
uniform sampler2D mask : filter_linear_mipmap, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float opacity = 1.0;
// Độ lởm chởm của mép cụm bụi và cỡ đốm nhiễu
uniform float roughness = 0.45;
uniform float noise_scale = 3.2;

varying vec3 seed;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	return noise(p) * 0.6 + noise(p * 2.1 + 7.3) * 0.28 + noise(p * 4.3 + 1.7) * 0.12;
}

void vertex() {
	seed = MODEL_MATRIX[3].xyz;
	vec3 scale_by = vec3(length(MODELVIEW_MATRIX[0].xyz), length(MODELVIEW_MATRIX[1].xyz), length(MODELVIEW_MATRIX[2].xyz));
	MODELVIEW_MATRIX[0] = vec4(scale_by.x, 0.0, 0.0, 0.0);
	MODELVIEW_MATRIX[1] = vec4(0.0, scale_by.y, 0.0, 0.0);
	MODELVIEW_MATRIX[2] = vec4(0.0, 0.0, scale_by.z, 0.0);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	vec2 offset = seed.xz * 1.7 + vec2(seed.y * 3.1);
	float n = fbm(UV * noise_scale + offset + TIME * 0.35);
	float r = length(p * vec2(1.0, 1.15));
	float puff = 1.0 - smoothstep(0.35, 1.0, r + (n - 0.5) * roughness * 2.0);
	// Lõi cụm sẫm hơn, mép sáng hơn: có khối, không phẳng
	float shade = mix(0.62, 1.15, smoothstep(0.1, 0.9, n + r * 0.4));
	ALBEDO = tint.rgb * shade * COLOR.rgb;
	ALPHA = clamp(puff * (0.55 + n * 0.6), 0.0, 1.0) * COLOR.a * opacity;
}
