shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Lưỡi lửa bùng ra từ chỗ nổ (mỗi hạt một lưỡi): hình giọt lửa nhọn đầu, viền xé bằng nhiễu chạy lên.
// Màu theo tuổi hạt (color_ramp của bộ hạt: trắng vàng -> cam -> đỏ sẫm -> tắt); hạt quay theo hướng bay.
uniform float flicker = 2.4;

varying vec3 seed;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 15731.743);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	seed = MODEL_MATRIX[3].xyz;
}

void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, UV.y);
	// Giọt lửa: rộng ở đáy (UV.y = 1), nhọn ở đỉnh (UV.y = 0)
	float width = mix(0.08, 0.85, smoothstep(0.0, 0.85, p.y));
	float n = noise(vec2(p.x * 3.0 + seed.x * 5.0, p.y * 4.0 + TIME * flicker + seed.z * 3.0));
	float shape = 1.0 - smoothstep(width * 0.55, width, abs(p.x) + (n - 0.5) * 0.35);
	shape *= smoothstep(0.0, 0.25, p.y + n * 0.2) * (1.0 - smoothstep(0.9, 1.0, p.y));
	float hot = 1.0 - smoothstep(0.0, width * 0.6, abs(p.x));
	ALBEDO = COLOR.rgb * mix(0.8, 1.6, hot * smoothstep(0.4, 1.0, p.y));
	ALPHA = clamp(shape * COLOR.a, 0.0, 1.0);
}
