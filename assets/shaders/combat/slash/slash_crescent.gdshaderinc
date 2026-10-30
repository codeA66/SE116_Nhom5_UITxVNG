// Hình học lưỡi liềm dùng chung cho thân đen (slash_trail.gdshader) và lớp sáng (slash_glow.gdshader),
// để hai lớp luôn khớp nhau từng pixel.
// Mesh cung: UV.x dọc cung 0..1, UV.y từ mép trong 0 ra mép ngoài 1.
// head (0..1): mũi vệt quét qua cung. dissolve (0..1): lưỡi liềm teo mỏng từ đuôi tới mũi.

uniform float head = 0.0;
uniform float dissolve = 0.0;
// +1 / -1: đổi chiều quét (đòn nối sau chém ngược lại)
uniform float direction = 1.0;
// Bề dày tối đa của lưỡi liềm (tỉ lệ bề rộng mesh) và độ phình
uniform float thickness = 0.6;
uniform float shape_power = 1.3;
// Độ dài đoạn thon nhọn ở mũi và ở đuôi (tỉ lệ cung)
uniform float tip_taper = 0.12;
// Đuôi mỏng hơn mũi: độ dày ở cuối vệt so với ở mũi, và độ dài đoạn mỏng dần (theo head)
uniform float tail_thickness = 0.4;
uniform float tail_length = 0.8;
// Độ dày biến thiên dọc cung (xoắn) và độ vụn mép trong. Mặc định gần 0: lưỡi đều, mép sắc
uniform float twist = 0.0;
uniform float crumble = 0.02;
uniform float seed = 0.0;

const float PI_F = 3.14159265;

float slash_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 43.7) * 43758.5453);
}

float slash_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(slash_hash(i), slash_hash(i + vec2(1.0, 0.0)), f.x), mix(slash_hash(i + vec2(0.0, 1.0)), slash_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// d_in: khoảng cách (theo UV.y) từ mép trong, > 0 là bên trong lưỡi; d_out: từ mép ngoài;
// t: bề dày hiện tại; s: vị trí theo chiều quét 0..1
void crescent_shape(vec2 uv, out float d_in, out float d_out, out float t, out float s) {
	s = direction > 0.0 ? uv.x : 1.0 - uv.x;
	float base_t = thickness * pow(max(sin(PI_F * uv.x), 0.0), shape_power);
	float head_taper = sqrt(clamp((head - s) / tip_taper, 0.0, 1.0));
	float tail_cut = dissolve * (1.0 + tip_taper);
	float tail_taper = clamp((s - tail_cut) / tip_taper, 0.0, 1.0);
	// Mũi đậm và dày nhất, thân mỏng dần về đuôi; độ dày xoắn không đều
	float recency = 1.0 - clamp((head - s) / max(tail_length, 0.001), 0.0, 1.0);
	float wobble = 1.0 + twist * (slash_noise(vec2(uv.x * 5.0, 1.7)) - 0.5) * 2.0;
	t = base_t * wobble * mix(tail_thickness, 1.0, recency) * head_taper * tail_taper * (1.0 - 0.35 * dissolve);
	t = clamp(t, 0.0, 0.98);
	d_in = uv.y - (1.0 - t);
	// Mép trong vụn: nhiễu cắt mép (mép ngoài vẫn liền sắc)
	d_in += (slash_noise(vec2(uv.x * 60.0, uv.y * 14.0)) - 0.5) * crumble * smoothstep(0.0, 0.15, t);
	d_out = 1.0 - uv.y;
}
