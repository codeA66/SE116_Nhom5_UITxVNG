shader_type spatial;
// Ngọn lửa (hộp vuông phủ ô sàn, hoặc trụ cột lửa; mặt trong + ngoài): gốc vàng trắng, lên cao chuyển cam đỏ rồi tan,
// mép trên răng cưa bập bùng bằng nhiễu theo thời gian. Không dùng texture.
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;

uniform vec4 base_color : source_color = vec4(1.0, 0.92, 0.55, 1.0);
uniform vec4 mid_color : source_color = vec4(1.0, 0.45, 0.08, 1.0);
uniform vec4 tip_color : source_color = vec4(0.7, 0.08, 0.02, 1.0);
uniform float speed = 2.2;
uniform float strength : hint_range(0.0, 2.0) = 1.0;
// Chiều cao mesh (gốc ở giữa): hộp đơn vị = 1; cột lửa cao bao nhiêu thì đặt bấy nhiêu
uniform float height = 1.0;

varying float v_height;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	// Chiều cao 0..1 trong mesh (gốc ở giữa)
	v_height = VERTEX.y / height + 0.5;
}

void fragment() {
	float h = clamp(v_height, 0.0, 1.0);
	vec2 p = vec2((UV.x + UV.y) * 6.0, h * 3.0 - TIME * speed);
	float n = noise(p) * 0.65 + noise(p * 2.3 + 7.0) * 0.35;
	// Mép trên răng cưa: càng cao càng dễ bị cắt
	float body = smoothstep(1.0, 0.25, h + (n - 0.5) * 0.7);
	vec3 col = mix(base_color.rgb, mid_color.rgb, smoothstep(0.0, 0.45, h));
	col = mix(col, tip_color.rgb, smoothstep(0.45, 0.95, h));
	ALBEDO = col * (0.8 + n * 0.6) * strength;
	ALPHA = body;
}
