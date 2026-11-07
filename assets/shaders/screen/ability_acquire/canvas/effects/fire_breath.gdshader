shader_type canvas_item;
// Hình hiệu ứng "Phun lửa" trên bảng nhận kỹ năng, vẽ bằng code: luồng lửa hình nón phụt từ cáo (mép trái)
// sang phải, mép lửa lởm chởm và chạy liên tục; gần gốc / giữa luồng nóng trắng, mép ngoài màu kỹ năng.
uniform vec4 core_color : source_color = vec4(1.0, 0.96, 0.86, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.5, 0.15, 1.0);
// Nửa bề cao nón lửa ở đầu xa
uniform float cone = 0.36;
uniform float flow_speed = 0.8;
uniform float noise_scale = 6.0;
uniform float brightness = 1.3;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

float fbm(vec2 p) {
	float sum = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		sum += value_noise(p) * amp;
		p *= 2.03;
		amp *= 0.5;
	}
	return sum;
}

void fragment() {
	vec2 uv = UV;
	float x = uv.x;
	float half_width = mix(0.05, cone, smoothstep(0.0, 0.85, x));
	float dy = abs(uv.y - 0.5) / half_width;
	float n = fbm(vec2(x * noise_scale - TIME * flow_speed * 3.0, uv.y * noise_scale * 1.3));
	float body = 1.0 - smoothstep(0.55, 1.05, dy + (n - 0.5) * 0.9);
	body *= smoothstep(0.0, 0.05, x) * (1.0 - smoothstep(0.7 + 0.2 * n, 1.0, x));
	float heat = clamp((1.0 - x) * (1.0 - dy) * 1.8, 0.0, 1.0);
	vec3 color = mix(glow_color.rgb, core_color.rgb, heat) * brightness;
	COLOR = vec4(color, clamp(body * (0.55 + 0.45 * n), 0.0, 1.0));
}
