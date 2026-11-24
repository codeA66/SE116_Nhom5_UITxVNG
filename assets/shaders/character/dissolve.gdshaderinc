// Tan biến dọc một trục trong không gian thế giới (chân -> đầu của nhân vật lúc chết). Dùng chung cho mọi material
// của model để thân, viền, mắt tan cùng một mép. dissolve = 0: nguyên vẹn (không tốn gì thêm), 1: biến mất hẳn.
// Mép tan lởm chởm theo nhiễu và có viền sáng. Trục đặt từ code lúc bắt đầu tan (nhân vật nằm yên lúc đó).
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform vec3 dissolve_origin = vec3(0.0);
uniform vec3 dissolve_axis = vec3(0.0, 1.0, 0.0);
uniform float dissolve_length = 1.0;
uniform vec4 dissolve_edge_color : source_color = vec4(1.0, 0.72, 0.38, 1.0);
uniform float dissolve_edge_width = 0.08;
uniform float dissolve_noise = 0.18;
uniform float dissolve_noise_scale = 9.0;
uniform float dissolve_edge_glow = 3.0;

varying vec3 dissolve_world;

float dissolve_hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.17, 0.13));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float dissolve_value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(dissolve_hash(i), dissolve_hash(i + vec3(1, 0, 0)), f.x),
			mix(dissolve_hash(i + vec3(0, 1, 0)), dissolve_hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(dissolve_hash(i + vec3(0, 0, 1)), dissolve_hash(i + vec3(1, 0, 1)), f.x),
			mix(dissolve_hash(i + vec3(0, 1, 1)), dissolve_hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// Trả về độ sáng viền (0..1); điểm đã tan thì discard. Gọi trong fragment()
float dissolve_apply() {
	if (dissolve <= 0.0) {
		return 0.0;
	}
	float along = dot(dissolve_world - dissolve_origin, normalize(dissolve_axis)) / max(dissolve_length, 0.001);
	float cut = along + (dissolve_value_noise(dissolve_world * dissolve_noise_scale) - 0.5) * dissolve_noise;
	// Mép chạy từ dưới chân (-noise) tới quá đầu (1 + noise + viền) để lúc 1 là tan hết
	float front = mix(-dissolve_noise - dissolve_edge_width, 1.0 + dissolve_noise, dissolve);
	if (cut < front) {
		discard;
	}
	return 1.0 - smoothstep(0.0, dissolve_edge_width, cut - front);
}
