// Phần dùng chung cho mọi shader gió: hàm băm, độ phủ của đầu/đuôi gió theo pulse, tô nét sắc.
// Toàn bộ chuyển động tính trên GPU theo TIME, script chỉ đổi uniform khi cấu hình hoặc pulse đổi.

// Độ phủ gió: giống hệt WindZone.get_flow_coverage() để hình và lực luôn khớp nhau
uniform bool pulse_enabled = false;
uniform float flow_active = 1.0;
uniform float on_time = 2.0;
uniform float off_time = 2.0;
uniform float sweep_time = 0.25;
uniform float sweep_exponent = 1.6;
uniform float cycle_time = 0.0;
uniform float flow_age = 1000.0;

float wind_hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

// progress: 0 = mặt gió vào, 1 = mặt gió ra
float wind_coverage(float progress) {
	if (progress < 0.0 || progress > 1.0) {
		return 0.0;
	}
	if (!pulse_enabled) {
		return flow_active;
	}
	float delay = pow(progress, 1.0 / sweep_exponent) * sweep_time;
	if (flow_age < delay) {
		return 0.0;
	}
	float phase = mod(cycle_time - delay, max(on_time + off_time, 0.001));
	return phase < on_time ? 1.0 : 0.0;
}

// Dải nét luôn quay mặt về camera: tính trong view space nên nét giữ đúng độ dày ở mọi góc nhìn
vec3 wind_ribbon_side(vec3 view_point, vec3 view_next) {
	vec3 tangent = view_next - view_point;
	if (dot(tangent, tangent) < 1e-10) {
		tangent = vec3(1.0, 0.0, 0.0);
	}
	vec3 side = cross(normalize(tangent), normalize(-view_point));
	if (dot(side, side) < 1e-10) {
		return vec3(0.0, 1.0, 0.0);
	}
	return normalize(side);
}

// Mặt cắt ngang của nét: lõi đặc, mép khử răng cưa theo đúng 1 pixel (fwidth) để nét sắc, không nhòe
float wind_stroke_body(float across) {
	float d = abs(across - 0.5) * 2.0;
	float aa = max(fwidth(d), 0.0001);
	return 1.0 - smoothstep(1.0 - aa * 1.5, 1.0, d);
}

float wind_stroke_core(float across) {
	return 1.0 - smoothstep(0.0, 0.55, abs(across - 0.5) * 2.0);
}

// Hình tròn sắc mép, dùng cho hạt li ti
float wind_dot(vec2 uv) {
	float d = length(uv * 2.0 - 1.0);
	float aa = max(fwidth(d), 0.0001);
	return 1.0 - smoothstep(1.0 - aa * 1.5, 1.0, d);
}

// Hình lá thon hai đầu nhọn, có gân giữa, mép sắc
vec2 wind_leaf(vec2 uv) {
	vec2 q = uv * 2.0 - 1.0;
	float half_width = 0.42 * (1.0 - q.y * q.y);
	float d = abs(q.x) - half_width;
	float aa = max(fwidth(d), 0.0001);
	float body = 1.0 - smoothstep(-aa, aa, d);
	float vein = 1.0 - smoothstep(0.0, 0.06, abs(q.x));
	return vec2(body, vein * step(abs(q.y), 0.8));
}

// Mây/khói mềm: noise giá trị 2 tầng, rẻ và đủ mịn cho vài quad lớn
float wind_value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = wind_hash(dot(i, vec2(1.0, 57.0)));
	float b = wind_hash(dot(i + vec2(1.0, 0.0), vec2(1.0, 57.0)));
	float c = wind_hash(dot(i + vec2(0.0, 1.0), vec2(1.0, 57.0)));
	float d = wind_hash(dot(i + vec2(1.0, 1.0), vec2(1.0, 57.0)));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float wind_puff(vec2 uv, float seed, float time) {
	vec2 q = uv * 2.0 - 1.0;
	float falloff = 1.0 - smoothstep(0.2, 1.0, length(q));
	vec2 p = uv * 3.0 + vec2(seed * 7.0, time * 0.15);
	float n = wind_value_noise(p) * 0.65 + wind_value_noise(p * 2.1 + 3.7) * 0.35;
	return falloff * smoothstep(0.25, 0.85, n);
}
