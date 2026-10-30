uniform float age = -1.0;
uniform float growth_time = 1.0;
uniform float shatter_time = 1.8;
uniform float duration = 3.4;
uniform float intensity = 1.0;
uniform vec4 core_color : source_color = vec4(0.16, 0.63, 1.0, 1.0);
uniform vec4 edge_color : source_color = vec4(0.68, 0.93, 1.0, 1.0);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float noise21(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1, 0)), f.x), mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1)), f.x), f.y);
}
float fbm(vec2 p) {
	return noise21(p) * 0.6 + noise21(p * 2.13 + 17.1) * 0.28 + noise21(p * 4.7 + 29.0) * 0.12;
}
float grow_at(float u) { return smoothstep(u * growth_time, u * growth_time + 0.15, age); }
